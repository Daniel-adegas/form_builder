/**
 * @description       : Universal Form Renderer -- works in Experience Cloud, Lightning pages,
 *                      Screen Flows, and Record Pages. Supports draft/resume, auto-save,
 *                      language switching, dependency visibility, submit flow, and read-only mode.
 * @author            : Daniel Murracas
 * @last modified on  : 17-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   19-03-2026   Daniel Murracas     Draft/resume, auto-save, submit flow
 * 2.0   19-03-2026   Daniel Murracas     Experience Cloud, Flow, read-only, @api props
 * 2.1   17-03-2026   Daniel Murracas     Logic group evaluation (AND/OR) in dependencies
 * ------------------------------------------------------------
**/
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getForms from '@salesforce/apex/FormBuilderService.getForms';
import getFormStructureWithMeta from '@salesforce/apex/FormService.getFormStructureWithMeta';
import getAvailableLanguages from '@salesforce/apex/TranslationService.getAvailableLanguages';
import getTranslations from '@salesforce/apex/TranslationService.getTranslations';
import getOrCreateSubmission from '@salesforce/apex/FormSubmissionService.getOrCreateSubmission';
import saveDraftState from '@salesforce/apex/FormSubmissionService.saveDraftState';
import submitFormApex from '@salesforce/apex/FormSubmissionService.submitForm';
import getFeatureSettings from '@salesforce/apex/FeatureSettingsService.getFeatureSettings';
import getSubmissionWithResponses from '@salesforce/apex/FormSubmissionService.getSubmissionWithResponses';
import getPrePopulationData from '@salesforce/apex/FieldMappingService.getPrePopulationData';
import { countWords, maxWordsExceededMessage } from 'c/formWordCountUtil';

const AUTO_SAVE_DELAY = 3000;

export default class FormRenderer extends LightningElement {

    @api formId;
    @api contextRecordId;
    @api recordContext;
    @api language;
    @api hideHeader = false;
    @api readOnly = false;
    /** When true, the form is rendered for preview only (no submission), e.g. builder or staged content. */
    @api previewMode = false;
    @api recordId; // auto-set on Record Pages

    _userRecordContext = '';

    get _recordContextJson() {
        if (this.recordContext) {
            if (typeof this.recordContext === 'object') return JSON.stringify(this.recordContext);
            return this.recordContext;
        }
        if (this._userRecordContext) return this._userRecordContext;
        if (this.contextRecordId) return this.contextRecordId;
        if (this.recordId) return this.recordId;
        return null;
    }

    handleRecordContextChange(event) {
        this._userRecordContext = event.detail.value;
    }

    @track forms = [];
    @track formStructure = null;
    @track formMeta = null;
    categoryPageMap = {};
    currentStep = 0;
    _selectedFormId = null;
    selectedFormName = '';
    mode = 'select';
    isLoading = false;

    selectedLanguage = '';
    @track availableLanguages = [];
    @track translationMap = {};
    @track selectedResponses = {};
    @track hiddenElements = {};
    @track requiredByDependency = {};
    @track crossFieldErrors = {};

    _submissionId = null;
    @track featureSettings = {
        scoring: true,
        fieldMapping: true,
        translations: true,
        characterCountdown: false
    };
    @track inlineMessage = { title: '', message: '', variant: 'info', visible: false };
    @track submissionMeta = null;

    _autoSaveTimer = null;
    _initialized = false;
    _forceReadOnly = false;
    _notifyTimer = null;
    /** Dedupes overlapping getFeatureSettings calls (e.g. launch + read-only). */
    _featureSettingsLoadPromise;

    get selectedFormId() { return this._selectedFormId || this.formId; }
    set selectedFormId(val) { this._selectedFormId = val; }

    get submissionId() { return this._submissionId; }
    set submissionId(val) { this._submissionId = val; }

    get isSelectMode() { return this.mode === 'select' && !this.isReadOnly; }
    get isRenderMode() { return this.mode === 'render'; }
    get isSuccessMode() { return this.mode === 'success'; }
    get isReadOnly() { return this.readOnly === true || this.readOnly === 'true' || this._forceReadOnly === true; }

    get isPreviewMode() { return this.previewMode === true || this.previewMode === 'true'; }

    get showHeader() { return !(this.hideHeader === true || this.hideHeader === 'true'); }
    get showBackButton() { return this.showHeader && !this.formId && !this.isReadOnly; }
    get showSubmitButton() { return !this.isReadOnly && !this.isPreviewMode; }

    get isLaunchDisabled() { return !this.selectedFormId; }

    get formOptions() {
        return this.forms.map(f => ({
            label: f.Name + ' (' + (f.C_Status__c || 'Draft') + ')',
            value: f.Id
        }));
    }

    get languageOptions() {
        return this.availableLanguages.map(l => ({ label: l, value: l }));
    }

    get hasLanguages() {
        return this.featureSettings.translations && this.availableLanguages.length > 1;
    }

    get hasFormStructure() {
        return this.formStructure && this.formStructure.length > 0;
    }

    get totalPages() {
        return this.visiblePages.length;
    }

    get visiblePages() {
        if (!this.formStructure) return [];
        return this.formStructure.filter(p => !this.hiddenElements[p.pageId]);
    }

    get progressSteps() {
        return this.visiblePages.map((p, idx) => ({
            ...p,
            translatedPageName: this.getTranslated('Page', p.pageId, 'Name') || p.pageName,
            stepIndex: idx + 1,
            isCurrent: idx === this.currentStep,
            isCompleted: idx < this.currentStep,
            isUpcoming: idx > this.currentStep,
            stepClass: idx === this.currentStep ? 'step-pill step-active' :
                       idx < this.currentStep ? 'step-pill step-completed' : 'step-pill step-upcoming'
        }));
    }

    get currentPage() {
        const pages = this.visiblePages;
        if (!pages || pages.length === 0) return null;
        return pages[this.currentStep] || null;
    }

    get currentPageName() {
        const page = this.currentPage;
        if (!page) return '';
        return this.getTranslated('Page', page.pageId, 'Name') || page.pageName;
    }

    get currentPageDescription() {
        const page = this.currentPage;
        if (!page) return '';
        return this.getTranslated('Page', page.pageId, 'C_Description__c') || page.description;
    }

    get currentSections() {
        const page = this.currentPage;
        if (!page || !page.sections) return [];
        return page.sections
            .filter(s => !this.hiddenElements[s.sectionId])
            .map(s => ({
                ...s,
                translatedName: this.getTranslated('Section', s.sectionId, 'Name') || s.sectionName,
                visibleQuestions: (s.questions || [])
                    .filter(q => !this.hiddenElements[q.questionId])
                    .map(q => {
                        const colBase =
                            q.layoutSpan === 'Half'
                                ? 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2'
                                : 'slds-col slds-size_1-of-1';
                        return {
                            ...q,
                            questionLayoutClass: `${colBase} question-row`,
                            isRequired: !this.isReadOnly && (q.isRequired === true || this.requiredByDependency[q.questionId] === true),
                            questionText: this.getTranslated('Question', q.questionId, 'C_Question_Text__c') || q.questionText || q.questionName,
                            helpText: this.getTranslated('Question', q.questionId, 'C_Help_Text__c') || q.helpText,
                            placeholder: this.getTranslated('Question', q.questionId, 'C_Placeholder__c') || q.placeholder,
                            crossFieldError: this.crossFieldErrors[q.questionId] || '',
                            responses: (q.responses || []).map(r => ({
                                ...r,
                                responseText: this.getTranslated('Response', r.responseId, 'C_Response_Text__c') || r.responseText || r.responseName,
                                responseName: r.responseName
                            }))
                        };
                    })
            }));
    }

    get isFirstPage() { return this.currentStep === 0; }
    get isLastPage() { return this.currentStep >= this.visiblePages.length - 1; }

    get pageCounter() {
        return `Page ${this.currentStep + 1} of ${this.totalPages}`;
    }

    get progressPercent() {
        if (this.totalPages <= 1) return 100;
        return Math.round(((this.currentStep + 1) / this.totalPages) * 100);
    }

    get progressWidth() {
        return `width: ${this.progressPercent}%`;
    }

    get inlineAlertClass() {
        const v = this.inlineMessage.variant || 'info';
        return `inline-alert inline-alert-${v}`;
    }

    get inlineAlertIcon() {
        const map = { error: 'utility:error', warning: 'utility:warning', success: 'utility:success', info: 'utility:info' };
        return map[this.inlineMessage.variant] || 'utility:info';
    }

    get readOnlyBannerText() {
        if (!this.submissionMeta) return '';
        const status = this.submissionMeta.status || 'Submitted';
        const score = this.submissionMeta.finalScore;
        const date = this.submissionMeta.submittedDate;
        let text = `Status: ${status}`;
        if (score != null) text += ` | Score: ${score}%`;
        if (date) text += ` | Submitted: ${date}`;
        return text;
    }

    get rendererLayout() { return this.formMeta?.layoutMode || 'classic'; }
    get isClassic() { return this.rendererLayout?.toLowerCase() === 'classic'; }
    get isConversational() { return this.rendererLayout?.toLowerCase() === 'conversational'; }
    get isCardBased() { return this.rendererLayout?.toLowerCase() === 'cardbased'; }
    get isWizard() { return this.rendererLayout?.toLowerCase() === 'wizard'; }

    connectedCallback() {
        if (this._initialized) return;
        this._initialized = true;

        if (this.isReadOnly && this.recordId) {
            this._loadReadOnlySubmission(this.recordId);
        } else if (this.formId) {
            this._selectedFormId = this.formId;
            this._launchForm();
        } else {
            this.loadForms();
        }
    }

    disconnectedCallback() {
        this._clearAutoSave();
    }

    async loadFeatureSettings() {
        if (this._featureSettingsLoadPromise) {
            return this._featureSettingsLoadPromise;
        }
        this._featureSettingsLoadPromise = (async () => {
            try {
                this.featureSettings = await getFeatureSettings();
            } catch (e) {
                // defaults already set on initial @track object
            }
        })();
        return this._featureSettingsLoadPromise;
    }

    async loadForms() {
        this.isLoading = true;
        try {
            this.forms = await getForms();
        } catch (error) {
            console.error('Error loading forms:', error);
            this._notify('Error', error?.body?.message || error?.message || 'Failed to load forms', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleFormSelect(event) {
        this._selectedFormId = event.detail.value;
        const form = this.forms.find(f => f.Id === this._selectedFormId);
        this.selectedFormName = form ? form.Name : '';
    }

    handleLaunchForm() {
        if (!this.selectedFormId) return;
        this._launchForm();
    }

    async _launchForm() {
        this.isLoading = true;
        try {
            await this.loadFeatureSettings();
            const result = await getFormStructureWithMeta({ formId: this.selectedFormId });
            this.formMeta = {
                formName: result.formName,
                formId: result.formId,
                defaultLanguage: result.defaultLanguage,
                layoutMode: result.layoutMode
            };
            this.formStructure = JSON.parse(JSON.stringify(result.pages));
            this.categoryPageMap = this._buildCategoryPageMap(result.categories);
            this.currentStep = 0;
            this.selectedResponses = {};
            this.hiddenElements = {};
            this.requiredByDependency = {};
            this.crossFieldErrors = {};
            this.selectedFormName = result.formName;

            if (!this.isReadOnly) {
                const subResult = await getOrCreateSubmission({
                    formId: this.selectedFormId,
                    recordContextJson: this._recordContextJson
                });
                this._submissionId = subResult.submissionId;

                const hasDraft = (subResult.isResume === true || subResult.isResume === 'true') && subResult.draftJson;
                if (hasDraft) {
                    this._restoreDraft(subResult.draftJson);
                }

                await this._applyPrePopulation(hasDraft);
            }

            this.mode = 'render';

            if (this.language) {
                this.selectedLanguage = this.language;
                if (this.language !== this.formMeta.defaultLanguage) {
                    await this._loadTranslationsForLanguage(this.language);
                }
            }

            if (this.featureSettings.translations) {
                await this.loadLanguages();
            }

            this.evaluateDependencies();
        } catch (error) {
            console.error('Error loading form:', error);
            this._notify('Error', error?.body?.message || error?.message || 'Failed to load form', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async _loadReadOnlySubmission(subId) {
        this.isLoading = true;
        try {
            await this.loadFeatureSettings();
            const subData = await getSubmissionWithResponses({ submissionId: subId });
            this.submissionMeta = {
                status: subData.status,
                finalScore: subData.finalScore,
                submittedDate: subData.submittedDate
            };
            this._selectedFormId = subData.formId;
            this._forceReadOnly = true;

            const result = await getFormStructureWithMeta({ formId: subData.formId });
            this.formMeta = {
                formName: result.formName,
                formId: result.formId,
                defaultLanguage: result.defaultLanguage,
                layoutMode: result.layoutMode
            };
            this.formStructure = JSON.parse(JSON.stringify(result.pages));
            this.categoryPageMap = this._buildCategoryPageMap(result.categories);
            this.selectedFormName = result.formName;

            const responses = subData.responses || {};
            const hasResponses = Object.keys(responses).length > 0;

            if (hasResponses && this.formStructure) {
                for (const page of this.formStructure) {
                    if (!page.sections) continue;
                    for (const section of page.sections) {
                        if (!section.questions) continue;
                        for (let i = 0; i < section.questions.length; i++) {
                            const resp = responses[section.questions[i].questionId];
                            if (resp) {
                                section.questions[i] = {
                                    ...section.questions[i],
                                    value: resp.value || null,
                                    textValue: resp.textValue || null
                                };
                                if (resp.value) {
                                    const vals = String(resp.value).split(';');
                                    for (const v of vals) {
                                        this.selectedResponses[v] = true;
                                    }
                                }
                            }
                        }
                    }
                }
                this.selectedResponses = { ...this.selectedResponses };
            } else if (subData.draftJson) {
                this._restoreDraft(subData.draftJson);
            }

            if (subData.language && subData.language !== this.formMeta.defaultLanguage) {
                await this._loadTranslationsForLanguage(subData.language);
            }
            if (this.featureSettings.translations) {
                await this.loadLanguages();
            }

            this.mode = 'render';
            this.evaluateDependencies();
        } catch (error) {
            console.error('Error loading submission:', error);
            this._notify('Error', error?.body?.message || error?.message || 'Failed to load submission', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async _loadTranslationsForLanguage(lang) {
        try {
            this.translationMap = await getTranslations({
                formId: this.selectedFormId,
                language: lang
            });
            this.selectedLanguage = lang;
        } catch (e) {
            this.translationMap = {};
        }
    }

    _restoreDraft(draftJson) {
        try {
            const draft = JSON.parse(draftJson);
            if (draft.currentStep != null) {
                this.currentStep = draft.currentStep;
            }
            if (draft.responses && this.formStructure) {
                for (const page of this.formStructure) {
                    if (!page.sections) continue;
                    for (const section of page.sections) {
                        if (!section.questions) continue;
                        for (let i = 0; i < section.questions.length; i++) {
                            const saved = draft.responses[section.questions[i].questionId];
                            if (saved) {
                                section.questions[i] = {
                                    ...section.questions[i],
                                    value: saved.value,
                                    textValue: saved.textValue
                                };
                                if (saved.value) {
                                    const vals = String(saved.value).split(';');
                                    for (const v of vals) {
                                        this.selectedResponses[v] = true;
                                    }
                                }
                            }
                        }
                    }
                }
                this.selectedResponses = { ...this.selectedResponses };
            }
        } catch (e) {
            console.error('Error restoring draft:', e);
        }
    }

    async _applyPrePopulation(hasDraft) {
        try {
            const prepopData = await getPrePopulationData({
                formId: this.selectedFormId,
                recordContextJson: this._recordContextJson
            });
            if (!prepopData || Object.keys(prepopData).length === 0) return;

            let appliedCount = 0;
            for (const page of this.formStructure) {
                if (!page.sections) continue;
                for (const section of page.sections) {
                    if (!section.questions) continue;
                    for (let i = 0; i < section.questions.length; i++) {
                        const q = section.questions[i];
                        const prepop = prepopData[q.questionId];
                        if (!prepop) continue;

                        const alreadyHasValue = hasDraft && ((q.value != null && q.value !== '') || (q.textValue != null && q.textValue !== ''));
                        if (alreadyHasValue) continue;

                        section.questions[i] = {
                            ...q,
                            value: prepop.value || null,
                            textValue: prepop.textValue || null
                        };

                        if (prepop.value) {
                            const vals = String(prepop.value).split(';');
                            for (const v of vals) {
                                this.selectedResponses[v] = true;
                            }
                        }
                        appliedCount++;
                    }
                }
            }

            if (appliedCount > 0) {
                this.selectedResponses = { ...this.selectedResponses };
                this._notify('Pre-filled', `${appliedCount} field(s) were pre-populated from your records.`, 'info');
            }
        } catch (e) {
            console.error('Pre-population failed:', e);
        }
    }

    _buildDraftJson() {
        const responses = {};
        if (this.formStructure) {
            for (const page of this.formStructure) {
                if (!page.sections) continue;
                for (const section of page.sections) {
                    if (!section.questions) continue;
                    for (const q of section.questions) {
                        if (q.value != null || q.textValue != null) {
                            responses[q.questionId] = { value: q.value, textValue: q.textValue };
                        }
                    }
                }
            }
        }
        return JSON.stringify({ currentStep: this.currentStep, responses });
    }

    _scheduleAutoSave() {
        if (this.isReadOnly) return;
        this._clearAutoSave();
        this._autoSaveTimer = setTimeout(() => {
            this._performAutoSave();
        }, AUTO_SAVE_DELAY);
    }

    _clearAutoSave() {
        if (this._autoSaveTimer) {
            clearTimeout(this._autoSaveTimer);
            this._autoSaveTimer = null;
        }
    }

    async _performAutoSave() {
        if (!this._submissionId || this.isReadOnly) return;
        try {
            await saveDraftState({
                submissionId: this._submissionId,
                draftJson: this._buildDraftJson()
            });
        } catch (e) {
            console.error('Auto-save failed:', e);
        }
    }

    async loadLanguages() {
        try {
            const langs = await getAvailableLanguages({ formId: this.selectedFormId });
            this.availableLanguages = langs || [];
            if (!this.selectedLanguage) {
                this.selectedLanguage = this.formMeta?.defaultLanguage || (langs && langs.length > 0 ? langs[0] : '');
            }
        } catch (error) {
            console.error('Error loading languages:', error);
            this.availableLanguages = [];
        }
    }

    async handleLanguageChange(event) {
        this.selectedLanguage = event.detail.value;
        if (this.selectedLanguage === this.formMeta?.defaultLanguage) {
            this.translationMap = {};
            return;
        }
        this.isLoading = true;
        try {
            await this._loadTranslationsForLanguage(this.selectedLanguage);
        } finally {
            this.isLoading = false;
        }
    }

    getTranslated(type, id, field) {
        if (!this.translationMap || Object.keys(this.translationMap).length === 0) return null;
        const key = `${type}_${id}_${field}`;
        return this.translationMap[key] || null;
    }

    handleBackToSelect() {
        this._clearAutoSave();
        this.mode = 'select';
        this.formStructure = null;
        this.formMeta = null;
        this.currentStep = 0;
        this.translationMap = {};
        this.selectedResponses = {};
        this.hiddenElements = {};
        this.requiredByDependency = {};
        this.crossFieldErrors = {};
        this.availableLanguages = [];
        this._submissionId = null;
        this.submissionMeta = null;
    }

    handleNav(event) {
        const direction = event?.detail?.direction || event?.currentTarget?.dataset?.direction;
        if (direction === 'next' && !this.isLastPage) {
            this.currentStep++;
            this._scheduleAutoSave();
        } else if (direction === 'prev' && !this.isFirstPage) {
            this.currentStep--;
            this._scheduleAutoSave();
        }
    }

    handleStepClick(event) {
        const rawIdx = event?.detail?.index ?? event?.currentTarget?.dataset?.index;
        const idx = parseInt(rawIdx, 10);
        if (!isNaN(idx) && idx >= 0 && idx < this.visiblePages.length) {
            this.currentStep = idx;
            this._scheduleAutoSave();
        }
    }

    handleStepKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleStepClick(event);
        }
    }

    handleResponse(event) {
        if (this.isReadOnly) return;
        const detail = event.detail;
        if (!detail || !detail.questionId) return;

        let pages = [...this.formStructure];
        for (let page of pages) {
            if (!page.sections) continue;
            for (let section of page.sections) {
                if (!section.questions) continue;
                for (let i = 0; i < section.questions.length; i++) {
                    if (section.questions[i].questionId === detail.questionId) {
                        const oldValue = section.questions[i].value;
                        if (oldValue) {
                            const oldVals = String(oldValue).split(';');
                            for (const ov of oldVals) {
                                delete this.selectedResponses[ov];
                            }
                        }

                        section.questions[i] = {
                            ...section.questions[i],
                            value: detail.value,
                            textValue: detail.textValue
                        };

                        if (detail.value) {
                            const vals = String(detail.value).split(';');
                            for (const v of vals) {
                                this.selectedResponses[v] = true;
                            }
                        }
                        break;
                    }
                }
            }
        }
        this.formStructure = pages;
        this.selectedResponses = { ...this.selectedResponses };
        this.evaluateDependencies();
        this._scheduleAutoSave();
    }

    _buildCategoryPageMap(categories) {
        const map = {};
        for (const cat of (categories || [])) {
            if (cat.categoryId) {
                map[cat.categoryId] = (cat.pages || []).map(p => p.pageId).filter(Boolean);
            }
        }
        return map;
    }

    evaluateDependencies() {
        if (!this.formStructure) {
            this.crossFieldErrors = {};
            return;
        }
        const hidden = {};
        const required = {};
        const showTargets = {};
        const showTriggered = {};

        // Collect all dependencies and group by (targetId, action, logicGroup)
        // Category dependencies expand to all page IDs within that category
        const allDeps = [];
        for (const page of this.formStructure) {
            if (!page.dependencies) continue;
            for (const dep of page.dependencies) {
                if (dep.targetCategory) {
                    const pageIds = this.categoryPageMap[dep.targetCategory] || [];
                    for (const pid of pageIds) {
                        allDeps.push({ ...dep, targetId: pid });
                    }
                    continue;
                }
                const targetId = dep.targetPage || dep.targetSection || dep.targetQuestion;
                if (!targetId) continue;
                allDeps.push({ ...dep, targetId });
            }
        }

        // Partition: deps with a logicGroup vs ungrouped (backward-compatible)
        const grouped = {};   // key: targetId__action__logicGroup -> { operator, deps[] }
        const ungrouped = []; // evaluated individually (same as legacy behavior)

        for (const dep of allDeps) {
            if (dep.logicGroup) {
                const key = `${dep.targetId}__${dep.action}__${dep.logicGroup}`;
                if (!grouped[key]) {
                    grouped[key] = {
                        targetId: dep.targetId,
                        action: dep.action,
                        operator: dep.logicOperator || 'OR',
                        deps: []
                    };
                }
                grouped[key].deps.push(dep);
            } else {
                ungrouped.push(dep);
            }
        }

        // Evaluate ungrouped dependencies individually (legacy behavior)
        for (const dep of ungrouped) {
            const isTriggered = this.selectedResponses[dep.controllingResponse] === true;
            if (dep.action === 'Show') {
                showTargets[dep.targetId] = true;
                if (isTriggered) {
                    showTriggered[dep.targetId] = true;
                }
            } else if (dep.action === 'Hide') {
                if (isTriggered) {
                    hidden[dep.targetId] = true;
                }
            } else if (dep.action === 'Require') {
                if (isTriggered) {
                    required[dep.targetId] = true;
                }
            }
        }

        // Evaluate grouped dependencies with AND/OR logic
        for (const key of Object.keys(grouped)) {
            const group = grouped[key];
            const results = group.deps.map(d => this.selectedResponses[d.controllingResponse] === true);
            const groupTriggered = group.operator === 'AND'
                ? results.every(Boolean)
                : results.some(Boolean);

            if (group.action === 'Show') {
                showTargets[group.targetId] = true;
                if (groupTriggered) {
                    showTriggered[group.targetId] = true;
                }
            } else if (group.action === 'Hide') {
                if (groupTriggered) {
                    hidden[group.targetId] = true;
                }
            } else if (group.action === 'Require') {
                if (groupTriggered) {
                    required[group.targetId] = true;
                }
            }
        }

        for (const targetId of Object.keys(showTargets)) {
            if (!showTriggered[targetId]) {
                hidden[targetId] = true;
            }
        }

        this.hiddenElements = hidden;
        this.requiredByDependency = required;

        const visibleCount = (this.formStructure || []).filter(p => !hidden[p.pageId]).length;
        if (visibleCount > 0 && this.currentStep >= visibleCount) {
            this.currentStep = visibleCount - 1;
        }

        this._evaluateCrossFieldRules();
    }

    _evaluateCrossFieldRules() {
        if (!this.formStructure) {
            this.crossFieldErrors = {};
            return;
        }
        if (this.isReadOnly) {
            this.crossFieldErrors = {};
            return;
        }
        const hidden = this.hiddenElements || {};
        const byId = indexQuestionsById(this.formStructure);
        const errors = {};
        for (const page of this.formStructure) {
            if (!page.sections) continue;
            for (const section of page.sections) {
                if (!section.questions) continue;
                for (const q of section.questions) {
                    const qid = q.questionId;
                    if (hidden[qid]) continue;
                    const raw = q.crossFieldRules;
                    if (!raw || typeof raw !== 'string') continue;
                    let rules;
                    try {
                        rules = JSON.parse(raw);
                    } catch (e) {
                        continue;
                    }
                    if (!Array.isArray(rules)) continue;
                    for (const rule of rules) {
                        if (!rule || !rule.type || !rule.refQuestionId) continue;
                        const msg = rule.message != null ? String(rule.message).trim() : '';
                        if (!msg) continue;
                        const refQ = byId[rule.refQuestionId];
                        if (!refQ || hidden[rule.refQuestionId]) continue;
                        if (crossFieldRuleFails(q, refQ, rule)) {
                            errors[qid] = msg;
                            break;
                        }
                    }
                }
            }
        }
        this.crossFieldErrors = { ...errors };
    }

    _validateForm() {
        if (!this.formStructure) return [];
        const errors = [];
        const pages = this.visiblePages;
        for (const page of pages) {
            if (!page.sections) continue;
            for (const section of page.sections) {
                if (this.hiddenElements[section.sectionId]) continue;
                if (!section.questions) continue;
                for (const q of section.questions) {
                    if (this.hiddenElements[q.questionId]) continue;
                    const cfMsg = this.crossFieldErrors[q.questionId];
                    if (cfMsg) {
                        errors.push(cfMsg);
                    }
                    if (q.questionType === 'Long Text') {
                        const maxW = Number(q.maxWordCount);
                        if (Number.isFinite(maxW) && maxW > 0) {
                            const text = q.textValue != null ? String(q.textValue) : '';
                            if (countWords(text) > Math.floor(maxW)) {
                                const label = q.questionText || q.questionName || 'Question';
                                errors.push(`${label}: ${maxWordsExceededMessage(maxW)}`);
                            }
                        }
                    }
                    const isReq = q.isRequired || this.requiredByDependency[q.questionId];
                    if (!isReq) continue;
                    const hasValue = (q.value != null && q.value !== '') || (q.textValue != null && q.textValue !== '');
                    if (!hasValue) {
                        errors.push(q.questionText || q.questionName || 'Unnamed question');
                    }
                }
            }
        }
        return errors;
    }

    async handleFinish() {
        if (this.isReadOnly || this.isPreviewMode) return;

        this._evaluateCrossFieldRules();
        this.template.querySelectorAll('c-form-question').forEach((el) => {
            if (typeof el.reportInputValidity === 'function') {
                el.reportInputValidity();
            }
        });
        const validationErrors = this._validateForm();
        if (validationErrors.length > 0) {
            const msg =
                validationErrors.length <= 3
                    ? 'Please correct: ' + validationErrors.join('; ')
                    : `Please correct ${validationErrors.length} issues before submitting.`;
            this._showInlineAlert('Validation Error', msg, 'error');
            return;
        }

        this.isLoading = true;
        try {
            await this._performAutoSave();
            if (this._submissionId) {
                await submitFormApex({ submissionId: this._submissionId });
            }
            this._clearAutoSave();
            this.mode = 'success';
        } catch (error) {
            this._notify('Error', error?.body?.message || error?.message || 'Failed to submit form', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleStartNew() {
        if (this.formId) {
            this._selectedFormId = this.formId;
            this._launchForm();
        } else {
            this.handleBackToSelect();
        }
    }

    handleDismissInline() {
        this.inlineMessage = { ...this.inlineMessage, visible: false };
    }

    _showInlineAlert(title, message, variant) {
        this.inlineMessage = { title, message, variant, visible: true };
        if (this._notifyTimer) clearTimeout(this._notifyTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._notifyTimer = setTimeout(() => {
            this.inlineMessage = { ...this.inlineMessage, visible: false };
        }, 6000);
    }

    _notify(title, message, variant) {
        try {
            this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
        } catch (e) {
            this._showInlineAlert(title, message, variant);
        }
    }

    errorCallback(error, stack) {
        this._notify('Component Error', error?.message || 'An unexpected error occurred', 'error');
        console.error('FormRenderer error:', error, 'Stack:', stack);
    }
}

function trimAnswerString(v) {
    if (v == null) return '';
    return String(v).trim();
}

function parseNumberAnswer(q) {
    const s = trimAnswerString(q.textValue != null ? q.textValue : q.value);
    if (!s) return NaN;
    return parseFloat(s);
}

function indexQuestionsById(formStructure) {
    const map = {};
    for (const page of formStructure || []) {
        for (const section of page.sections || []) {
            for (const q of section.questions || []) {
                if (q && q.questionId) {
                    map[q.questionId] = q;
                }
            }
        }
    }
    return map;
}

/**
 * Cross-field rules: if either side has no comparable value, skip (no error) so optional fields do not block.
 */
function crossFieldRuleFails(dep, ref, rule) {
    const t = dep.questionType;
    if (t !== ref.questionType) return false;

    if (t === 'Date') {
        const dv = trimAnswerString(dep.textValue != null ? dep.textValue : dep.value);
        const rv = trimAnswerString(ref.textValue != null ? ref.textValue : ref.value);
        if (!dv || !rv) return false;
        if (rule.type === 'dateOnOrAfter') return dv < rv;
        if (rule.type === 'dateAfter') return dv <= rv;
        if (rule.type === 'dateOnOrBefore') return dv > rv;
        if (rule.type === 'dateBefore') return dv >= rv;
        return false;
    }

    if (t === 'Number') {
        const dn = parseNumberAnswer(dep);
        const rn = parseNumberAnswer(ref);
        if (!Number.isFinite(dn) || !Number.isFinite(rn)) return false;
        if (rule.type === 'greaterOrEqual') return dn < rn;
        if (rule.type === 'greaterThan') return dn <= rn;
        if (rule.type === 'lessOrEqual') return dn > rn;
        if (rule.type === 'lessThan') return dn >= rn;
        return false;
    }

    return false;
}
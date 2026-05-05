/**
 * @description       : Visual Form Builder - drag-and-drop interface with live preview
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   18-03-2026   Daniel Murracas     Full D&D overhaul: unified handler, cross-container moves, visual feedback
 * ------------------------------------------------------------
**/
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getForms from '@salesforce/apex/FormBuilderService.getForms';
import saveForm from '@salesforce/apex/FormBuilderService.saveForm';
import deleteForm from '@salesforce/apex/FormBuilderService.deleteForm';
import saveCategory from '@salesforce/apex/FormBuilderService.saveCategory';
import deleteCategory from '@salesforce/apex/FormBuilderService.deleteCategory';
import savePage from '@salesforce/apex/FormBuilderService.savePage';
import deletePage from '@salesforce/apex/FormBuilderService.deletePage';
import saveSection from '@salesforce/apex/FormBuilderService.saveSection';
import deleteSection from '@salesforce/apex/FormBuilderService.deleteSection';
import saveQuestion from '@salesforce/apex/FormBuilderService.saveQuestion';
import deleteQuestion from '@salesforce/apex/FormBuilderService.deleteQuestion';
import saveResponse from '@salesforce/apex/FormBuilderService.saveResponse';
import deleteResponse from '@salesforce/apex/FormBuilderService.deleteResponse';
import saveDependency from '@salesforce/apex/FormBuilderService.saveDependency';
import deleteDependency from '@salesforce/apex/FormBuilderService.deleteDependency';
import reorderItems from '@salesforce/apex/FormBuilderService.reorderItems';
import moveItem from '@salesforce/apex/FormBuilderService.moveItem';
import getFullFormStructure from '@salesforce/apex/FormBuilderService.getFullFormStructure';
import cloneForm from '@salesforce/apex/FormBuilderService.cloneForm';
import getFeatureSettings from '@salesforce/apex/FeatureSettingsService.getFeatureSettings';
import getFormTargets from '@salesforce/apex/FieldMappingService.getFormTargets';
import searchLibraryQuestions from '@salesforce/apex/LibraryAssetService.searchLibraryQuestions';
import searchLibrarySections from '@salesforce/apex/LibraryAssetService.searchLibrarySections';
import injectLibraryQuestion from '@salesforce/apex/LibraryAssetService.injectLibraryQuestion';
import injectLibrarySection from '@salesforce/apex/LibraryAssetService.injectLibrarySection';
import promoteQuestionToLibrary from '@salesforce/apex/LibraryAssetService.promoteQuestionToLibrary';
import promoteSectionToLibrary from '@salesforce/apex/LibraryAssetService.promoteSectionToLibrary';
import getAssetLibraryFormId from '@salesforce/apex/LibraryAssetService.getAssetLibraryFormId';
import { isDropCompatible as dragIsDropCompatible } from 'c/formBuilderDragUtil';

const QUESTION_TYPES = [
    { label: 'Text Question', value: 'Text', icon: 'utility:text' },
    { label: 'Long Text Question', value: 'Long Text', icon: 'utility:textarea' },
    { label: 'Picklist Question', value: 'Picklist', icon: 'utility:picklist_type' },
    { label: 'Multi-Select Question', value: 'Multi-Select', icon: 'utility:multi_select_checkbox' },
    { label: 'Checkbox Question', value: 'Checkbox', icon: 'utility:check' },
    { label: 'Date Question', value: 'Date', icon: 'utility:date_input' },
    { label: 'Number Question', value: 'Number', icon: 'utility:number_input' },
    { label: 'File Question', value: 'File', icon: 'utility:file' },
    { label: 'Table Question', value: 'Table', icon: 'utility:table' }
];

const RESPONSE_TYPES = new Set(['Picklist', 'Multi-Select', 'Checkbox']);

const TOOLBOX_ITEMS = [
    { key: 'category', label: 'Category', dragType: 'category', icon: 'utility:summary' },
    { key: 'page', label: 'Page', dragType: 'page', icon: 'utility:page' },
    { key: 'section', label: 'Section', dragType: 'section', icon: 'utility:layout' },
    ...QUESTION_TYPES.map(qt => ({
        key: 'question-' + qt.value,
        label: qt.label,
        dragType: 'question',
        questionType: qt.value,
        icon: qt.icon
    })),
    { key: 'response', label: 'Response', dragType: 'response', icon: 'utility:choice' }
];

const REPOSITORY_TOOLBOX_ITEMS = [
    {
        key: 'question-repository',
        label: 'Question Repository',
        dragType: 'questionRepository',
        icon: 'utility:collection'
    },
    {
        key: 'section-repository',
        label: 'Section Repository',
        dragType: 'sectionRepository',
        icon: 'utility:copy_to_clipboard'
    }
];

export default class FormBuilderVisual extends LightningElement {
    /** When true, loads the hidden asset-library form and hides form list / back / clone. Used by the Asset Repository tab. */
    @api repositoryMode = false;
    /** Initial canvas selection in repository mode: `section` or `question`. */
    @api repositoryFocusType;
    /** Record Id of the library section or question to select after load. */
    @api repositoryFocusId;

    @track forms = [];
    @track selectedFormId = null;
    @track formStructure = null;
    @track selectedElement = null;
    @track selectedElementType = '';
    @track isDragging = false;
    @track dragType = '';
    @track showPreview = false;
    @track showDependencyBuilder = false;
    @track currentView = 'list';
    @track isLoading = false;
    @track showNewFormModal = false;
    @track newFormName = '';
    @track newFormDescription = '';
    @track dragQuestionType = '';
    @track dragItemType = '';
    @track draggingSourceId = null;
    @track collapsedIds = {};
    @track featureSettings = {
        scoring: true,
        fieldMapping: true,
        translations: true,
        assetRepository: false,
        characterCountdown: false
    };
    @track showCloneModal = false;
    @track showConfigModal = false;
    @track configLayoutMode = 'Classic';
    @track cloneFormName = '';
    @track fieldMappingTargets = [];
    @track questionMappingMap = {};
    @track showFieldMappingPanel = false;
    @track expandedSections = { basic: true, helpValidation: false, crossFieldRules: false, styling: false, translations: false, scoring: false, fileOptions: false, tableOptions: false, dependencies: false, fieldMapping: false, options: false, repository: false };
    formSearchTerm = '';

    @track showRepositoryModal = false;
    repositoryModalKind = '';
    pendingRepositoryParentId = null;
    pendingRepositoryPosition = 0;
    @track repositorySearchTerm = '';
    @track repositoryResults = [];
    @track repositorySearching = false;
    @track showPromoteConfirm = false;
    promoteConfirmKind = '';
    currentLayoutMode = 'classic';
    _repositoryFocusApplied = false;

    get isListView() {
        if (this.repositoryMode) {
            return false;
        }
        return this.currentView === 'list';
    }
    get isBuilderView() {
        if (this.repositoryMode) {
            return true;
        }
        return this.currentView === 'builder';
    }

    get showBuilderBackButton() {
        return !this.repositoryMode;
    }
    get showCloneInToolbar() {
        return !this.repositoryMode;
    }

    get showConfigInToolbar() {
        return !this.repositoryMode;
    }

    get formLayoutMode() {
        return this.configLayoutMode || this.formStructure?.form?.C_Layout_Mode__c || 'Classic';
    }

    /** True when editing a library section or question from Asset Repository (narrow UI). */
    get repositoryAssetEditUi() {
        if (!this.repositoryMode || !this.repositoryFocusId) {
            return false;
        }
        const t = (this.repositoryFocusType || '').toLowerCase();
        return t === 'section' || t === 'question';
    }

    /** Hide left toolbox entirely when editing a library question only. */
    get showRepositoryToolbox() {
        if (!this.repositoryMode) {
            return true;
        }
        if (!this.repositoryAssetEditUi) {
            return true;
        }
        return (this.repositoryFocusType || '').toLowerCase() !== 'question';
    }

    get builderLayoutClass() {
        let cls = 'builder-layout';
        if (this.repositoryMode && !this.showRepositoryToolbox) {
            cls += ' repository-no-toolbox';
        }
        return cls;
    }

    get filteredForms() {
        if (!this.forms || !this.forms.length) return [];
        const term = (this.formSearchTerm || '').toLowerCase().trim();
        let list = this.forms;
        if (term) {
            list = list.filter(f =>
                (f.Name || '').toLowerCase().includes(term) ||
                (f.C_Description__c || '').toLowerCase().includes(term)
            );
        }
        const latestId = this.forms.length > 0 ? this.forms[0].Id : null;
        return list.map(f => ({
            ...f,
            isLatest: f.Id === latestId,
            formattedDate: this._formatRelativeDate(f.LastModifiedDate),
            displayVersion: f.C_Version__c ? `v${f.C_Version__c}` : ''
        }));
    }

    get hasFilteredForms() {
        return this.filteredForms.length > 0;
    }

    handleFormSearch(event) {
        this.formSearchTerm = event.detail.value;
    }

    _formatRelativeDate(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);
        if (diffMins < 1) return 'just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined });
    }

    get canvasClass() {
        let cls = 'canvas-panel';
        if (this.hasCanvasContent) cls += ' has-content';
        if (this.showPreview) cls += ' preview-mode';
        if (this.isDragging) cls += ' is-dragging';
        return cls;
    }

    get hasCanvasContent() {
        const fs = this.formStructure;
        if (!fs) return false;
        const pages = fs.pages || [];
        const cats = fs.categories || [];
        return pages.length > 0 || cats.length > 0;
    }

    /** Edit-mode canvas: use isolated rows when in repository asset edit. */
    get canvasEditHasRows() {
        if (!this.formStructure) {
            return false;
        }
        if (this.repositoryAssetEditUi) {
            return (this.displayCanvasRows || []).length > 0;
        }
        return this.hasCanvasContent;
    }

    getUncategorizedPagesRaw() {
        const fs = this.formStructure;
        if (!fs) return [];
        const explicit = fs.uncategorizedPages;
        if (Array.isArray(explicit)) {
            return explicit;
        }
        const pbc = fs.pagesByCategory || {};
        const fromMap = pbc.null ?? pbc['null'];
        if (Array.isArray(fromMap) && fromMap.length > 0) {
            return fromMap;
        }
        return (fs.pages || []).filter(p => !p.C_Category__c);
    }

    getPagesForCategoryKey(categoryId) {
        const fs = this.formStructure;
        if (!fs) return [];
        if (categoryId === undefined || categoryId === null || categoryId === '') {
            return this.getUncategorizedPagesRaw();
        }
        return fs.pagesByCategory?.[categoryId] || [];
    }

    _normalizePageCategoryId(value) {
        if (value === undefined || value === null || value === '') {
            return null;
        }
        return value;
    }

    _computeCategoryInsertOrder(position) {
        const catCount = (this.formStructure?.categories || []).length;
        return position !== undefined && position !== null ? position + 1 : catCount + 1;
    }

    _enrichPageTree(pages, pageCategoryParentKey) {
        const { targetPages, targetSections, targetQuestions } = this.dependencyTargetIds;
        const parentKey = pageCategoryParentKey === undefined || pageCategoryParentKey === null ? '' : pageCategoryParentKey;
        return pages.map((page, pageIdx) => {
            const sections = (this.formStructure?.sectionsByPage?.[page.Id] || []).map((section, secIdx) => {
                const questions = (this.formStructure?.questionsBySection?.[section.Id] || []).map((question, qIdx) => {
                    const responses = (this.formStructure?.responsesByQuestion?.[question.Id] || []).map((resp, rIdx) => ({
                        ...resp,
                        displayLabel: resp.C_Response_Text__c || resp.Name,
                        cssClass: this.getResponseCssClass(resp.Id),
                        pointsDisplay: resp.C_Points__c ? `${resp.C_Points__c} pts` : '',
                        dropPosition: rIdx + 1
                    }));
                    const qType = question.C_Type__c || 'Text';
                    const mappingInfo = this._getQuestionMappingBadge(question.Id);
                    const optionsGroupHighlight =
                        (qType === 'Picklist' || qType === 'Multi-Select') &&
                        responses.length > 0;
                    const questionRowSelected =
                        this.selectedElement?.Id === question.Id &&
                        this.selectedElementType === 'question';
                    const canvasQuestionBlockClass =
                        optionsGroupHighlight && questionRowSelected
                            ? 'canvas-question-block is-options-group-selected'
                            : 'canvas-question-block';
                    return {
                        ...question,
                        displayLabel: question.C_Question_Text__c || question.Name,
                        cssClass: this.getQuestionCssClass(question.Id),
                        canvasQuestionBlockClass,
                        typeBadge: qType,
                        isMapped: mappingInfo.isMapped,
                        mappingBadgeLabel: mappingInfo.label,
                        mappingBadgeClass: mappingInfo.cssClass,
                        isDependent: targetQuestions.has(question.Id),
                        responses,
                        hasResponses: responses.length > 0,
                        supportsResponses: RESPONSE_TYPES.has(qType),
                        dropPosition: qIdx + 1,
                        isTextPreview: qType === 'Text',
                        isLongTextPreview: qType === 'Long Text',
                        isNumberPreview: qType === 'Number',
                        isDatePreview: qType === 'Date',
                        isCheckboxPreview: qType === 'Checkbox',
                        isFilePreview: qType === 'File',
                        isPicklistPreview: qType === 'Picklist',
                        isMultiSelectPreview: qType === 'Multi-Select',
                        isTablePreview: qType === 'Table'
                    };
                });
                return {
                    ...section,
                    cssClass: this.getSectionCssClass(section.Id),
                    isDependent: targetSections.has(section.Id),
                    questions,
                    hasQuestions: questions.length > 0,
                    dropPosition: secIdx + 1,
                    isCollapsed: this.collapsedIds[section.Id] === true,
                    collapseIcon: this.collapsedIds[section.Id] ? 'utility:chevronright' : 'utility:chevrondown'
                };
            });
            return {
                ...page,
                pageCategoryParentKey: parentKey,
                cssClass: this.getPageCssClass(page.Id),
                isDependent: targetPages.has(page.Id),
                sections,
                hasSections: sections.length > 0,
                dropPosition: pageIdx + 1,
                isCollapsed: this.collapsedIds[page.Id] === true,
                collapseIcon: this.collapsedIds[page.Id] ? 'utility:chevronright' : 'utility:chevrondown'
            };
        });
    }

    get canvasRows() {
        if (!this.formStructure) return [];
        const categoriesRaw = this.formStructure.categories || [];
        const targetCategories = new Set();
        for (const dep of (this.formStructure?.dependencies || [])) {
            if (dep.C_Target_Category__c) targetCategories.add(dep.C_Target_Category__c);
        }
        const rows = categoriesRaw.map((category, catIdx) => {
            const catPages = this.getPagesForCategoryKey(category.Id);
            const pages = this._enrichPageTree(catPages, category.Id);
            return {
                rowType: 'category',
                rowKey: category.Id,
                isCategoryRow: true,
                isRootPagesRow: false,
                hidePageBody: this.collapsedIds[category.Id] === true,
                rowOuterClass: this.getCategoryCssClass(category.Id),
                pageDropzone: 'category',
                pageDropParentId: category.Id,
                ...category,
                cssClass: this.getCategoryCssClass(category.Id),
                isDependent: targetCategories.has(category.Id),
                pages,
                hasPages: pages.length > 0,
                dropPosition: catIdx + 1,
                isCollapsed: this.collapsedIds[category.Id] === true,
                collapseIcon: this.collapsedIds[category.Id] ? 'utility:chevronright' : 'utility:chevrondown',
                iconName: category.C_Icon__c || 'utility:bundle'
            };
        });
        const uncategorized = this.getUncategorizedPagesRaw();
        if (uncategorized.length > 0) {
            const pages = this._enrichPageTree(uncategorized, '');
            rows.push({
                rowType: 'rootPages',
                rowKey: 'root',
                isCategoryRow: false,
                isRootPagesRow: true,
                hidePageBody: false,
                rowOuterClass: 'canvas-root-pages',
                pageDropzone: 'rootPages',
                pageDropParentId: null,
                pages,
                hasPages: true,
                dropPosition: rows.length + 1,
                isCollapsed: false,
                collapseIcon: 'utility:chevrondown'
            });
        }
        return rows;
    }

    /**
     * When editing a library asset, show only the focused page/section/question branch.
     */
    filterCanvasRowsToRepositoryFocus(fullRows) {
        const ft = (this.repositoryFocusType || '').toLowerCase();
        const fid = this.repositoryFocusId;
        if (!fid || (ft !== 'section' && ft !== 'question')) {
            return fullRows;
        }

        let targetPageId;
        let targetSectionId;
        if (ft === 'section') {
            targetSectionId = fid;
            targetPageId = this.findParentId('section', fid);
        } else {
            targetSectionId = this.findParentId('question', fid);
            targetPageId = targetSectionId ? this.findParentId('section', targetSectionId) : null;
        }
        if (!targetPageId || !targetSectionId) {
            return [];
        }

        const suppress = { repositorySuppressCanvasChrome: true };
        const out = [];
        for (const row of fullRows) {
            const newPages = [];
            for (const page of row.pages || []) {
                if (page.Id !== targetPageId) {
                    continue;
                }
                const newSections = [];
                for (const sec of page.sections || []) {
                    if (sec.Id !== targetSectionId) {
                        continue;
                    }
                    let questions = sec.questions || [];
                    if (ft === 'question') {
                        questions = questions.filter(q => q.Id === fid);
                    }
                    newSections.push({
                        ...sec,
                        ...suppress,
                        questions: questions.map(q => ({ ...q, ...suppress })),
                        hasQuestions: questions.length > 0
                    });
                }
                if (newSections.length === 0) {
                    continue;
                }
                newPages.push({
                    ...page,
                    ...suppress,
                    sections: newSections,
                    hasSections: true
                });
            }
            if (newPages.length === 0) {
                continue;
            }
            out.push({
                ...row,
                ...suppress,
                pages: newPages,
                hasPages: true
            });
        }
        return out;
    }

    get displayCanvasRows() {
        const full = this.canvasRows;
        if (!this.repositoryAssetEditUi) {
            return full;
        }
        return this.filterCanvasRowsToRepositoryFocus(full);
    }

    get formName() {
        return this.formStructure?.form?.Name || 'Untitled Form';
    }

    get formStatus() {
        return this.formStructure?.form?.C_Status__c || 'Draft';
    }

    get dependencyTargetIds() {
        const targetPages = new Set();
        const targetSections = new Set();
        const targetQuestions = new Set();
        for (const dep of (this.formStructure?.dependencies || [])) {
            if (dep.C_Target_Page__c) targetPages.add(dep.C_Target_Page__c);
            if (dep.C_Target_Section__c) targetSections.add(dep.C_Target_Section__c);
            if (dep.C_Target_Question__c) targetQuestions.add(dep.C_Target_Question__c);
        }
        return { targetPages, targetSections, targetQuestions };
    }

    get categories() {
        return this.canvasRows.filter(r => r.rowType === 'category');
    }

    get dependencies() {
        return this.formStructure?.dependencies || [];
    }

    get hasDependencies() {
        return this.dependencies.length > 0;
    }

    get enrichedDependencies() {
        const responseMap = {};
        const questionForResponse = {};
        const categoryMap = {};
        const pageMap = {};
        const sectionMap = {};
        const questionMap = {};

        for (const cat of this.formStructure?.categories || []) {
            categoryMap[cat.Id] = cat.Name;
        }
        for (const page of this.formStructure?.pages || []) {
            pageMap[page.Id] = page.Name;
        }
        const secMap = this.formStructure?.sectionsByPage || {};
        for (const pageId of Object.keys(secMap)) {
            for (const sec of secMap[pageId]) {
                sectionMap[sec.Id] = sec.Name;
            }
        }
        const qMap = this.formStructure?.questionsBySection || {};
        for (const secId of Object.keys(qMap)) {
            for (const q of qMap[secId]) {
                questionMap[q.Id] = q.C_Question_Text__c || q.Name;
                const rMap = this.formStructure?.responsesByQuestion || {};
                for (const r of (rMap[q.Id] || [])) {
                    responseMap[r.Id] = r.C_Response_Text__c || r.Name;
                    questionForResponse[r.Id] = q.Name;
                }
            }
        }

        return this.dependencies.map(d => {
            const respLabel = responseMap[d.C_Controlling_Response__c] || d.C_Controlling_Response__c;
            const qLabel = questionForResponse[d.C_Controlling_Response__c] || '';
            const targetName = d.C_Target_Type__c === 'Category'
                ? categoryMap[d.C_Target_Category__c] || ''
                : d.C_Target_Type__c === 'Page'
                    ? pageMap[d.C_Target_Page__c] || ''
                    : d.C_Target_Type__c === 'Section'
                        ? sectionMap[d.C_Target_Section__c] || ''
                        : d.C_Target_Type__c === 'Question'
                            ? questionMap[d.C_Target_Question__c] || ''
                            : '';
            return {
                ...d,
                controllingResponseLabel: qLabel ? `${qLabel} > ${respLabel}` : respLabel,
                targetLabel: `${d.C_Target_Type__c}: ${targetName}`
            };
        });
    }

    get previewButtonLabel() {
        return this.showPreview ? 'Edit Mode' : 'Preview';
    }

    get previewButtonVariant() {
        return this.showPreview ? 'brand' : 'neutral';
    }

    get previewButtonIcon() {
        return this.showPreview ? 'utility:edit' : 'utility:preview';
    }

    get hasSelectedElement() {
        return this.selectedElement !== null;
    }

    get propertiesPanelTitle() {
        if (!this.selectedElementType) return 'Properties';
        const typeLabel = this.selectedElementType.charAt(0).toUpperCase() + this.selectedElementType.slice(1);
        return `Properties - ${typeLabel}`;
    }

    get isFormProperties() { return this.selectedElementType === 'form'; }
    get isCategoryProperties() { return this.selectedElementType === 'category'; }
    get isPageProperties() { return this.selectedElementType === 'page'; }
    get isSectionProperties() { return this.selectedElementType === 'section'; }
    get isQuestionProperties() { return this.selectedElementType === 'question'; }
    get isSelectedQuestionTable() { return this.isQuestionProperties && this.selectedElement && this.selectedElement.C_Type__c === 'Table'; }
    get isSelectedQuestionFile() { return this.isQuestionProperties && this.selectedElement && this.selectedElement.C_Type__c === 'File'; }
    get isSelectedQuestionNumber() { return this.isQuestionProperties && this.selectedElement && this.selectedElement.C_Type__c === 'Number'; }
    get isSelectedQuestionLongText() { return this.isQuestionProperties && this.selectedElement && this.selectedElement.C_Type__c === 'Long Text'; }
    get isSelectedQuestionDate() { return this.isQuestionProperties && this.selectedElement && this.selectedElement.C_Type__c === 'Date'; }
    /** Show for any selected question so admins always find the panel; Date/Number get full editor inside. */
    get showCrossFieldRules() { return this.isQuestionProperties; }

    get showCrossFieldRulesInProperties() {
        return this.showCrossFieldRules && !this.repositoryAssetEditUi;
    }

    get showRepositoryPromoteInProperties() {
        return this.showAssetRepository && !this.repositoryAssetEditUi;
    }

    get showQuestionFieldMappingPanel() {
        return this.showFieldMapping && !this.repositoryAssetEditUi;
    }
    get isResponseProperties() { return this.selectedElementType === 'response'; }

    get layoutSpanOptions() {
        return [
            { label: 'Full', value: 'Full' },
            { label: 'Half', value: 'Half' }
        ];
    }

    get allQuestionsForMapping() {
        if (!this.formStructure) return [];
        const questions = [];
        const qMap = this.formStructure.questionsBySection || {};
        for (const secId of Object.keys(qMap)) {
            for (const q of qMap[secId]) {
                questions.push({
                    label: q.C_Question_Text__c || q.Name,
                    value: q.Id
                });
            }
        }
        return questions;
    }

    get allQuestionsFlat() {
        if (!this.formStructure) return [];
        const questions = [];
        const secMap = this.formStructure.sectionsByPage || {};
        const qMap = this.formStructure.questionsBySection || {};
        const sectionNames = {};
        for (const pageId of Object.keys(secMap)) {
            for (const sec of secMap[pageId]) {
                sectionNames[sec.Id] = sec.Name;
            }
        }
        for (const secId of Object.keys(qMap)) {
            const secName = sectionNames[secId] || '';
            for (const q of qMap[secId]) {
                const questionLabel = q.C_Question_Text__c || q.Name;
                questions.push({
                    label: secName ? `${secName} > ${questionLabel}` : questionLabel,
                    value: q.Id,
                    type: q.C_Type__c || 'Text'
                });
            }
        }
        return questions;
    }

    get parsedCrossFieldRules() {
        if (!this.selectedElement || !this.selectedElement.C_Cross_Field_Rules_JSON__c) return [];
        try {
            return JSON.parse(this.selectedElement.C_Cross_Field_Rules_JSON__c);
        } catch (e) {
            return [];
        }
    }

    get formStatusOptions() {
        return [
            { label: 'Draft', value: 'Draft' },
            { label: 'Testing', value: 'Testing' },
            { label: 'Published', value: 'Published' },
            { label: 'Archived', value: 'Archived' }
        ];
    }

    get questionTypeOptions() {
        return QUESTION_TYPES.map(qt => ({ label: qt.label.replace(' Question', ''), value: qt.value }));
    }

    get dependencyActionOptions() {
        return [
            { label: 'Show', value: 'Show' },
            { label: 'Hide', value: 'Hide' },
            { label: 'Require', value: 'Require' }
        ];
    }

    get categoriesWithQuestions() {
        if (!this.formStructure) return new Set();
        const withQuestions = new Set();
        const sectionsByPage = this.formStructure.sectionsByPage || {};
        const questionsBySection = this.formStructure.questionsBySection || {};
        for (const cat of this.formStructure.categories || []) {
            const pages = this.getPagesForCategoryKey(cat.Id);
            outer: for (const page of pages) {
                const sections = sectionsByPage[page.Id] || [];
                for (const section of sections) {
                    if ((questionsBySection[section.Id] || []).length > 0) {
                        withQuestions.add(cat.Id);
                        break outer;
                    }
                }
            }
        }
        return withQuestions;
    }

    get dependencyTargetTypeOptions() {
        const opts = [];
        if (this.categoriesWithQuestions.size > 0) {
            opts.push({ label: 'Category', value: 'Category' });
        }
        opts.push(
            { label: 'Page', value: 'Page' },
            { label: 'Section', value: 'Section' },
            { label: 'Question', value: 'Question' }
        );
        return opts;
    }

    get allResponses() {
        if (!this.formStructure) return [];
        const responses = [];
        const respMap = this.formStructure.responsesByQuestion || {};
        const qMap = this.formStructure.questionsBySection || {};
        const secMap = this.formStructure.sectionsByPage || {};
        const pages = this.formStructure.pages || [];
        const questionNames = {};
        const questionToSection = {};
        const sectionToPage = {};
        const pageToCategory = {};

        for (const page of pages) {
            pageToCategory[page.Id] = page.C_Category__c || null;
        }
        for (const pageId of Object.keys(secMap)) {
            for (const sec of secMap[pageId]) {
                sectionToPage[sec.Id] = pageId;
            }
        }
        for (const secId of Object.keys(qMap)) {
            for (const q of qMap[secId]) {
                questionNames[q.Id] = q.Name;
                questionToSection[q.Id] = secId;
            }
        }
        for (const qId of Object.keys(respMap)) {
            const qName = questionNames[qId] || '';
            const sectionId = questionToSection[qId] || null;
            const pageId = sectionId ? sectionToPage[sectionId] || null : null;
            const categoryId = pageId ? pageToCategory[pageId] || null : null;
            for (const r of respMap[qId]) {
                const rLabel = r.C_Response_Text__c || r.Name;
                responses.push({
                    label: qName ? `${qName} > ${rLabel}` : rLabel,
                    value: r.Id,
                    questionId: qId,
                    sectionId,
                    pageId,
                    categoryId
                });
            }
        }
        return responses;
    }

    get allTargetElements() {
        if (!this.formStructure) return [];
        const elements = [];
        const withQuestions = this.categoriesWithQuestions;
        for (const cat of this.formStructure.categories || []) {
            if (withQuestions.has(cat.Id)) {
                elements.push({ label: `Category: ${cat.Name}`, value: cat.Id, type: 'Category' });
            }
        }
        for (const page of this.formStructure.pages || []) {
            elements.push({ label: `Page: ${page.Name}`, value: page.Id, type: 'Page' });
        }
        const secMap = this.formStructure.sectionsByPage || {};
        for (const pageId of Object.keys(secMap)) {
            for (const sec of secMap[pageId]) {
                elements.push({ label: `Section: ${sec.Name}`, value: sec.Id, type: 'Section' });
            }
        }
        const qMap = this.formStructure.questionsBySection || {};
        for (const secId of Object.keys(qMap)) {
            for (const q of qMap[secId]) {
                elements.push({ label: `Question: ${q.Name}`, value: q.Id, type: 'Question' });
            }
        }
        return elements;
    }

    getCategoryCssClass(categoryId) {
        return this.selectedElement?.Id === categoryId && this.selectedElementType === 'category'
            ? 'canvas-category is-selected' : 'canvas-category';
    }

    getPageCssClass(pageId) {
        return this.selectedElement?.Id === pageId && this.selectedElementType === 'page'
            ? 'canvas-page is-selected' : 'canvas-page';
    }

    getSectionCssClass(sectionId) {
        return this.selectedElement?.Id === sectionId && this.selectedElementType === 'section'
            ? 'canvas-section is-selected' : 'canvas-section';
    }

    getQuestionCssClass(questionId) {
        return this.selectedElement?.Id === questionId && this.selectedElementType === 'question'
            ? 'canvas-question is-selected' : 'canvas-question';
    }

    getResponseCssClass(responseId) {
        return this.selectedElement?.Id === responseId && this.selectedElementType === 'response'
            ? 'canvas-response is-selected' : 'canvas-response';
    }

    get showScoring() { return this.featureSettings.scoring; }
    get showFieldMapping() { return this.featureSettings.fieldMapping; }
    get showTranslations() { return this.featureSettings.translations; }
    get showAssetRepository() { return this.featureSettings.assetRepository === true; }

    get repositoryModalTitle() {
        return this.repositoryModalKind === 'question' ? 'Select library question' : 'Select library section';
    }

    get repositoryResultsEmpty() {
        return !this.repositorySearching && (!this.repositoryResults || this.repositoryResults.length === 0);
    }

    get promoteConfirmMessage() {
        return this.promoteConfirmKind === 'question'
            ? 'A copy of this question will be added to the public library.'
            : 'A copy of this section and its nested questions will be added to the public library.';
    }

    get toolboxItems() {
        let items;
        if (this.repositoryMode) {
            items = [...TOOLBOX_ITEMS];
        } else if (!this.showAssetRepository) {
            items = [...TOOLBOX_ITEMS];
        } else {
            items = [...TOOLBOX_ITEMS, ...REPOSITORY_TOOLBOX_ITEMS];
        }
        if (this.repositoryAssetEditUi && (this.repositoryFocusType || '').toLowerCase() === 'section') {
            const stripKeys = new Set(['category', 'page', 'section']);
            items = items.filter(
                i => !stripKeys.has(i.key) && i.dragType !== 'sectionRepository'
            );
        }
        return items;
    }

    get formDefaultLanguage() {
        return this.formStructure?.form?.C_Default_Language__c || '';
    }

    get propSections() {
        const make = (key, defaultOpen) => {
            const isOpen = this.expandedSections[key] !== undefined ? this.expandedSections[key] : defaultOpen;
            return { open: isOpen, chevron: isOpen ? 'utility:chevrondown' : 'utility:chevronright' };
        };
        return {
            basic: make('basic', true),
            helpValidation: make('helpValidation', false),
            crossFieldRules: make('crossFieldRules', false),
            scoring: make('scoring', false),
            fileOptions: make('fileOptions', false),
            tableOptions: make('tableOptions', false),
            dependencies: make('dependencies', false),
            fieldMapping: make('fieldMapping', false),
        options: make('options', false),
            styling: make('styling', false),
            translations: make('translations', false),
            repository: make('repository', false)
        };
    }

    get selectedQuestionMappings() {
        if (!this.isQuestionProperties || !this.selectedElement) return [];
        return this.questionMappingMap[this.selectedElement.Id] || [];
    }

    get hasSelectedQuestionMappings() {
        return this.selectedQuestionMappings.length > 0;
    }

    connectedCallback() {
        if (this.repositoryMode) {
            this.isLoading = true;
        }
        this.initializeComponent();
    }

    async initializeComponent() {
        await this.loadFeatureSettings();
        if (this.repositoryMode) {
            try {
                const libFormId = await getAssetLibraryFormId();
                await this.selectForm(libFormId);
            } catch (error) {
                this.showError('Error loading asset library', error);
                this.isLoading = false;
            }
        } else {
            await this.loadForms();
        }
    }

    async loadFeatureSettings() {
        try {
            this.featureSettings = await getFeatureSettings();
        } catch(e) { /* defaults already set */ }
    }

    async loadForms() {
        this.isLoading = true;
        try {
            this.forms = await getForms();
        } catch (error) {
            this.showError('Error loading forms', error);
        } finally {
            this.isLoading = false;
        }
    }

    async selectForm(formId) {
        this.selectedFormId = formId;
        this.currentView = 'builder';
        this.selectedElement = null;
        this.selectedElementType = '';
        this.showPreview = false;
        await this.refreshFormStructure();
    }

    async refreshFormStructure() {
        if (!this.selectedFormId) return;
        this.isLoading = true;
        try {
            this.formStructure = await getFullFormStructure({ formId: this.selectedFormId });
            if (this.showFieldMapping) {
                this.loadFieldMappings();
            }
            if (
                this.repositoryMode &&
                this.repositoryFocusId &&
                !this._repositoryFocusApplied
            ) {
                const focusType = (this.repositoryFocusType || '').toLowerCase();
                const elementType = focusType === 'section' || focusType === 'question' ? focusType : '';
                if (elementType) {
                    const focused = this.findElementById(elementType, this.repositoryFocusId);
                    if (focused) {
                        this.selectElement(focused, elementType);
                    } else {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Item not found',
                                message:
                                    'The selected library item could not be found. It may have been deleted.',
                                variant: 'warning'
                            })
                        );
                    }
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Invalid selection',
                            message: 'Repository focus type must be section or question.',
                            variant: 'warning'
                        })
                    );
                }
                this._repositoryFocusApplied = true;
            } else if (this.selectedElement && this.selectedElementType) {
                const refreshed = this.findElementById(this.selectedElementType, this.selectedElement.Id);
                if (refreshed) {
                    this.selectedElement = JSON.parse(JSON.stringify(refreshed));
                }
            }
        } catch (error) {
            this.showError('Error loading form structure', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleFormSelect(event) {
        const formId = event.currentTarget.dataset.id;
        this.selectForm(formId);
    }

    handleBackToList() {
        if (this.repositoryMode) {
            return;
        }
        this.currentView = 'list';
        this.selectedFormId = null;
        this.formStructure = null;
        this.selectedElement = null;
        this.selectedElementType = '';
        this.showPreview = false;
        this.showDependencyBuilder = false;
        this.loadForms();
    }

    handleOpenNewForm() {
        this.showNewFormModal = true;
        this.newFormName = '';
        this.newFormDescription = '';
    }

    handleCloseNewForm() {
        this.showNewFormModal = false;
    }

    handleNewFormNameChange(event) {
        this.newFormName = event.detail.value;
    }

    handleNewFormDescriptionChange(event) {
        this.newFormDescription = event.detail.value;
    }

    async handleCreateForm() {
        if (!this.newFormName) {
            this.showError('Form name is required');
            return;
        }
        this.isLoading = true;
        try {
            const form = await saveForm({
                form: {
                    Name: this.newFormName,
                    C_Description__c: this.newFormDescription,
                    C_Status__c: 'Draft',
                    C_Version__c: 1,
                    C_Layout_Mode__c: this.formLayoutMode
                }
            });
            this.showNewFormModal = false;
            this.showSuccess('Form created successfully');
            await this.selectForm(form.Id);
        } catch (error) {
            this.showError('Error creating form', error);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Toolbox Drag (creating new items) ---

    handleToolboxDragStart(event) {
        const dragType = event.currentTarget.dataset.dragtype;
        const questionType = event.currentTarget.dataset.questiontype || '';
        event.dataTransfer.setData('text/plain', JSON.stringify({
            dragType,
            questionType,
            source: 'toolbox'
        }));
        event.dataTransfer.effectAllowed = 'copy';
        this.isDragging = true;
        this.dragType = dragType;
        this.dragItemType = dragType;
        this.dragQuestionType = questionType;
    }

    handleDragEnd() {
        this.isDragging = false;
        this.dragType = '';
        this.dragItemType = '';
        this.dragQuestionType = '';
        this.draggingSourceId = null;
    }

    handleBuilderDragStart(event) {
        const { itemType, itemId } = event.detail;
        this.isDragging = true;
        this.dragType = 'reorder';
        this.dragItemType = itemType;
        this.draggingSourceId = itemId;
    }

    handleBuilderDragEnd() {
        this.handleDragEnd();
    }

    handleDragOver(event) {
        event.preventDefault();
        const accepts = event.currentTarget.dataset.accepts;

        if (!this.isDropCompatible(accepts)) {
            event.dataTransfer.dropEffect = 'none';
            return;
        }

        event.dataTransfer.dropEffect = this.dragType === 'reorder' ? 'move' : 'copy';
        event.currentTarget.classList.add('drag-over');
    }

    handleDragLeave(event) {
        event.currentTarget.classList.remove('drag-over');
    }

    isDropCompatible(accepts) {
        return dragIsDropCompatible(accepts, this.dragItemType);
    }

    async handleBuilderDrop(event) {
        event.stopPropagation();
        const { data, dropzone, parentId, position, accepts } = event.detail;
        await this.applyUnifiedDropDetail({ data, dropzone, parentId, position, accepts });
    }

    // --- Unified Drop Handler ---

    async handleUnifiedDrop(event) {
        event.preventDefault();
        event.stopPropagation();

        const dropzone = event.currentTarget.dataset.dropzone;
        const parentId = event.currentTarget.dataset.parentid;
        const position = parseInt(event.currentTarget.dataset.position || '0', 10);
        const accepts = event.currentTarget.dataset.accepts;

        let data;
        try {
            data = JSON.parse(event.dataTransfer.getData('text/plain'));
        } catch {
            return;
        }

        event.currentTarget.classList.remove('drag-over');
        await this.applyUnifiedDropDetail({ data, dropzone, parentId, position, accepts });
    }

    async applyUnifiedDropDetail({ data, dropzone, parentId, position, accepts }) {
        this.isDragging = false;
        this.dragType = '';
        this.dragItemType = '';
        this.dragQuestionType = '';
        this.draggingSourceId = null;

        if (!data) {
            return;
        }

        if (!this.isDropCompatible(accepts)) {
            return;
        }

        const normParent = parentId === undefined || parentId === null ? '' : parentId;

        if (data.source === 'toolbox') {
            await this.handleToolboxDrop(data, dropzone, normParent, position);
        } else if (data.source === 'canvas') {
            await this.handleReorderOrMoveDrop(data, dropzone, normParent, position);
        }
    }

    async handleToolboxDrop(data, dropzone, parentId, position) {
        const { dragType, questionType } = data;

        if (dragType === 'category' && dropzone === 'canvas') {
            await this.createNewCategory(position);
        } else if (dragType === 'page' && dropzone === 'canvas') {
            await this.createNewPage(null, position);
        } else if (dragType === 'page' && dropzone === 'rootPages') {
            await this.createNewPage(null, position);
        } else if (dragType === 'page' && dropzone === 'category') {
            await this.createNewPage(parentId, position);
        } else if (dragType === 'section' && dropzone === 'page') {
            await this.createNewSection(parentId, position);
        } else if (dragType === 'question' && dropzone === 'section') {
            await this.createNewQuestion(parentId, questionType, position);
        } else if (dragType === 'questionRepository' && dropzone === 'section') {
            this.openRepositoryModal('question', parentId, position);
        } else if (dragType === 'sectionRepository' && dropzone === 'page') {
            this.openRepositoryModal('section', parentId, position);
        } else if (dragType === 'response' && dropzone === 'question') {
            await this.createNewResponse(parentId, position);
        }
    }

    _isReorderDropAllowed(dropzone, itemType) {
        const allowed = {
            canvas: ['category', 'page'],
            rootPages: ['page'],
            category: ['page'],
            page: ['section'],
            section: ['question'],
            question: ['response']
        };
        return (allowed[dropzone] || []).includes(itemType);
    }

    async handleReorderOrMoveDrop(data, dropzone, parentId, position) {
        const { itemType, itemId, parentId: sourceParentId } = data;

        if (!this._isReorderDropAllowed(dropzone, itemType)) return;

        if (itemType === 'page') {
            const normSource = this._normalizePageCategoryId(sourceParentId);
            let normTarget;
            if (dropzone === 'canvas' || dropzone === 'rootPages') {
                normTarget = null;
            } else if (dropzone === 'category') {
                normTarget = this._normalizePageCategoryId(parentId);
            } else {
                return;
            }
            if (normTarget !== normSource) {
                await this.moveItemToNewParent('page', itemId, normTarget, position + 1);
            } else {
                await this.reorderItem('page', itemId, normSource, position);
            }
            return;
        }

        const isCrossContainer = parentId && sourceParentId && parentId !== sourceParentId;

        if (isCrossContainer) {
            await this.moveItemToNewParent(itemType, itemId, parentId, position + 1);
        } else {
            await this.reorderItem(itemType, itemId, parentId, position);
        }
    }

    async moveItemToNewParent(objectType, itemId, newParentId, newPosition) {
        const typeMap = { page: 'Page', section: 'Section', question: 'Question', response: 'Response', category: 'Category' };
        this.isLoading = true;
        try {
            await moveItem({
                objectType: typeMap[objectType],
                itemId,
                newParentId: newParentId != null ? newParentId : null,
                newPosition
            });
            this.showSuccess(`${typeMap[objectType]} moved`);
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error moving item', error);
        } finally {
            this.isLoading = false;
        }
    }

    async reorderItem(objectType, itemId, parentId, newPosition) {
        let items;
        const typeMap = { category: 'Category', page: 'Page', section: 'Section', question: 'Question', response: 'Response' };
        const apexType = typeMap[objectType];

        if (objectType === 'category') {
            items = (this.formStructure.categories || []).map(c => ({ id: c.Id, order: c.C_Order__c }));
        } else if (objectType === 'page') {
            const catPages = this.getPagesForCategoryKey(this._normalizePageCategoryId(parentId));
            items = catPages.map(p => ({ id: p.Id, order: p.C_Order__c }));
        } else if (objectType === 'section') {
            items = (this.formStructure.sectionsByPage?.[parentId] || []).map(s => ({ id: s.Id, order: s.C_Order__c }));
        } else if (objectType === 'question') {
            items = (this.formStructure.questionsBySection?.[parentId] || []).map(q => ({ id: q.Id, order: q.C_Order__c }));
        } else if (objectType === 'response') {
            items = (this.formStructure.responsesByQuestion?.[parentId] || []).map(r => ({ id: r.Id, order: r.C_Order__c }));
        }

        if (!items) return;

        const oldIndex = items.findIndex(i => i.id === itemId);
        const movedItem = items.find(i => i.id === itemId);
        if (!movedItem || oldIndex === -1) return;

        let targetIndex = newPosition;
        if (oldIndex < targetIndex) targetIndex--;

        const filtered = items.filter(i => i.id !== itemId);
        filtered.splice(targetIndex, 0, movedItem);
        const reordered = filtered.map((item, idx) => ({ id: item.id, order: idx + 1 }));

        try {
            await reorderItems({ objectType: apexType, items: reordered });
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error reordering items', error);
        }
    }

    // --- Element creation ---

    async createNewCategory(position) {
        const order = this._computeCategoryInsertOrder(position);
        this.isLoading = true;
        try {
            const category = await saveCategory({
                category: {
                    Name: `Category ${order}`,
                    C_Form__c: this.selectedFormId,
                    C_Order__c: order,
                    C_Is_Active__c: true
                }
            });
            this.showSuccess('Category created');
            await this.refreshFormStructure();
            this.selectElement(category, 'category');
        } catch (error) {
            this.showError('Error creating category', error);
        } finally {
            this.isLoading = false;
        }
    }

    async createNewPage(categoryId, position) {
        const existingCategoryId = categoryId || null;
        this.isLoading = true;
        try {
            let targetCategoryId = existingCategoryId;
            if (!targetCategoryId) {
                const catOrder = this._computeCategoryInsertOrder(position);
                const category = await saveCategory({
                    category: {
                        Name: `Category ${catOrder}`,
                        C_Form__c: this.selectedFormId,
                        C_Order__c: catOrder,
                        C_Is_Active__c: true
                    }
                });
                targetCategoryId = category.Id;
            }
            const catPages = this.getPagesForCategoryKey(targetCategoryId);
            const pageOrder = position !== undefined && position !== null ? position + 1 : catPages.length + 1;
            const page = await savePage({
                page: {
                    Name: `Page ${pageOrder}`,
                    C_Form__c: this.selectedFormId,
                    C_Category__c: targetCategoryId,
                    C_Order__c: pageOrder
                }
            });
            this.showSuccess('Page created');
            await this.refreshFormStructure();
            this.selectElement(page, 'page');
        } catch (error) {
            this.showError('Error creating page', error);
        } finally {
            this.isLoading = false;
        }
    }

    async createNewSection(pageId, position) {
        const sections = this.formStructure?.sectionsByPage?.[pageId] || [];
        const order = position !== undefined ? position + 1 : sections.length + 1;
        this.isLoading = true;
        try {
            const section = await saveSection({
                section: {
                    Name: `Section ${order}`,
                    C_Page__c: pageId,
                    C_Order__c: order
                }
            });
            this.showSuccess('Section created');
            await this.refreshFormStructure();
            this.selectElement(section, 'section');
        } catch (error) {
            this.showError('Error creating section', error);
        } finally {
            this.isLoading = false;
        }
    }

    async createNewQuestion(sectionId, questionType, position) {
        const questions = this.formStructure?.questionsBySection?.[sectionId] || [];
        const order = position !== undefined ? position + 1 : questions.length + 1;
        const type = questionType || 'Text';
        this.isLoading = true;
        try {
            const question = await saveQuestion({
                question: {
                    Name: `${type} Question ${order}`,
                    C_Section__c: sectionId,
                    C_Order__c: order,
                    C_Type__c: type,
                    C_Is_Required__c: false,
                    C_Is_Disabled__c: false
                }
            });
            this.showSuccess(`${type} question created`);
            await this.refreshFormStructure();
            this.selectElement(question, 'question');
        } catch (error) {
            this.showError('Error creating question', error);
        } finally {
            this.isLoading = false;
        }
    }

    async createNewResponse(questionId, position) {
        const responses = this.formStructure?.responsesByQuestion?.[questionId] || [];
        const order = position !== undefined ? position + 1 : responses.length + 1;
        this.isLoading = true;
        try {
            const response = await saveResponse({
                response: {
                    Name: `Response ${order}`,
                    C_Question__c: questionId,
                    C_Order__c: order,
                    C_Points__c: 0
                }
            });
            this.showSuccess('Response created');
            await this.refreshFormStructure();
            this.selectElement(response, 'response');
        } catch (error) {
            this.showError('Error creating response', error);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Element selection ---

    handleElementClick(event) {
        event.stopPropagation();
        const elementType = event.currentTarget.dataset.elementtype;
        const elementId = event.currentTarget.dataset.id;
        const element = this.findElementById(elementType, elementId);
        if (element) {
            this.selectElement(element, elementType);
        }
    }

    handleFormHeaderClick() {
        if (this.formStructure?.form) {
            this.selectElement({ ...this.formStructure.form }, 'form');
        }
    }

    selectElement(element, type) {
        this.selectedElement = JSON.parse(JSON.stringify(element));
        this.selectedElementType = type;
    }

    findElementById(type, id) {
        if (!this.formStructure) return null;
        if (type === 'form') {
            return this.formStructure?.form?.Id === id ? this.formStructure.form : null;
        }
        if (type === 'category') {
            return (this.formStructure.categories || []).find(c => c.Id === id);
        }
        if (type === 'page') {
            return (this.formStructure.pages || []).find(p => p.Id === id);
        }
        if (type === 'section') {
            const secMap = this.formStructure.sectionsByPage || {};
            for (const pageId of Object.keys(secMap)) {
                const found = secMap[pageId].find(s => s.Id === id);
                if (found) return found;
            }
        }
        if (type === 'question') {
            const qMap = this.formStructure.questionsBySection || {};
            for (const secId of Object.keys(qMap)) {
                const found = qMap[secId].find(q => q.Id === id);
                if (found) return found;
            }
        }
        if (type === 'response') {
            const rMap = this.formStructure.responsesByQuestion || {};
            for (const qId of Object.keys(rMap)) {
                const found = rMap[qId].find(r => r.Id === id);
                if (found) return found;
            }
        }
        return null;
    }

    findParentId(type, id) {
        if (!this.formStructure) return null;
        if (type === 'section') {
            const secMap = this.formStructure.sectionsByPage || {};
            for (const pageId of Object.keys(secMap)) {
                if (secMap[pageId].find(s => s.Id === id)) return pageId;
            }
        }
        if (type === 'question') {
            const qMap = this.formStructure.questionsBySection || {};
            for (const secId of Object.keys(qMap)) {
                if (qMap[secId].find(q => q.Id === id)) return secId;
            }
        }
        if (type === 'response') {
            const rMap = this.formStructure.responsesByQuestion || {};
            for (const qId of Object.keys(rMap)) {
                if (rMap[qId].find(r => r.Id === id)) return qId;
            }
        }
        return null;
    }

    // --- Property editing ---

    handlePropertyChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        if (event.target.type === 'number') {
            value = value !== '' ? parseFloat(value) : null;
        }
        this.selectedElement = { ...this.selectedElement, [field]: value };
    }

    handleTableColumnsChange(event) {
        this.selectedElement = { ...this.selectedElement, C_Table_Columns__c: event.detail.value };
    }

    handleCrossFieldRulesChange(event) {
        const rules = event.detail.rules;
        this.selectedElement = {
            ...this.selectedElement,
            C_Cross_Field_Rules_JSON__c: rules && rules.length > 0 ? JSON.stringify(rules) : null
        };
    }

    async handleInlineSaveDependency(event) {
        const dep = event.detail.dependency;
        this.isLoading = true;
        try {
            await saveDependency({ dep });
            this.showSuccess('Dependency created');
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error creating dependency', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleInlineDeleteDependency(event) {
        const depId = event.detail.dependencyId;
        this.isLoading = true;
        try {
            await deleteDependency({ depId });
            this.showSuccess('Dependency deleted');
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error deleting dependency', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handlePropertySave() {
        if (!this.selectedElement || !this.selectedElementType) return;
        this.isLoading = true;
        try {
            const type = this.selectedElementType;
            const el = this.selectedElement;

            if (type === 'form') {
                await saveForm({ form: el });
            } else if (type === 'category') {
                await saveCategory({ category: el });
            } else if (type === 'page') {
                await savePage({ page: el });
            } else if (type === 'section') {
                await saveSection({ section: el });
            } else if (type === 'question') {
                await saveQuestion({ question: el });
            } else if (type === 'response') {
                await saveResponse({ response: el });
            }

            this.showSuccess(`${type.charAt(0).toUpperCase() + type.slice(1)} saved`);
            await this.refreshFormStructure();

            const refreshed = this.findElementById(type, el.Id);
            if (refreshed) {
                this.selectedElement = JSON.parse(JSON.stringify(refreshed));
            }
        } catch (error) {
            this.showError('Error saving element', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteElement() {
        if (!this.selectedElement || !this.selectedElementType) return;
        const type = this.selectedElementType;

        const confirmMsg =
            type === 'category'
                ? 'Deleting this category will also delete all pages (and their sections, questions, and responses) inside it. This cannot be undone. Continue?'
                : `Are you sure you want to delete this ${type}? This action cannot be undone.`;
        const confirmed = await new Promise(resolve => {
            if (window.confirm(confirmMsg)) {
                resolve(true);
            } else {
                resolve(false);
            }
        });
        if (!confirmed) return;

        this.isLoading = true;
        try {
            const id = this.selectedElement.Id;

            if (type === 'form') {
                await deleteForm({ formId: id });
                this.handleBackToList();
                return;
            } else if (type === 'category') {
                await deleteCategory({ categoryId: id });
            } else if (type === 'page') {
                await deletePage({ pageId: id });
            } else if (type === 'section') {
                await deleteSection({ sectionId: id });
            } else if (type === 'question') {
                await deleteQuestion({ questionId: id });
            } else if (type === 'response') {
                await deleteResponse({ responseId: id });
            }

            this.selectedElement = null;
            this.selectedElementType = '';
            this.showSuccess(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted`);
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error deleting element', error);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Preview ---

    togglePreview() {
        this.showPreview = !this.showPreview;
    }

    get previewPages() {
        return this.pages;
    }

    // --- Dependency Builder ---

    toggleDependencyBuilder() {
        this.showDependencyBuilder = !this.showDependencyBuilder;
        if (this.showDependencyBuilder) {
            this.showPreview = false;
            this.showFieldMappingPanel = false;
        }
    }

    // --- Field Mapping Panel ---

    get dependencyButtonVariant() {
        return this.showDependencyBuilder ? 'brand' : 'neutral';
    }

    get fieldMappingButtonVariant() {
        return this.showFieldMappingPanel ? 'brand' : 'neutral';
    }

    toggleFieldMappingPanel() {
        this.showFieldMappingPanel = !this.showFieldMappingPanel;
        if (this.showFieldMappingPanel) {
            this.showPreview = false;
            this.showDependencyBuilder = false;
        }
    }

    handleInlineMappingChanged() {
        this.loadFieldMappings();
    }

    @track newDependency = {
        C_Controlling_Response__c: '',
        C_Target_Type__c: '',
        C_Action__c: 'Show',
        C_Target_Category__c: null,
        C_Target_Page__c: null,
        C_Target_Section__c: null,
        C_Target_Question__c: null
    };

    handleDependencyFieldChange(event) {
        const field = event.target.dataset.field;
        this.newDependency = { ...this.newDependency, [field]: event.detail.value };

        if (field === 'C_Target_Type__c') {
            this.newDependency.C_Target_Category__c = null;
            this.newDependency.C_Target_Page__c = null;
            this.newDependency.C_Target_Section__c = null;
            this.newDependency.C_Target_Question__c = null;
        }
    }

    handleDependencyTargetChange(event) {
        const targetId = event.detail.value;
        const targetType = this.newDependency.C_Target_Type__c;
        if (targetType === 'Category') {
            this.newDependency = { ...this.newDependency, C_Target_Category__c: targetId, C_Target_Page__c: null, C_Target_Section__c: null, C_Target_Question__c: null };
        } else if (targetType === 'Page') {
            this.newDependency = { ...this.newDependency, C_Target_Category__c: null, C_Target_Page__c: targetId, C_Target_Section__c: null, C_Target_Question__c: null };
        } else if (targetType === 'Section') {
            this.newDependency = { ...this.newDependency, C_Target_Category__c: null, C_Target_Page__c: null, C_Target_Section__c: targetId, C_Target_Question__c: null };
        } else if (targetType === 'Question') {
            this.newDependency = { ...this.newDependency, C_Target_Category__c: null, C_Target_Page__c: null, C_Target_Section__c: null, C_Target_Question__c: targetId };
        }
    }

    get isTargetComboboxDisabled() {
        return !this.newDependency || !this.newDependency.C_Target_Type__c;
    }

    get filteredTargetElements() {
        const targetType = this.newDependency.C_Target_Type__c;
        if (!targetType) return [];
        return this.allTargetElements.filter(el => el.type === targetType);
    }

    get selectedTargetValue() {
        const tt = this.newDependency.C_Target_Type__c;
        if (tt === 'Category') return this.newDependency.C_Target_Category__c;
        if (tt === 'Page') return this.newDependency.C_Target_Page__c;
        if (tt === 'Section') return this.newDependency.C_Target_Section__c;
        if (tt === 'Question') return this.newDependency.C_Target_Question__c;
        return '';
    }

    get layoutModeOptions() {
        return [
            { label: 'Classic', value: 'classic' },
            { label: 'Conversational', value: 'conversational' },
            { label: 'Wizard', value: 'wizard' },
            { label: 'Card Based', value: 'cardBased' }
        ];
    }

    async handleSaveDependency() {
        const dep = { ...this.newDependency };
        if (!dep.C_Controlling_Response__c || !dep.C_Target_Type__c || !dep.C_Action__c) {
            this.showError('Please fill all dependency fields');
            return;
        }
        const hasTarget = dep.C_Target_Category__c || dep.C_Target_Page__c || dep.C_Target_Section__c || dep.C_Target_Question__c;
        if (!hasTarget) {
            this.showError('Please select a target element');
            return;
        }

        this.isLoading = true;
        try {
            await saveDependency({ dep });
            this.showSuccess('Dependency created');
            this.newDependency = {
                C_Controlling_Response__c: '',
                C_Target_Type__c: '',
                C_Action__c: 'Show',
                C_Target_Category__c: null,
                C_Target_Page__c: null,
                C_Target_Section__c: null,
                C_Target_Question__c: null
            };
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error creating dependency', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteDependency(event) {
        const depId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await deleteDependency({ depId });
            this.showSuccess('Dependency deleted');
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error deleting dependency', error);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Collapse/Expand ---

    handleToggleCollapse(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.collapsedIds = {
            ...this.collapsedIds,
            [id]: !this.collapsedIds[id]
        };
    }

    // --- Quick add buttons ---

    handleQuickAddCategory() {
        this.createNewCategory();
    }

    handleQuickAddPage(event) {
        const categoryId = event.currentTarget.dataset.categoryid || null;
        this.createNewPage(categoryId);
    }

    handleQuickAddSection(event) {
        const pageId = event.currentTarget.dataset.pageid;
        this.createNewSection(pageId);
    }

    handleQuickAddQuestion(event) {
        const sectionId = event.currentTarget.dataset.sectionid;
        this.createNewQuestion(sectionId, 'Text');
    }

    handleQuickAddResponse(event) {
        const questionId = event.currentTarget.dataset.questionid;
        this.createNewResponse(questionId);
    }

    handleBuilderElementClick(event) {
        const { elementType, elementId } = event.detail;
        const element = this.findElementById(elementType, elementId);
        if (element) {
            this.selectElement(element, elementType);
        }
    }

    handleBuilderToggleCollapse(event) {
        const { id } = event.detail;
        this.collapsedIds = {
            ...this.collapsedIds,
            [id]: !this.collapsedIds[id]
        };
    }

    handleBuilderQuickAddPage(event) {
        const categoryId = event.detail.categoryId || null;
        this.createNewPage(categoryId);
    }

    handleBuilderQuickAddSection(event) {
        this.createNewSection(event.detail.pageId);
    }

    handleBuilderQuickAddQuestion(event) {
        this.createNewQuestion(event.detail.sectionId, 'Text');
    }

    handleBuilderQuickAddResponse(event) {
        this.createNewResponse(event.detail.questionId);
    }

    // --- Config Modal ---

    handleCloseConfigModal() {
        this.showConfigModal = false;
    }

    handleSaveConfig() {
        this.showConfigModal = false;
    }

    handleOpenConfigModal() {
        this.configLayoutMode = this.formStructure?.form?.C_Layout_Mode__c || 'Classic';
        this.showConfigModal = true;
    }

    handleConfigLayoutModeChange(event) {
        this.configLayoutMode = event.detail.value;
    }

    async handleSaveConfig() {
        if (!this.formStructure?.form) return;
    
        this.isLoading = true;
        try {
            await saveForm({
                form: {
                    ...this.formStructure.form,
                    C_Layout_Mode__c: this.configLayoutMode
                }
            });
    
            this.showConfigModal = false;
            this.showSuccess('Configuration saved');
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error saving configuration', error);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Clone Form ---

    handleOpenCloneModal() {
        this.cloneFormName = this.formName + ' (Copy)';
        this.showCloneModal = true;
    }

    handleCloneNameChange(event) {
        this.cloneFormName = event.detail.value;
    }

    handleCancelClone() {
        this.showCloneModal = false;
    }

    async handleConfirmClone() {
        if (!this.cloneFormName) return;
        this.isLoading = true;
        try {
            await cloneForm({ formId: this.selectedFormId, newFormName: this.cloneFormName });
            this.showCloneModal = false;
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Form cloned successfully', variant: 'success' }));
            this.loadForms();
            this.currentView = 'list';
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error?.body?.message || 'Clone failed', variant: 'error' }));
        } finally {
            this.isLoading = false;
        }
    }

    // --- Field Mapping ---

    async loadFieldMappings() {
        try {
            this.fieldMappingTargets = await getFormTargets({ formId: this.selectedFormId });
            this.buildQuestionMappingMap();
        } catch (e) {
            this.fieldMappingTargets = [];
            this.questionMappingMap = {};
        }
    }

    buildQuestionMappingMap() {
        const map = {};
        for (const target of (this.fieldMappingTargets || [])) {
            const mappings = target.C_Field_Mappings__r || [];
            for (const m of mappings) {
                if (m.C_Question__c) {
                    if (!map[m.C_Question__c]) map[m.C_Question__c] = [];
                    map[m.C_Question__c].push({
                        id: m.Id,
                        targetName: target.Name,
                        targetObject: target.C_Target_Object__c,
                        targetField: m.C_Target_Field__c,
                        mappingType: m.C_Mapping_Type__c,
                        staticValue: m.C_Static_Value__c,
                        targetId: target.Id,
                        operation: target.C_Record_Operation__c,
                        direction: target.C_Direction__c || 'Outbound',
                        resolutionType: target.C_Resolution_Type__c,
                        contextKey: target.C_Context_Key__c
                    });
                }
            }
        }
        this.questionMappingMap = map;
    }

    _getQuestionMappingBadge(questionId) {
        const mappings = this.questionMappingMap[questionId];
        if (!mappings || mappings.length === 0) {
            return { isMapped: false, label: '', cssClass: '' };
        }
        const dirs = new Set(mappings.map(m => m.direction));
        if (dirs.has('Bidirectional') || (dirs.has('Inbound') && dirs.has('Outbound'))) {
            return { isMapped: true, label: 'Synced', cssClass: 'type-badge synced-badge' };
        }
        if (dirs.has('Inbound')) {
            return { isMapped: true, label: 'Pre-filled', cssClass: 'type-badge prefilled-badge' };
        }
        return { isMapped: true, label: 'Mapped', cssClass: 'type-badge mapped-badge' };
    }

    handleMappingChanged() {
        this.loadFieldMappings();
    }

    handleNavigateToMapping() {
        if (this.formStructure?.form) {
            this.selectElement({ ...this.formStructure.form }, 'form');
        }
    }

    // --- Asset repository ---

    openRepositoryModal(kind, parentId, position) {
        this.repositoryModalKind = kind;
        this.pendingRepositoryParentId = parentId;
        this.pendingRepositoryPosition = position !== undefined && position !== null ? position : 0;
        this.repositorySearchTerm = '';
        this.repositoryResults = [];
        this.showRepositoryModal = true;
        this.runRepositorySearch();
    }

    closeRepositoryModal() {
        this.showRepositoryModal = false;
        this.repositoryModalKind = '';
        this.repositoryResults = [];
    }

    handleRepositorySearchInput(event) {
        this.repositorySearchTerm = event.target.value;
    }

    handleRepositorySearchKeyup(event) {
        if (event.key === 'Enter') {
            this.handleRepositorySearchClick();
        }
    }

    async handleRepositorySearchClick() {
        await this.runRepositorySearch();
    }

    async runRepositorySearch() {
        this.repositorySearching = true;
        try {
            const term = this.repositorySearchTerm || '';
            if (this.repositoryModalKind === 'question') {
                const rows = await searchLibraryQuestions({ searchTerm: term });
                this.repositoryResults = (rows || []).map(r => ({
                    id: r.Id,
                    title: r.Name,
                    subtitle: `${r.C_Question_Text__c || ''} · ${r.C_Type__c || ''}`.trim()
                }));
            } else {
                const rows = await searchLibrarySections({ searchTerm: term });
                this.repositoryResults = (rows || []).map(r => ({
                    id: r.Id,
                    title: r.Name,
                    subtitle: 'Library section'
                }));
            }
        } catch (error) {
            this.showError('Search failed', error);
            this.repositoryResults = [];
        } finally {
            this.repositorySearching = false;
        }
    }

    async handlePickRepositoryItem(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) {
            return;
        }
        this.isLoading = true;
        try {
            if (this.repositoryModalKind === 'question') {
                const newId = await injectLibraryQuestion({
                    libraryQuestionId: id,
                    targetSectionId: this.pendingRepositoryParentId,
                    positionZeroBased: this.pendingRepositoryPosition
                });
                this.showSuccess('Question added from repository');
                await this.refreshFormStructure();
                const el = this.findElementById('question', newId);
                if (el) {
                    this.selectElement(el, 'question');
                }
            } else {
                const newId = await injectLibrarySection({
                    librarySectionId: id,
                    targetPageId: this.pendingRepositoryParentId,
                    positionZeroBased: this.pendingRepositoryPosition
                });
                this.showSuccess('Section added from repository');
                await this.refreshFormStructure();
                const el = this.findElementById('section', newId);
                if (el) {
                    this.selectElement(el, 'section');
                }
            }
            this.closeRepositoryModal();
        } catch (error) {
            this.showError('Could not insert from repository', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenPromoteSection() {
        this.promoteConfirmKind = 'section';
        this.showPromoteConfirm = true;
    }

    handleOpenPromoteQuestion() {
        this.promoteConfirmKind = 'question';
        this.showPromoteConfirm = true;
    }

    handleCancelPromoteConfirm() {
        this.showPromoteConfirm = false;
    }

    async handleConfirmPromote() {
        this.isLoading = true;
        try {
            if (this.promoteConfirmKind === 'question') {
                await promoteQuestionToLibrary({ formQuestionId: this.selectedElement.Id });
                this.showSuccess('Question copied to public repository');
            } else {
                await promoteSectionToLibrary({ formSectionId: this.selectedElement.Id });
                this.showSuccess('Section copied to public repository');
            }
            this.showPromoteConfirm = false;
        } catch (error) {
            this.showError('Publish to repository failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Property Sections ---

    handleTogglePropertySection(event) {
        const section = event.currentTarget.dataset.section;
        this.expandedSections = {
            ...this.expandedSections,
            [section]: !this.expandedSections[section]
        };
    }

    // --- Dependency Update ---

    async handleInlineUpdateDependency(event) {
        const dep = event.detail.dependency;
        this.isLoading = true;
        try {
            await saveDependency({ dep });
            this.showSuccess('Dependency updated');
            await this.refreshFormStructure();
        } catch (error) {
            this.showError('Error updating dependency', error);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Utilities ---

    handleTargetBuilderToast(event) {
        const { title, message, variant } = event.detail;
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    showError(message, error) {
        const detail = error?.body?.message || error?.message || message;
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: detail, variant: 'error' }));
    }

    errorCallback(error, stack) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Component Error',
            message: error?.message || 'An unexpected error occurred',
            variant: 'error'
        }));
        console.error('FormBuilderVisual error:', error, 'Stack:', stack);
    }
}
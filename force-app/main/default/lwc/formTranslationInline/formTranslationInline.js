import { LightningElement, api, track } from 'lwc';
import getAvailableLanguages from '@salesforce/apex/TranslationService.getAvailableLanguages';
import getAllElementTranslations from '@salesforce/apex/TranslationService.getAllElementTranslations';
import saveTranslation from '@salesforce/apex/TranslationService.saveTranslation';
import deleteTranslation from '@salesforce/apex/TranslationService.deleteTranslation';

const FIELDS_BY_TYPE = {
    category: [{ field: 'Name', label: 'Name' }],
    page: [
        { field: 'Name', label: 'Name' },
        { field: 'C_Description__c', label: 'Description' }
    ],
    section: [{ field: 'Name', label: 'Name' }],
    question: [
        { field: 'C_Question_Text__c', label: 'Question Text' },
        { field: 'C_Help_Text__c', label: 'Help Text' },
        { field: 'C_Placeholder__c', label: 'Placeholder' }
    ],
    response: [{ field: 'C_Response_Text__c', label: 'Response Text' }]
};

const FIELD_LABELS = {
    'Name': 'Name',
    'C_Description__c': 'Description',
    'C_Question_Text__c': 'Question Text',
    'C_Help_Text__c': 'Help Text',
    'C_Placeholder__c': 'Placeholder',
    'C_Response_Text__c': 'Response Text'
};

export default class FormTranslationInline extends LightningElement {
    _elementId;
    _elementType;
    @api defaultLanguage = '';

    @api
    get elementId() { return this._elementId; }
    set elementId(value) {
        const changed = this._elementId !== value;
        this._elementId = value;
        if (changed) this._resetAndReload();
    }

    @api
    get elementType() { return this._elementType; }
    set elementType(value) {
        const changed = this._elementType !== value;
        this._elementType = value;
        if (changed) this._resetAndReload();
    }

    @track translations = [];
    @track languageOptions = [];
    @track showAddForm = false;
    @track editingId = null;
    @track newTranslation = {};
    @track isSaving = false;
    @track isLoadingTranslations = false;

    _languagesLoaded = false;
    _connected = false;

    get translatableFields() {
        return FIELDS_BY_TYPE[this._elementType] || [];
    }

    get addButtonIcon() {
        return this.showAddForm ? 'utility:dash' : 'utility:add';
    }

    get saveButtonLabel() {
        return this.editingId ? 'Update' : 'Save';
    }

    get hasTranslations() {
        return this.translations && this.translations.length > 0;
    }

    get enrichedTranslations() {
        const grouped = {};
        for (const t of this.translations) {
            const key = `${t.language}_${t.fieldName}`;
            grouped[key] = t;
        }

        const pills = [];
        for (const key of Object.keys(grouped)) {
            const t = grouped[key];
            const fieldLabel = FIELD_LABELS[t.fieldName] || t.fieldName;
            const text = t.translatedText || '';
            const preview = text.length > 40 ? text.substring(0, 40) + '...' : text;
            pills.push({
                ...t,
                pillKey: key,
                displayLabel: `${t.language} · ${fieldLabel}`,
                preview
            });
        }
        return pills;
    }

    get availableLanguageOptions() {
        const defLang = (this.defaultLanguage || '').toLowerCase();
        return this.languageOptions
            .filter(l => l.toLowerCase() !== defLang)
            .map(l => ({ label: l, value: l }));
    }

    get hasLanguageOptions() {
        return this.availableLanguageOptions.length > 0;
    }

    get formFields() {
        return this.translatableFields.map(f => ({
            ...f,
            value: this.newTranslation[f.field] || ''
        }));
    }

    connectedCallback() {
        this._connected = true;
        this._loadLanguages();
        this._loadExistingTranslations();
    }

    _resetAndReload() {
        this.translations = [];
        this.showAddForm = false;
        this.editingId = null;
        this.newTranslation = {};
        if (this._connected) {
            this._loadExistingTranslations();
        }
    }

    async _loadLanguages() {
        if (this._languagesLoaded) return;
        try {
            const langs = await getAvailableLanguages({ formId: null });
            this.languageOptions = langs || [];
            this._languagesLoaded = true;
        } catch (e) {
            this.languageOptions = [];
        }
    }

    async _loadExistingTranslations() {
        if (!this._elementId || !this._elementType) return;
        const targetId = this._elementId;
        const targetType = this._elementType;
        this.isLoadingTranslations = true;
        try {
            const result = await getAllElementTranslations({
                elementType: targetType,
                elementId: targetId
            });
            if (this._elementId !== targetId || this._elementType !== targetType) return;
            this.translations = result || [];
        } catch (e) {
            if (this._elementId !== targetId || this._elementType !== targetType) return;
            this.translations = [];
        } finally {
            if (this._elementId === targetId && this._elementType === targetType) {
                this.isLoadingTranslations = false;
            }
        }
    }

    handleToggleAdd() {
        this.showAddForm = !this.showAddForm;
        if (!this.showAddForm) {
            this.editingId = null;
            this.newTranslation = {};
        }
    }

    handleEditPill(event) {
        const id = event.currentTarget.dataset.id;
        const match = this.translations.find(t => t.id === id);
        if (!match) return;

        this.newTranslation = {
            language: match.language,
            ...this._buildFieldValues(match.language)
        };
        this.editingId = id;
        this.showAddForm = true;
    }

    _buildFieldValues(language) {
        const values = {};
        const langTranslations = this.translations.filter(t => t.language === language);
        for (const t of langTranslations) {
            values[t.fieldName] = t.translatedText;
        }
        return values;
    }

    handleLanguageChange(event) {
        const lang = event.detail.value;
        this.newTranslation = {
            ...this.newTranslation,
            language: lang,
            ...this._buildFieldValues(lang)
        };
        const existing = this.translations.find(t => t.language === lang);
        this.editingId = existing ? existing.id : null;
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.newTranslation = { ...this.newTranslation, [field]: event.detail.value };
    }

    async handleSave() {
        const lang = this.newTranslation.language;
        if (!lang) return;

        this.isSaving = true;
        try {
            for (const f of this.translatableFields) {
                const value = this.newTranslation[f.field];
                if (value === undefined || value === null) continue;
                const hasExisting = this.translations.some(
                    t => t.language === lang && t.fieldName === f.field
                );
                if (!hasExisting && typeof value === 'string' && value.trim() === '') continue;
                await saveTranslation({
                    language: lang,
                    translatedText: value,
                    fieldName: f.field,
                    categoryId: this._elementType === 'category' ? this._elementId : null,
                    pageId: this._elementType === 'page' ? this._elementId : null,
                    sectionId: this._elementType === 'section' ? this._elementId : null,
                    questionId: this._elementType === 'question' ? this._elementId : null,
                    responseId: this._elementType === 'response' ? this._elementId : null
                });
            }
            await this._loadExistingTranslations();
            this.showAddForm = false;
            this.editingId = null;
            this.newTranslation = {};
        } catch (e) {
            console.error('Translation save failed:', e);
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.showAddForm = false;
        this.editingId = null;
        this.newTranslation = {};
    }

    async handleDelete(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        try {
            await deleteTranslation({ translationId: id });
            await this._loadExistingTranslations();
        } catch (e) {
            console.error('Translation delete failed:', e);
        }
    }
}

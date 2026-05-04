import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchLibrarySections from '@salesforce/apex/LibraryAssetService.searchLibrarySections';
import searchLibraryQuestions from '@salesforce/apex/LibraryAssetService.searchLibraryQuestions';

export default class FormBuilderAssetRepo extends LightningElement {
    /** list | edit */
    @track view = 'list';
    /** sections | questions */
    @track assetTab = 'sections';

    @track searchTerm = '';
    @track sections = [];
    @track questions = [];
    @track loading = false;

    @track editFocusType = '';
    @track editFocusId = '';
    @track editFocusName = '';

    get isListView() {
        return this.view === 'list';
    }
    get isEditView() {
        return this.view === 'edit';
    }

    get editTitle() {
        const base =
            this.editFocusType === 'question' ? 'Edit library question' : 'Edit library section';
        const n = (this.editFocusName || '').trim();
        if (!n) {
            return base;
        }
        return `${base} — ${n}`;
    }

    get isSectionsTab() {
        return this.assetTab === 'sections';
    }
    get isQuestionsTab() {
        return this.assetTab === 'questions';
    }

    get sectionsTabClass() {
        return this.assetTab === 'sections' ? 'asset-tab-btn is-active' : 'asset-tab-btn';
    }
    get questionsTabClass() {
        return this.assetTab === 'questions' ? 'asset-tab-btn is-active' : 'asset-tab-btn';
    }

    connectedCallback() {
        this.runSearch();
    }

    handleTabButtonClick(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab === 'sections' || tab === 'questions') {
            this.assetTab = tab;
            this.runSearch();
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.detail.value || '';
    }

    handleSearchSubmit() {
        this.runSearch();
    }

    async runSearch() {
        this.loading = true;
        const term = this.searchTerm || '';
        try {
            if (this.assetTab === 'sections') {
                this.sections = await searchLibrarySections({ searchTerm: term });
            } else {
                this.questions = await searchLibraryQuestions({ searchTerm: term });
            }
        } catch (e) {
            this.sections = [];
            this.questions = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Search failed',
                    message: e?.body?.message || e?.message || 'Unknown error',
                    variant: 'error'
                })
            );
        } finally {
            this.loading = false;
        }
    }

    handleEditSection(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name || '';
        this.openEditor('section', id, name);
    }

    handleEditQuestion(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name || '';
        this.openEditor('question', id, name);
    }

    openEditor(type, id, name) {
        this.editFocusType = type;
        this.editFocusId = id;
        this.editFocusName = name || '';
        this.view = 'edit';
    }

    handleBackToList() {
        this.view = 'list';
        this.editFocusType = '';
        this.editFocusId = '';
        this.editFocusName = '';
    }
}

import { LightningElement, api, track } from 'lwc';

export default class FormRendererLayoutConversational extends LightningElement {
    @api currentPage;
    @api currentPageName;
    @api currentSections = [];
    @api readOnly = false;
    /** When true, blocks finishing the conversational flow (matches FormRenderer preview). */
    @api previewMode = false;
    @api featureSettings;

    activeIndex = 0;
    lastPageId;

    @track validationInlineError = '';

    get isEffectiveReadOnly() {
        return this.readOnly === true || this.readOnly === 'true';
    }

    get isPreviewModeEffective() {
        return this.previewMode === true || this.previewMode === 'true';
    }

    /** Prevent submit/finish while read-only or preview (footer submit is hidden there; conversational OK button must match). */
    get isPrimaryActionDisabled() {
        return this.isLastQuestion && (this.isEffectiveReadOnly || this.isPreviewModeEffective);
    }

    renderedCallback() {
        const pageId = this.currentPage?.pageId;

        if (pageId && pageId !== this.lastPageId) {
            this.lastPageId = pageId;
            this.activeIndex = 0;
            this.validationInlineError = '';
        }

        if (this.activeIndex >= this.totalQuestions && this.totalQuestions > 0) {
            this.activeIndex = this.totalQuestions - 1;
        }
    }

    get flatQuestions() {
        const questions = [];

        for (const section of this.currentSections || []) {
            for (const question of section.visibleQuestions || []) {
                questions.push({
                    ...question,
                    sectionId: section.sectionId,
                    sectionName: section.translatedName || section.sectionName || ''
                });
            }
        }

        return questions;
    }

    get hasQuestions() {
        return this.flatQuestions.length > 0 && this.activeQuestion !== null;
    }

    get activeQuestion() {
        return this.flatQuestions[this.activeIndex] || null;
    }

    get activeSectionName() {
        return this.activeQuestion?.sectionName || '';
    }

    get activeNumber() {
        if (!this.totalQuestions) return 0;
        return this.activeIndex + 1;
    }

    get totalQuestions() {
        return this.flatQuestions.length;
    }

    get questionCounter() {
        return `${this.activeNumber} of ${this.totalQuestions}`;
    }

    get progressWidth() {
        if (!this.totalQuestions) return 'width: 0%';
        return `width: ${Math.round((this.activeNumber / this.totalQuestions) * 100)}%`;
    }

    get isFirstQuestion() {
        return this.activeIndex === 0;
    }

    get isLastQuestion() {
        return this.activeIndex >= this.totalQuestions - 1;
    }

    get nextLabel() {
        return this.isLastQuestion ? 'Submit' : 'OK';
    }

    validateActiveQuestion() {
        this.validationInlineError = '';

        if (this.isEffectiveReadOnly || this.isPreviewModeEffective) {
            return true;
        }

        const fq = this.template.querySelector('c-form-question');
        if (!fq || typeof fq.checkInputValidity !== 'function') {
            return true;
        }

        if (!fq.checkInputValidity()) {
            this.validationInlineError = 'Please correct this answer before continuing.';
            return false;
        }

        return true;
    }

    handleNext() {
        if (this.isLastQuestion && (this.isEffectiveReadOnly || this.isPreviewModeEffective)) {
            return;
        }

        if (!this.validateActiveQuestion()) {
            return;
        }

        if (this.isLastQuestion) {
            this.dispatchEvent(
                new CustomEvent('finish', {
                    bubbles: true,
                    composed: true
                })
            );
            return;
        }

        this.activeIndex += 1;
    }

    handlePrevious() {
        this.validationInlineError = '';
        if (!this.isFirstQuestion) {
            this.activeIndex -= 1;
        }
    }

    handleValueChange(event) {
        this.validationInlineError = '';
        const detail = event.detail || {};

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail,
                bubbles: true,
                composed: true
            })
        );
    }
}

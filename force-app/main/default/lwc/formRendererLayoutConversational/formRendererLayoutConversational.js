import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { tableQuestionHasAnswer } from 'c/formTableQuestionUtil';

export default class FormRendererLayoutConversational extends LightningElement {
    @api currentPage;
    @api currentPageName;
    @api currentSections = [];
    @api readOnly = false;
    @api featureSettings;

    activeIndex = 0;
    lastPageId;
    answerState = {};

    renderedCallback() {
        const pageId = this.currentPage?.pageId;

        if (pageId && pageId !== this.lastPageId) {
            this.lastPageId = pageId;
            this.activeIndex = 0;
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

    get isActiveQuestionRequired() {
        return this.activeQuestion?.isRequired === true;
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    hasAnswer(question) {
        if (!question) return false;

        const liveAnswer = this.answerState[question.questionId];

        const value = liveAnswer?.value ?? question.value;
        const textValue = liveAnswer?.textValue ?? question.textValue;

        if (question.questionType === 'Table') {
            return tableQuestionHasAnswer(textValue);
        }

        return this.hasRealValue(value) || this.hasRealValue(textValue);
    }

    hasRealValue(value) {
        if (value === null || value === undefined) return false;

        if (Array.isArray(value)) {
            return value.length > 0;
        }

        const text = String(value).trim();

        return text !== '' && text !== '[]' && text !== '{}';
    }

    validateActiveQuestion() {
        if (!this.isActiveQuestionRequired) {
            return true;
        }

        if (this.hasAnswer(this.activeQuestion)) {
            return true;
        }

        this.showToast(
            'Required question',
            'Please answer this question before continuing.',
            'error'
        );

        return false;
    }

    handleNext() {
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
        if (!this.isFirstQuestion) {
            this.activeIndex -= 1;
        }
    }

    handleValueChange(event) {
        const detail = event.detail || {};

        this.answerState = {
            ...this.answerState,
            [detail.questionId]: {
                value: detail.value,
                textValue: detail.textValue
            }
        };

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail,
                bubbles: true,
                composed: true
            })
        );
    }
}
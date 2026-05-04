import { LightningElement, api } from 'lwc';

export default class FormRendererLayoutWizard extends LightningElement {
    @api formStructure = [];
    @api hiddenElements = {};
    @api currentPage;
    @api currentPageName;
    @api currentPageDescription;
    @api currentSections = [];
    @api progressSteps = [];
    @api currentStep = 0;
    @api readOnly = false;
    @api featureSettings;

    activeQuestionId;
    answerState = {};
    pendingScrollQuestionId;

    get currentQuestions() {
        const questions = [];

        for (const section of this.currentSections || []) {
            for (const question of section.visibleQuestions || []) {
                questions.push(question);
            }
        }

        return questions;
    }

    get answeredQuestionCount() {
        return this.currentQuestions.filter(q => this.isAnswered(q)).length;
    }

    get totalQuestionCount() {
        return this.currentQuestions.length;
    }

    get questionProgressText() {
        return `${this.answeredQuestionCount} of ${this.totalQuestionCount} answered`;
    }

    get questionProgressWidth() {
        if (!this.totalQuestionCount) {
            return 'width: 0%';
        }

        return `width: ${Math.round((this.answeredQuestionCount / this.totalQuestionCount) * 100)}%`;
    }

    get sidebarPages() {
        return (this.progressSteps || []).map((step, index) => {
            const page = (this.formStructure || []).find(p => p.pageId === step.pageId);
            const questions = [];

            for (const section of page?.sections || []) {
                if (this.hiddenElements?.[section.sectionId]) {
                    continue;
                }

                for (const question of section.questions || []) {
                    if (this.hiddenElements?.[question.questionId]) {
                        continue;
                    }

                    const liveQuestion = this.getLiveQuestion(question.questionId);
                    const questionForStatus = liveQuestion || question;

                    questions.push({
                        questionId: question.questionId,
                        questionText: question.questionText || question.questionName,
                        itemClass:
                            question.questionId === this.activeQuestionId
                                ? 'question-nav-item question-nav-active'
                                : 'question-nav-item',
                        isAnswered: this.isAnswered(questionForStatus)
                    });
                }
            }

            return {
                ...step,
                index,
                questions
            };
        });
    }

    getLiveQuestion(questionId) {
        return this.currentQuestions.find(q => q.questionId === questionId);
    }

    isAnswered(question) {
        if (!question) return false;

        const liveAnswer = this.answerState[question.questionId];

        if (liveAnswer) {
            return this.hasRealValue(liveAnswer.value) || this.hasRealValue(liveAnswer.textValue);
        }

        return this.hasRealValue(question.value) || this.hasRealValue(question.textValue);
    }

    hasRealValue(value) {
        if (value === null || value === undefined) return false;

        const text = String(value).trim();

        if (text === '' || text === '[]' || text === '{}') {
            return false;
        }

        try {
            const parsed = JSON.parse(text);

            if (Array.isArray(parsed)) {
                return parsed.some(row => {
                    if (!row || typeof row !== 'object') return false;

                    return Object.values(row).some(cell => {
                        const cellText = String(cell ?? '').trim();

                        return (
                            cellText !== '' &&
                            cellText !== '1' &&
                            cellText !== '2'
                        );
                    });
                });
            }

            if (typeof parsed === 'object') {
                return Object.values(parsed).some(v => String(v ?? '').trim() !== '');
            }
        } catch (e) {
            return text !== '';
        }

        return text !== '';
    }

    handleValueChange(event) {
        const detail = event.detail || {};
        this.activeQuestionId = detail.questionId;

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

    handleQuestionFocus(event) {
        this.activeQuestionId = event.currentTarget.dataset.bodyQuestionId;
    }

    handleStepClick(event) {
        this.dispatchEvent(
            new CustomEvent('stepchange', {
                detail: {
                    index: event.currentTarget.dataset.index
                },
                bubbles: true,
                composed: true
            })
        );
    }

    renderedCallback() {
        if (this.pendingScrollQuestionId) {
            const questionId = this.pendingScrollQuestionId;
            this.pendingScrollQuestionId = null;

            requestAnimationFrame(() => {
                this.scrollToQuestion(questionId);
            });
        }
    }

    handleQuestionNavClick(event) {
        const questionId = event.currentTarget.dataset.questionId;
        const pageIndex = Number(event.currentTarget.dataset.pageIndex);

        this.activeQuestionId = questionId;
        this.pendingScrollQuestionId = questionId;

        if (pageIndex !== this.currentStep) {
            this.dispatchEvent(
                new CustomEvent('stepchange', {
                    detail: {
                        index: pageIndex
                    },
                    bubbles: true,
                    composed: true
                })
            );
            return;
        }

        this.scrollToQuestion(questionId);
    }

    scrollToQuestion(questionId) {
        const questionEl = this.template.querySelector(
            `[data-body-question-id="${questionId}"]`
        );

        if (!questionEl) return;

        this.template.querySelectorAll('.question-highlight').forEach(el => {
            el.classList.remove('question-highlight');
        });

        questionEl.scrollIntoView({
            behavior: 'smooth',
            block: 'center'
        });

        questionEl.classList.add('question-highlight');

        window.setTimeout(() => {
            questionEl.classList.remove('question-highlight');
        }, 2100);
    }
}
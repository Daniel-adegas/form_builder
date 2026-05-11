import { LightningElement, api } from 'lwc';
import { tableQuestionHasAnswer } from 'c/formTableQuestionUtil';

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
    scrollHighlightTimeoutId;

    /** Avoids JSON.parse on every getter run for unchanged question values (e.g. each keystroke). */
    _hasRealValueCache = new Map();
    _hasRealValueCacheMax = 512;

    _sidebarPagesCache;
    _sidebarPagesDepsKey;
    _sidebarBaselineFormRef;
    _sidebarBaselineProgressRef;
    _sidebarBaselineHiddenRef;
    /** Serialized baseline question values; recomputed only when structure @api refs change. */
    _sidebarValueBaseline = '';

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
        const key = this._getSidebarPagesDepsKey();
        if (key === this._sidebarPagesDepsKey && this._sidebarPagesCache) {
            return this._sidebarPagesCache;
        }
        this._sidebarPagesDepsKey = key;
        this._sidebarPagesCache = this._buildSidebarPages();
        return this._sidebarPagesCache;
    }

    _syncSidebarValueBaselineIfStale() {
        const struct = this.formStructure || [];
        const steps = this.progressSteps || [];
        const hidden = this.hiddenElements || {};
        if (
            struct === this._sidebarBaselineFormRef &&
            steps === this._sidebarBaselineProgressRef &&
            hidden === this._sidebarBaselineHiddenRef
        ) {
            return;
        }
        this._sidebarBaselineFormRef = struct;
        this._sidebarBaselineProgressRef = steps;
        this._sidebarBaselineHiddenRef = hidden;

        const stepPart = steps.map(s => s.pageId).join('\u001e');
        const hiddenPart = Object.keys(hidden)
            .sort()
            .map(k => `${k}:${hidden[k]}`)
            .join('\u001e');
        const baselinePart = struct
            .map(p =>
                (p.sections || [])
                    .map(sec =>
                        (sec.questions || [])
                            .map(
                                q =>
                                    `${q.questionId}\u001f${q.questionType}\u001f${q.value}\u001f${q.textValue}`
                            )
                            .join('\u001e')
                    )
                    .join('\u001d')
            )
            .join('\u001c');
        this._sidebarValueBaseline = [stepPart, hiddenPart, struct.length, baselinePart].join('\u0000');
    }

    _getSidebarPagesDepsKey() {
        this._syncSidebarValueBaselineIfStale();
        const answers = this.answerState || {};
        const answerPart = Object.keys(answers)
            .sort()
            .map(k => {
                const a = answers[k];
                return `${k}\u001f${a?.value}\u001f${a?.textValue}`;
            })
            .join('\u001e');
        return [this._sidebarValueBaseline, answerPart, this.activeQuestionId].join('\u0000');
    }

    _buildSidebarPages() {
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

        if (question.questionType === 'Table') {
            const textValue = liveAnswer?.textValue ?? question.textValue;
            return tableQuestionHasAnswer(textValue);
        }

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

        const first = text[0];
        if (first !== '[' && first !== '{') {
            return text !== '';
        }

        if (this._hasRealValueCache.has(text)) {
            return this._hasRealValueCache.get(text);
        }

        let result;
        try {
            const parsed = JSON.parse(text);

            if (Array.isArray(parsed)) {
                result = parsed.some(row => {
                    if (!row || typeof row !== 'object') return false;

                    return Object.values(row).some(cell => {
                        const cellText = String(cell ?? '').trim();

                        return cellText !== '';
                    });
                });
            } else if (typeof parsed === 'object' && parsed !== null) {
                result = Object.values(parsed).some(v => String(v ?? '').trim() !== '');
            } else {
                result = text !== '';
            }
        } catch (e) {
            result = text !== '';
        }

        this._memoizeHasRealValue(text, result);
        return result;
    }

    _memoizeHasRealValue(text, result) {
        if (this._hasRealValueCache.size >= this._hasRealValueCacheMax) {
            const oldestKey = this._hasRealValueCache.keys().next().value;
            this._hasRealValueCache.delete(oldestKey);
        }
        this._hasRealValueCache.set(text, result);
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

    disconnectedCallback() {
        if (this.scrollHighlightTimeoutId != null) {
            clearTimeout(this.scrollHighlightTimeoutId);
            this.scrollHighlightTimeoutId = null;
        }
        this._hasRealValueCache.clear();
        this._sidebarPagesCache = undefined;
        this._sidebarPagesDepsKey = undefined;
        this._sidebarBaselineFormRef = undefined;
        this._sidebarBaselineProgressRef = undefined;
        this._sidebarBaselineHiddenRef = undefined;
        this._sidebarValueBaseline = '';
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

        if (this.scrollHighlightTimeoutId != null) {
            clearTimeout(this.scrollHighlightTimeoutId);
        }

        this.scrollHighlightTimeoutId = window.setTimeout(() => {
            this.scrollHighlightTimeoutId = null;
            questionEl.classList.remove('question-highlight');
        }, 2100);
    }
}
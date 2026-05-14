import { LightningElement, api } from "lwc";
import { tableQuestionHasAnswer } from "c/formTableQuestionUtil";

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

  _answeredMemo;
  _hasRealValueCache;

  /** Cached sidebar shape; invalidated when progressSteps/formStructure/hiddenElements refs change. */
  _sidebarStaticDeps = null;
  _sidebarStaticPages = null;

  _ensureMemoCaches() {
    if (!this._answeredMemo) {
      this._answeredMemo = new Map();
    }
    if (!this._hasRealValueCache) {
      this._hasRealValueCache = new Map();
    }
  }

  get currentQuestions() {
    const questions = [];

    for (const section of this.currentSections || []) {
      for (const question of section.visibleQuestions || []) {
        questions.push(question);
      }
    }

    return questions;
  }

  _syncSidebarStructure() {
    const progressSteps = this.progressSteps;
    const formStructure = this.formStructure;
    const hiddenElements = this.hiddenElements;

    if (
      this._sidebarStaticDeps &&
      this._sidebarStaticDeps.progressSteps === progressSteps &&
      this._sidebarStaticDeps.formStructure === formStructure &&
      this._sidebarStaticDeps.hiddenElements === hiddenElements &&
      this._sidebarStaticPages
    ) {
      return;
    }

    const pages = [];

    for (let index = 0; index < (progressSteps || []).length; index++) {
      const step = progressSteps[index];
      const page = (formStructure || []).find((p) => p.pageId === step.pageId);
      const questionRefs = [];

      for (const section of page?.sections || []) {
        if (hiddenElements?.[section.sectionId]) {
          continue;
        }

        for (const question of section.questions || []) {
          if (hiddenElements?.[question.questionId]) {
            continue;
          }

          questionRefs.push({
            questionId: question.questionId,
            questionText: question.questionText || question.questionName,
            baseQuestion: question
          });
        }
      }

      pages.push({ step, index, questionRefs });
    }

    this._sidebarStaticPages = pages;
    this._sidebarStaticDeps = {
      progressSteps,
      formStructure,
      hiddenElements
    };
  }

  get answeredQuestionCount() {
    return this.currentQuestions.filter((q) => this.isAnswered(q)).length;
  }

  get totalQuestionCount() {
    return this.currentQuestions.length;
  }

  get questionProgressText() {
    return `${this.answeredQuestionCount} of ${this.totalQuestionCount} answered`;
  }

  get questionProgressWidth() {
    if (!this.totalQuestionCount) {
      return "width: 0%";
    }

    return `width: ${Math.round((this.answeredQuestionCount / this.totalQuestionCount) * 100)}%`;
  }

  get sidebarPages() {
    this._syncSidebarStructure();

    const liveByQuestionId = new Map();
    for (const question of this.currentQuestions) {
      liveByQuestionId.set(question.questionId, question);
    }

    const activeId = this.activeQuestionId;

    return this._sidebarStaticPages.map(
      ({ step, index: stepIndex, questionRefs }) => ({
        ...step,
        index: stepIndex,
        questions: questionRefs.map((ref) => {
          const questionForStatus =
            liveByQuestionId.get(ref.questionId) || ref.baseQuestion;

          return {
            questionId: ref.questionId,
            questionText: ref.questionText,
            itemClass:
              ref.questionId === activeId
                ? "question-nav-item question-nav-active"
                : "question-nav-item",
            isAnswered: this.isAnswered(questionForStatus)
          };
        })
      })
    );
  }

  isAnswered(question) {
    if (!question) return false;

    return this.memoizedIsAnswered(question);
  }

  memoizedIsAnswered(question) {
    if (!question?.questionId) return false;

    const liveAnswer = this.answerState[question.questionId];
    const cacheKey =
      `${question.questionId}\u0000` +
      `${JSON.stringify(liveAnswer?.value)}\u0000` +
      `${JSON.stringify(liveAnswer?.textValue)}\u0000` +
      `${JSON.stringify(question.value)}\u0000` +
      `${JSON.stringify(question.textValue)}\u0000` +
      `${question.questionType || ""}`;
    this._ensureMemoCaches();
    if (this._answeredMemo.has(cacheKey)) {
      return this._answeredMemo.get(cacheKey);
    }

    const result = this.computeIsAnswered(question, liveAnswer);

    if (this._answeredMemo.size > 500) {
      this._answeredMemo.clear();
    }

    this._answeredMemo.set(cacheKey, result);
    return result;
  }

  computeIsAnswered(
    question,
    liveAnswer = this.answerState[question.questionId]
  ) {
    if (question.questionType === "Table") {
      const textValue = liveAnswer?.textValue ?? question.textValue;
      return tableQuestionHasAnswer(textValue);
    }

    if (liveAnswer) {
      return (
        this.hasRealValue(liveAnswer.value) ||
        this.hasRealValue(liveAnswer.textValue)
      );
    }

    return (
      this.hasRealValue(question.value) || this.hasRealValue(question.textValue)
    );
  }

  hasRealValue(value) {
    if (value === null || value === undefined) return false;

    const text = String(value).trim();

    if (text === "" || text === "[]" || text === "{}") {
      return false;
    }

    const first = text[0];
    if (first !== "[" && first !== "{") {
      return text !== "";
    }

    this._ensureMemoCaches();
    if (this._hasRealValueCache.has(text)) {
      return this._hasRealValueCache.get(text);
    }

    let result;
    try {
      const parsed = JSON.parse(text);

      if (Array.isArray(parsed)) {
        result = parsed.some((row) => {
          if (!row || typeof row !== "object") return false;

          return Object.values(row).some((cell) => {
            const cellText = String(cell ?? "").trim();

            return cellText !== "";
          });
        });
      } else if (parsed !== null && typeof parsed === "object") {
        result = Object.values(parsed).some(
          (v) => String(v ?? "").trim() !== ""
        );
      } else {
        result = text !== "";
      }
    } catch {
      result = text !== "";
    }

    if (result === undefined) {
      result = text !== "";
    }

    if (this._hasRealValueCache.size > 500) {
      this._hasRealValueCache.clear();
    }

    this._hasRealValueCache.set(text, result);
    return result;
  }

  handleValueChange(event) {
    // Child event bubbles/composes to this host; re-dispatch once for parents.
    event.stopPropagation();

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
      new CustomEvent("valuechange", {
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
      new CustomEvent("stepchange", {
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

      // eslint-disable-next-line @lwc/lwc/no-async-operation
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
        new CustomEvent("stepchange", {
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
  }

  scrollToQuestion(questionId) {
    const questionEl = this.template.querySelector(
      `[data-body-question-id="${questionId}"]`
    );

    if (!questionEl) return;

    this.template.querySelectorAll(".question-highlight").forEach((el) => {
      el.classList.remove("question-highlight");
    });

    questionEl.scrollIntoView({
      behavior: "smooth",
      block: "center"
    });

    questionEl.classList.add("question-highlight");

    if (this.scrollHighlightTimeoutId != null) {
      clearTimeout(this.scrollHighlightTimeoutId);
    }

    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.scrollHighlightTimeoutId = window.setTimeout(() => {
      this.scrollHighlightTimeoutId = null;
      questionEl.classList.remove("question-highlight");
    }, 2100);
  }
}

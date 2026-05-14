import { LightningElement, api } from "lwc";
import { tableQuestionHasAnswer } from "c/formTableQuestionUtil";

export default class FormRendererLayoutConversational extends LightningElement {
  @api currentPage;
  @api currentPageName;
  @api currentPageDescription;
  @api currentSections = [];
  @api readOnly = false;
  /** When true, conversational flow must not emit finish (e.g. builder preview). */
  @api previewMode = false;
  @api featureSettings;

  activeIndex = 0;
  lastPageId;
  answerState = {};
  inlineValidationMessage = "";

  renderedCallback() {
    const pageId = this.currentPage?.pageId;

    if (pageId && pageId !== this.lastPageId) {
      this.lastPageId = pageId;
      this.activeIndex = 0;
      this.inlineValidationMessage = "";
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
          sectionName: section.translatedName || section.sectionName || ""
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

  get hasConversationHeader() {
    return !!(this.currentPageName || this.currentPageDescription);
  }

  get activeSectionName() {
    return this.activeQuestion?.sectionName || "";
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
    if (!this.totalQuestions) return "width: 0%";
    return `width: ${Math.round((this.activeNumber / this.totalQuestions) * 100)}%`;
  }

  get isFirstQuestion() {
    return this.activeIndex === 0;
  }

  get isLastQuestion() {
    return this.activeIndex >= this.totalQuestions - 1;
  }

  get nextLabel() {
    return this.isLastQuestion ? "Submit" : "OK";
  }

  /** Same normalization as formRenderer.isReadOnly (parent passes merged read-only; no _forceReadOnly here). */
  get isReadOnly() {
    return this.readOnly === true || this.readOnly === "true";
  }

  get isLastStepSubmitDisabled() {
    if (!this.isLastQuestion) return false;
    if (this.isReadOnly) return true;
    if (this.previewMode === true || this.previewMode === "true") return true;
    return false;
  }

  get isActiveQuestionRequired() {
    return this.activeQuestion?.isRequired === true;
  }

  get hasInlineValidationError() {
    return Boolean(this.inlineValidationMessage);
  }

  hasAnswer(question) {
    if (!question) return false;

    const liveAnswer = this.answerState[question.questionId];

    const value = liveAnswer?.value ?? question.value;
    const textValue = liveAnswer?.textValue ?? question.textValue;

    if (question.questionType === "Table") {
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

    return text !== "" && text !== "[]" && text !== "{}";
  }

  validateActiveQuestion() {
    const q = this.activeQuestion;
    if (!q) {
      this.inlineValidationMessage = "";
      return true;
    }

    const questionEl = this.template.querySelector("c-form-question");
    // Delegate regex, native constraints, word limits, and cross-field errors to formQuestion.
    if (
      questionEl &&
      typeof questionEl.reportInputValidity === "function" &&
      !questionEl.reportInputValidity()
    ) {
      this.inlineValidationMessage = "";
      return false;
    }

    if (this.isActiveQuestionRequired && !this.hasAnswer(q)) {
      this.inlineValidationMessage =
        "Please answer this question before continuing.";
      return false;
    }

    this.inlineValidationMessage = "";
    return true;
  }

  handleNext() {
    if (!this.validateActiveQuestion()) {
      return;
    }

    if (this.isLastQuestion) {
      // Mirror formRenderer.handleFinish — never emit finish in read-only or preview.
      if (this.isReadOnly) {
        return;
      }
      if (this.previewMode === true || this.previewMode === "true") {
        return;
      }

      this.dispatchEvent(
        new CustomEvent("finish", {
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
      this.inlineValidationMessage = "";
      this.activeIndex -= 1;
    }
  }

  handleValueChange(event) {
    // Original child event bubbles/composes to this host; we re-dispatch once for parents.
    event.stopPropagation();

    const detail = event.detail || {};

    this.inlineValidationMessage = "";

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
}

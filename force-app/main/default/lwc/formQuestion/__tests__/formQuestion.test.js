import { createElement } from "@lwc/engine-dom";
import FormQuestion from "c/formQuestion";

function buildQuestion(overrides = {}) {
  return {
    questionId: "q-1",
    questionType: "Text",
    questionText: "What is your name?",
    isRequired: false,
    isDisabled: false,
    value: "",
    textValue: "",
    ...overrides
  };
}

function appendFormQuestion(props = {}) {
  const element = createElement("c-form-question", { is: FormQuestion });
  Object.assign(element, {
    question: buildQuestion(),
    sectionId: "sec-1",
    ...props
  });
  document.body.appendChild(element);
  return element;
}

describe("c-form-question", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  describe("reportInputValidity", () => {
    it("returns true immediately when readOnly is true (disabled short-circuit)", () => {
      const element = appendFormQuestion({ readOnly: true });
      expect(element.reportInputValidity()).toBe(true);
    });

    it("returns true immediately when question.isDisabled is true", () => {
      const element = appendFormQuestion({
        question: buildQuestion({ isDisabled: true })
      });
      expect(element.reportInputValidity()).toBe(true);
    });

    it("returns false when crossFieldError is present", () => {
      const element = appendFormQuestion({
        question: buildQuestion({
          crossFieldError: "Value conflicts with another field"
        })
      });
      expect(element.reportInputValidity()).toBe(false);
    });
  });

  describe("required asterisk", () => {
    it("renders the required asterisk when isRequired is true", () => {
      const element = appendFormQuestion({
        question: buildQuestion({ isRequired: true })
      });
      expect(element.shadowRoot.querySelector(".slds-required")).not.toBeNull();
    });

    it("omits the required asterisk when isRequired is false", () => {
      const element = appendFormQuestion();
      expect(element.shadowRoot.querySelector(".slds-required")).toBeNull();
    });

    it("omits the required asterisk when isRequired is true but the question is disabled", () => {
      const element = appendFormQuestion({
        question: buildQuestion({ isRequired: true, isDisabled: true })
      });
      expect(element.shadowRoot.querySelector(".slds-required")).toBeNull();
    });
  });

  describe("word counter", () => {
    it("renders the word counter row for Long Text when maxWordCount > 0", () => {
      const element = appendFormQuestion({
        question: buildQuestion({
          questionType: "Long Text",
          maxWordCount: 100,
          textValue: ""
        })
      });
      expect(
        element.shadowRoot.querySelector(".word-counter-row")
      ).not.toBeNull();
    });

    it("hides the word counter row for Long Text when maxWordCount is 0", () => {
      const element = appendFormQuestion({
        question: buildQuestion({
          questionType: "Long Text",
          maxWordCount: 0,
          textValue: ""
        })
      });
      expect(element.shadowRoot.querySelector(".word-counter-row")).toBeNull();
    });

    it("hides the word counter for Short Text regardless of maxWordCount", () => {
      const element = appendFormQuestion({
        question: buildQuestion({
          questionType: "Text",
          maxWordCount: 100,
          textValue: ""
        })
      });
      expect(element.shadowRoot.querySelector(".word-counter-row")).toBeNull();
    });
  });

  it("dispatches valuechange with sectionId, questionId, and textValue when the text input changes", () => {
    const element = appendFormQuestion({
      sectionId: "sec-42",
      question: buildQuestion()
    });

    const handler = jest.fn();
    element.addEventListener("valuechange", handler);

    const input = element.shadowRoot.querySelector("lightning-input");
    expect(input).not.toBeNull();
    input.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "hello" },
        bubbles: true,
        composed: true
      })
    );

    expect(handler).toHaveBeenCalledTimes(1);
    const evt = handler.mock.calls[0][0];
    expect(evt.bubbles).toBe(true);
    expect(evt.composed).toBe(true);
    expect(evt.detail).toMatchObject({
      sectionId: "sec-42",
      questionId: "q-1",
      value: null,
      textValue: "hello"
    });
  });
});

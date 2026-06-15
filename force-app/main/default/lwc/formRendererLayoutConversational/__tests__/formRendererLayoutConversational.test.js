import { createElement } from "@lwc/engine-dom";
import FormRendererLayoutConversational from "c/formRendererLayoutConversational";

function buildSampleSections() {
  return [
    {
      sectionId: "sec-1",
      translatedName: "Profile",
      visibleQuestions: [
        {
          questionId: "q-text-1",
          questionType: "Text",
          isRequired: false,
          value: "",
          textValue: ""
        }
      ]
    }
  ];
}

function appendConversationalLayout(props = {}) {
  const element = createElement("c-form-renderer-layout-conversational", {
    is: FormRendererLayoutConversational
  });
  Object.assign(element, {
    currentPage: { pageId: "page-1" },
    currentSections: buildSampleSections(),
    ...props
  });
  document.body.appendChild(element);
  return element;
}

describe("c-form-renderer-layout-conversational", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("shows empty state when there are no visible questions", () => {
    const element = appendConversationalLayout({ currentSections: [] });
    const empty = element.shadowRoot.querySelector(".empty-state");
    expect(empty).not.toBeNull();
    expect(empty.textContent.trim()).toBe(
      "No questions available on this page."
    );
  });

  it("renders page description in conversation header when provided", () => {
    const element = appendConversationalLayout({
      currentPageName: "About you",
      currentPageDescription: "Tell us a bit about yourself."
    });

    const description = element.shadowRoot.querySelector(
      ".conversation-header .description"
    );
    expect(description).not.toBeNull();
    expect(description.textContent.trim()).toBe(
      "Tell us a bit about yourself."
    );
  });

  it("dispatches nextpage (not finish) on last question when another page remains", () => {
    const element = appendConversationalLayout({ isLastPage: false });
    const formQuestion = element.shadowRoot.querySelector("c-form-question");
    formQuestion.reportInputValidity = jest.fn().mockReturnValue(true);

    const nextListener = jest.fn();
    const finishListener = jest.fn();
    element.addEventListener("nextpage", nextListener);
    element.addEventListener("finish", finishListener);

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons[1].label).toBe("Next");
    buttons[1].click();

    expect(nextListener).toHaveBeenCalledTimes(1);
    expect(nextListener.mock.calls[0][0].detail).toEqual({ activeIndex: 0 });
    expect(finishListener).not.toHaveBeenCalled();
  });

  it("shows Next label on last question of page when not isLastPage", () => {
    const element = appendConversationalLayout({ isLastPage: false });
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons[1].label).toBe("Next");
  });

  it("dispatches finish from last question when isLastPage", () => {
    const element = appendConversationalLayout({
      isLastPage: true,
      readOnly: false,
      previewMode: false
    });
    const formQuestion = element.shadowRoot.querySelector("c-form-question");
    formQuestion.reportInputValidity = jest.fn().mockReturnValue(true);

    const finishListener = jest.fn();
    element.addEventListener("finish", finishListener);

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons[1].label).toBe("Submit");
    buttons[1].click();

    expect(finishListener).toHaveBeenCalledTimes(1);
  });

  it("dispatches previouspage from first question when not isFirstPage", () => {
    const element = appendConversationalLayout({
      isFirstPage: false,
      currentSections: buildSampleSections()
    });

    const prevListener = jest.fn();
    element.addEventListener("previouspage", prevListener);

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons[0].disabled).toBe(false);
    buttons[0].click();

    expect(prevListener).toHaveBeenCalledTimes(1);
    expect(prevListener.mock.calls[0][0].detail).toEqual({ activeIndex: 0 });
  });

  it("keeps Previous disabled on first question when isFirstPage", () => {
    const element = appendConversationalLayout({ isFirstPage: true });
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons[0].disabled).toBe(true);
  });

  it("renders progress shell, active question host, and navigation buttons", () => {
    const element = appendConversationalLayout();

    expect(
      element.shadowRoot.querySelector(".conversation-shell")
    ).not.toBeNull();

    const progress = element.shadowRoot.querySelector('[role="progressbar"]');
    expect(progress).not.toBeNull();
    expect(progress.getAttribute("aria-valuenow")).toBe("1");

    const counter = element.shadowRoot.querySelector(".counter");
    expect(counter.textContent.trim()).toBe("1 of 1");

    const formQuestion = element.shadowRoot.querySelector("c-form-question");
    expect(formQuestion).not.toBeNull();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons).toHaveLength(2);
    expect(buttons[0].label).toBe("Previous");
    expect(buttons[1].label).toBe("Submit");
  });

  it("re-dispatches valuechange from c-form-question with bubbles and composed, preserving detail", () => {
    const element = appendConversationalLayout();
    const formQuestion = element.shadowRoot.querySelector("c-form-question");
    expect(formQuestion).not.toBeNull();

    const hostListener = jest.fn();
    element.addEventListener("valuechange", hostListener);

    const detail = {
      questionId: "q-text-1",
      value: "Updated answer",
      textValue: "Updated answer"
    };

    formQuestion.dispatchEvent(
      new CustomEvent("valuechange", {
        detail,
        bubbles: true,
        composed: true
      })
    );

    expect(hostListener).toHaveBeenCalledTimes(1);
    const evt = hostListener.mock.calls[0][0];
    expect(evt.bubbles).toBe(true);
    expect(evt.composed).toBe(true);
    expect(evt.detail).toEqual(detail);
  });

  it("disables submit on last step when readOnly (handleFinish parity)", () => {
    const element = appendConversationalLayout({ readOnly: true });
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons[1].disabled).toBe(true);
  });

  it("disables submit on last step when previewMode (handleFinish parity)", () => {
    const element = appendConversationalLayout({ previewMode: true });
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons[1].disabled).toBe(true);
  });
});

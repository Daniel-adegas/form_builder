import { createElement } from "@lwc/engine-dom";
import FormRendererLayoutCardBased from "c/formRendererLayoutCardBased";

function buildSampleSections(options = {}) {
  const { withQuestions = true, bonus = false } = options;
  return [
    {
      sectionId: "sec-1",
      translatedName: "Profile",
      bonus,
      visibleQuestions: withQuestions
        ? [
            {
              questionId: "q-text-1",
              questionType: "Text",
              isRequired: false,
              value: "",
              textValue: "",
              questionLayoutClass: "slds-col slds-size_1-of-1 question-row"
            }
          ]
        : []
    }
  ];
}

function appendCardBasedLayout(props = {}) {
  const element = createElement("c-form-renderer-layout-card-based", {
    is: FormRendererLayoutCardBased
  });
  Object.assign(element, {
    currentPage: { pageId: "page-1" },
    currentPageName: "Page One",
    currentPageDescription: "Description for page one.",
    currentSections: buildSampleSections(),
    ...props
  });
  document.body.appendChild(element);
  return element;
}

describe("c-form-renderer-layout-card-based", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders card layout shell, page header, description, question cards, and form questions", () => {
    const element = appendCardBasedLayout();

    expect(element.shadowRoot.querySelector(".card-layout")).not.toBeNull();

    const title = element.shadowRoot.querySelector(".page-header h2");
    expect(title).not.toBeNull();
    expect(title.textContent.trim()).toBe("Page One");

    const description = element.shadowRoot.querySelector(".page-description");
    expect(description).not.toBeNull();
    expect(description.textContent.trim()).toBe("Description for page one.");

    expect(
      element.shadowRoot.querySelector(".question-card-grid")
    ).not.toBeNull();
    expect(element.shadowRoot.querySelector(".question-card")).not.toBeNull();

    const sectionLabel = element.shadowRoot.querySelector(".section-label");
    expect(sectionLabel.textContent.trim()).toBe("Profile");

    const formQuestions =
      element.shadowRoot.querySelectorAll("c-form-question");
    expect(formQuestions).toHaveLength(1);
  });

  it("shows empty state when there are no visible questions", () => {
    const element = appendCardBasedLayout({
      currentSections: buildSampleSections({ withQuestions: false })
    });
    const empty = element.shadowRoot.querySelector(".empty-state");
    expect(empty).not.toBeNull();
    expect(empty.textContent.trim()).toBe("No questions on this page.");
  });

  it("shows bonus badge when section has bonus flag", () => {
    const element = appendCardBasedLayout({
      currentSections: buildSampleSections({ bonus: true })
    });
    const badge = element.shadowRoot.querySelector(".bonus-badge");
    expect(badge).not.toBeNull();
    expect(badge.textContent.trim()).toBe("Bonus");
  });

  it("re-dispatches valuechange from c-form-question with bubbles and composed, preserving detail", () => {
    const element = appendCardBasedLayout();
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
});

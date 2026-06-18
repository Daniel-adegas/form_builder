import { createElement } from "@lwc/engine-dom";
import FormRendererLayoutClassic from "c/formRendererLayoutClassic";

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
        : [],
      hasVisibleQuestions: withQuestions
    }
  ];
}

function appendClassicLayout(props = {}) {
  const element = createElement("c-form-renderer-layout-classic", {
    is: FormRendererLayoutClassic
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

describe("c-form-renderer-layout-classic", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders page shell, title, description, section card, and form questions", () => {
    const element = appendClassicLayout();

    expect(element.shadowRoot.querySelector(".page-content")).not.toBeNull();

    const title = element.shadowRoot.querySelector(".page-title");
    expect(title).not.toBeNull();
    expect(title.textContent.trim()).toBe("Page One");

    const description = element.shadowRoot.querySelector(".page-description");
    expect(description).not.toBeNull();
    expect(description.textContent.trim()).toBe("Description for page one.");

    expect(element.shadowRoot.querySelector(".section-card")).not.toBeNull();
    const sectionName = element.shadowRoot.querySelector(".section-name");
    expect(sectionName.textContent.trim()).toBe("Profile");

    const formQuestions =
      element.shadowRoot.querySelectorAll("c-form-question");
    expect(formQuestions).toHaveLength(1);
  });

  it("shows empty section message when a section has no visible questions", () => {
    const element = appendClassicLayout({
      currentSections: buildSampleSections({ withQuestions: false })
    });
    const emptyMsg = element.shadowRoot.querySelector(".empty-section-msg");
    expect(emptyMsg).not.toBeNull();
    expect(emptyMsg.textContent.trim()).toBe("No questions in this section.");
  });

  it("shows bonus badge when section has bonus flag", () => {
    const element = appendClassicLayout({
      currentSections: buildSampleSections({ bonus: true })
    });
    const badge = element.shadowRoot.querySelector(".bonus-badge");
    expect(badge).not.toBeNull();
    expect(badge.textContent.trim()).toBe("Bonus");
  });

  it("re-dispatches valuechange from c-form-question with bubbles and composed, preserving detail", () => {
    const element = appendClassicLayout();
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

import { createElement } from "@lwc/engine-dom";
import FormRendererLayoutWizard from "c/formRendererLayoutWizard";

function buildSampleSections(options = {}) {
  const { withQuestions = true, bonus = false, questionsOverride } = options;
  const defaultQuestions = [
    {
      questionId: "q-text-1",
      questionType: "Text",
      isRequired: false,
      value: "",
      textValue: "",
      questionLayoutClass: "slds-col slds-size_1-of-1 question-row"
    }
  ];
  return [
    {
      sectionId: "sec-1",
      translatedName: "Profile",
      bonus,
      visibleQuestions: withQuestions
        ? questionsOverride || defaultQuestions
        : [],
      hasVisibleQuestions: withQuestions
    }
  ];
}

function buildFormStructure() {
  return [
    {
      pageId: "page-1",
      pageName: "Page One",
      sections: [
        {
          sectionId: "sec-1",
          sectionName: "Profile",
          questions: [
            {
              questionId: "q-text-1",
              questionType: "Text",
              questionText: "Sample question",
              questionName: "Sample question"
            }
          ]
        }
      ]
    }
  ];
}

function buildProgressSteps() {
  return [
    {
      pageId: "page-1",
      stepIndex: 1,
      translatedPageName: "Page One",
      stepClass: "step-pill step-active"
    }
  ];
}

function appendWizardLayout(props = {}) {
  const element = createElement("c-form-renderer-layout-wizard", {
    is: FormRendererLayoutWizard
  });
  Object.assign(element, {
    formStructure: buildFormStructure(),
    hiddenElements: {},
    currentPage: { pageId: "page-1" },
    currentPageName: "Page One",
    currentPageDescription: "Description for the active step.",
    currentSections: buildSampleSections(),
    progressSteps: buildProgressSteps(),
    currentStep: 0,
    ...props
  });
  document.body.appendChild(element);
  return element;
}

describe("c-form-renderer-layout-wizard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders shell, sidebar progress, step control, section card, and form questions", () => {
    const element = appendWizardLayout();

    expect(element.shadowRoot.querySelector(".wizard-layout")).not.toBeNull();
    expect(element.shadowRoot.querySelector(".wizard-sidebar")).not.toBeNull();

    const progressLabel = element.shadowRoot.querySelector(
      ".question-progress-label"
    );
    expect(progressLabel).not.toBeNull();
    expect(progressLabel.textContent.trim()).toBe("Current page progress");

    expect(
      element.shadowRoot.querySelector(".question-progress-bar")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelector(".question-progress-text")
    ).not.toBeNull();

    const pagesLabel = element.shadowRoot.querySelector(".wizard-label");
    expect(pagesLabel).not.toBeNull();
    expect(pagesLabel.textContent.trim()).toBe("Pages");

    const stepButton = element.shadowRoot.querySelector(
      ".sidebar-page-block .step-text"
    );
    expect(stepButton).not.toBeNull();
    expect(stepButton.textContent.trim()).toBe("Page One");

    const description = element.shadowRoot.querySelector(".page-description");
    expect(description).not.toBeNull();
    expect(description.textContent.trim()).toBe(
      "Description for the active step."
    );

    expect(element.shadowRoot.querySelector(".section-card")).not.toBeNull();
    const sectionName = element.shadowRoot.querySelector(".section-name");
    expect(sectionName.textContent.trim()).toBe("Profile");

    const formQuestions =
      element.shadowRoot.querySelectorAll("c-form-question");
    expect(formQuestions).toHaveLength(1);

    const navItem = element.shadowRoot.querySelector(
      ".question-nav-item .question-nav-text"
    );
    expect(navItem).not.toBeNull();
    expect(navItem.textContent.trim()).toBe("Sample question");
  });

  it("shows (Disabled) in sidebar when question has isDisabled true", () => {
    const formStructure = buildFormStructure();
    formStructure[0].sections[0].questions[0].isDisabled = true;

    const element = appendWizardLayout({
      currentSections: buildSampleSections({
        questionsOverride: [
          {
            questionId: "q-text-1",
            questionType: "Text",
            isRequired: false,
            isDisabled: true,
            value: "",
            textValue: "",
            questionLayoutClass: "slds-col slds-size_1-of-1 question-row"
          }
        ]
      }),
      formStructure
    });

    const disabledLabel = element.shadowRoot.querySelector(
      ".disabled-sidebar-text"
    );
    expect(disabledLabel).not.toBeNull();
    expect(disabledLabel.textContent.trim()).toBe("(Disabled)");
  });

  it("shows empty section message when a section has no visible questions", () => {
    const element = appendWizardLayout({
      currentSections: buildSampleSections({ withQuestions: false })
    });
    const emptyMsg = element.shadowRoot.querySelector(".empty-section-msg");
    expect(emptyMsg).not.toBeNull();
    expect(emptyMsg.textContent.trim()).toBe("No questions in this section.");
  });

  it("shows bonus badge when section has bonus flag", () => {
    const element = appendWizardLayout({
      currentSections: buildSampleSections({ bonus: true })
    });
    const badge = element.shadowRoot.querySelector(".bonus-badge");
    expect(badge).not.toBeNull();
    expect(badge.textContent.trim()).toBe("Bonus");
  });

  it("re-dispatches valuechange from c-form-question with bubbles and composed, preserving detail", () => {
    const element = appendWizardLayout();
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

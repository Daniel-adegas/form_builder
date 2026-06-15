import { createElement } from "@lwc/engine-dom";
import FormRenderer from "c/formRenderer";

jest.mock(
  "@salesforce/apex/FeatureSettingsService.getFeatureSettings",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormService.getFormStructureWithMeta",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormSubmissionService.getOrCreateSubmission",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FieldMappingService.getPrePopulationData",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormSubmissionService.submitForm",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.getForms",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TranslationService.getAvailableLanguages",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/TranslationService.getTranslations",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormSubmissionService.saveDraftState",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormSubmissionService.getSubmissionWithResponses",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

import getFeatureSettings from "@salesforce/apex/FeatureSettingsService.getFeatureSettings";
import getFormStructureWithMeta from "@salesforce/apex/FormService.getFormStructureWithMeta";
import getOrCreateSubmission from "@salesforce/apex/FormSubmissionService.getOrCreateSubmission";
import getPrePopulationData from "@salesforce/apex/FieldMappingService.getPrePopulationData";
import submitFormApex from "@salesforce/apex/FormSubmissionService.submitForm";

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const FEATURE_SETTINGS = {
  scoring: true,
  fieldMapping: true,
  translations: false,
  characterCountdown: false
};

function buildFormResult(
  layoutMode = "classic",
  pages = null,
  dependencies = null
) {
  return {
    formName: "Test Form",
    formId: "001XX000000001",
    defaultLanguage: "en",
    layoutMode,
    description: "A test form",
    pages: pages ?? [{ pageId: "page-1", pageName: "Page 1", sections: [] }],
    categories: [],
    dependencies: dependencies ?? []
  };
}

function buildPage(pageId, sections = []) {
  return { pageId, pageName: `Page ${pageId}`, sections };
}

function appendFormRenderer(props = {}) {
  const element = createElement("c-form-renderer", { is: FormRenderer });
  Object.assign(element, { formId: "001XX000000001", ...props });
  document.body.appendChild(element);
  return element;
}

describe("c-form-renderer", () => {
  beforeEach(() => {
    getFeatureSettings.mockResolvedValue(FEATURE_SETTINGS);
    getOrCreateSubmission.mockResolvedValue({
      submissionId: "sub-1",
      isResume: false,
      draftJson: null
    });
    getPrePopulationData.mockResolvedValue({});
    submitFormApex.mockResolvedValue({});
  });

  afterEach(() => {
    jest.clearAllMocks();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  // ── Layout routing ──────────────────────────────────────────────────────

  it("renders the classic layout when layoutMode is classic", () => {
    getFormStructureWithMeta.mockResolvedValue(buildFormResult("classic"));
    const element = appendFormRenderer();

    return flushPromises().then(() => {
      expect(
        element.shadowRoot.querySelector("c-form-renderer-layout-classic")
      ).not.toBeNull();
    });
  });

  it("renders the conversational layout when layoutMode is conversational", () => {
    getFormStructureWithMeta.mockResolvedValue(
      buildFormResult("conversational")
    );
    const element = appendFormRenderer();

    return flushPromises().then(() => {
      expect(
        element.shadowRoot.querySelector(
          "c-form-renderer-layout-conversational"
        )
      ).not.toBeNull();
    });
  });

  it("renders the wizard layout when layoutMode is wizard", () => {
    getFormStructureWithMeta.mockResolvedValue(buildFormResult("wizard"));
    const element = appendFormRenderer();

    return flushPromises().then(() => {
      expect(
        element.shadowRoot.querySelector("c-form-renderer-layout-wizard")
      ).not.toBeNull();
    });
  });

  it("renders the card-based layout when layoutMode is cardbased", () => {
    getFormStructureWithMeta.mockResolvedValue(buildFormResult("cardbased"));
    const element = appendFormRenderer();

    return flushPromises().then(() => {
      expect(
        element.shadowRoot.querySelector("c-form-renderer-layout-card-based")
      ).not.toBeNull();
    });
  });

  // ── previewMode gating ──────────────────────────────────────────────────

  it("does not call submitForm when previewMode is true", () => {
    getFormStructureWithMeta.mockResolvedValue(buildFormResult("classic"));
    const element = appendFormRenderer({ previewMode: true });

    return flushPromises()
      .then(() => {
        const submitBtn = element.shadowRoot.querySelector(
          ".nav-footer lightning-button"
        );
        expect(submitBtn).not.toBeNull();
        submitBtn.dispatchEvent(
          new CustomEvent("click", { bubbles: true, composed: false })
        );
        return flushPromises();
      })
      .then(() => {
        expect(submitFormApex).not.toHaveBeenCalled();
      });
  });

  // ── Conversational navigation handlers ─────────────────────────────────

  it("handleConversationalNextPage advances to the next page", () => {
    const pages = [buildPage("page-1"), buildPage("page-2")];
    getFormStructureWithMeta.mockResolvedValue(
      buildFormResult("conversational", pages)
    );
    const element = appendFormRenderer();

    return flushPromises()
      .then(() => {
        const layout = element.shadowRoot.querySelector(
          "c-form-renderer-layout-conversational"
        );
        expect(layout).not.toBeNull();
        expect(layout.currentPage.pageId).toBe("page-1");

        layout.dispatchEvent(
          new CustomEvent("nextpage", { bubbles: false, composed: false })
        );
        return flushPromises();
      })
      .then(() => {
        const layout = element.shadowRoot.querySelector(
          "c-form-renderer-layout-conversational"
        );
        expect(layout.currentPage.pageId).toBe("page-2");
      });
  });

  it("handleConversationalPreviousPage does nothing on the first page", () => {
    const pages = [buildPage("page-1"), buildPage("page-2")];
    getFormStructureWithMeta.mockResolvedValue(
      buildFormResult("conversational", pages)
    );
    const element = appendFormRenderer();

    return flushPromises()
      .then(() => {
        const layout = element.shadowRoot.querySelector(
          "c-form-renderer-layout-conversational"
        );
        expect(layout.currentPage.pageId).toBe("page-1");

        layout.dispatchEvent(
          new CustomEvent("previouspage", { bubbles: false, composed: false })
        );
        return flushPromises();
      })
      .then(() => {
        const layout = element.shadowRoot.querySelector(
          "c-form-renderer-layout-conversational"
        );
        expect(layout.currentPage.pageId).toBe("page-1");
      });
  });

  // ── Table-answer-gated validation ───────────────────────────────────────

  it("blocks submit when a required Table question has no answer", () => {
    const tableQuestion = {
      questionId: "q-table-1",
      questionType: "Table",
      questionText: "Fill the table",
      isRequired: true,
      textValue: null,
      tableColumns: "Col A"
    };
    const pages = [
      buildPage("page-1", [
        {
          sectionId: "sec-1",
          sectionName: "Section 1",
          questions: [tableQuestion]
        }
      ])
    ];
    getFormStructureWithMeta.mockResolvedValue(
      buildFormResult("classic", pages)
    );
    const element = appendFormRenderer();

    return flushPromises()
      .then(() => {
        const submitBtn = element.shadowRoot.querySelector(
          ".nav-footer lightning-button"
        );
        expect(submitBtn).not.toBeNull();
        submitBtn.dispatchEvent(
          new CustomEvent("click", { bubbles: true, composed: false })
        );
        return flushPromises();
      })
      .then(() => {
        expect(submitFormApex).not.toHaveBeenCalled();
      });
  });

  // ── Form-level dependencies ─────────────────────────────────────────────

  it("applies form-level dependencies when page wrappers have empty dependency lists", () => {
    const pages = [
      buildPage("page-1", [
        {
          sectionId: "sec-1",
          sectionName: "Section 1",
          questions: [
            {
              questionId: "q-1",
              questionName: "Q1",
              questionText: "Trigger question",
              questionType: "Picklist",
              responses: [{ responseId: "resp-ctrl", responseText: "Yes" }]
            }
          ]
        }
      ]),
      buildPage("page-2", [])
    ];
    getFormStructureWithMeta.mockResolvedValue(
      buildFormResult("classic", pages, [
        {
          controllingResponse: "resp-ctrl",
          targetPage: "page-2",
          action: "Hide"
        }
      ])
    );
    const element = appendFormRenderer();

    return flushPromises()
      .then(() => {
        expect(
          element.shadowRoot.querySelectorAll(".steps-container [role=button]")
            .length
        ).toBe(2);
        const layout = element.shadowRoot.querySelector(
          "c-form-renderer-layout-classic"
        );
        layout.dispatchEvent(
          new CustomEvent("valuechange", {
            detail: { questionId: "q-1", value: "resp-ctrl" },
            bubbles: true
          })
        );
        return flushPromises();
      })
      .then(() => {
        expect(
          element.shadowRoot.querySelectorAll(".steps-container [role=button]")
            .length
        ).toBe(1);
      });
  });
});

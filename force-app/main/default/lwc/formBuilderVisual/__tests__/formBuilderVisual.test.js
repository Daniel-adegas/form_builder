import { createElement } from "@lwc/engine-dom";
import FormBuilderVisual from "c/formBuilderVisual";

jest.mock(
  "@salesforce/apex/FeatureSettingsService.getFeatureSettings",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.getForms",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.saveForm",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.deleteForm",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.saveCategory",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.deleteCategory",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.savePage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.deletePage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.saveSection",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.deleteSection",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.saveQuestion",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.deleteQuestion",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.saveResponse",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.deleteResponse",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.saveDependency",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.deleteDependency",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.reorderItems",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.moveItem",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.getFullFormStructure",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FormBuilderService.cloneForm",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FieldMappingService.getFormTargets",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAssetService.searchLibraryQuestions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAssetService.searchLibrarySections",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAssetService.injectLibraryQuestion",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAssetService.injectLibrarySection",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAssetService.promoteQuestionToLibrary",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAssetService.promoteSectionToLibrary",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LibraryAssetService.getAssetLibraryFormId",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

import getFeatureSettings from "@salesforce/apex/FeatureSettingsService.getFeatureSettings";
import getForms from "@salesforce/apex/FormBuilderService.getForms";

const FEATURE_SETTINGS = {
  scoring: false,
  fieldMapping: false,
  translations: false,
  repository: false,
  options: false,
  styling: false,
  layoutModes: false
};

function appendFormBuilderVisual(props = {}) {
  const element = createElement("c-form-builder-visual", {
    is: FormBuilderVisual
  });
  Object.assign(element, props);
  document.body.appendChild(element);
  return element;
}

describe("c-form-builder-visual", () => {
  beforeEach(() => {
    getFeatureSettings.mockResolvedValue(FEATURE_SETTINGS);
    getForms.mockResolvedValue([]);
  });

  afterEach(() => {
    jest.clearAllMocks();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  // ── Initial list view ───────────────────────────────────────────────────

  it("renders the list view (lightning-card) on initial mount", () => {
    const element = appendFormBuilderVisual();

    expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
  });

  it("renders the New Form button with correct label in the list view", () => {
    const element = appendFormBuilderVisual();

    const addBtn = element.shadowRoot.querySelector('[slot="actions"]');
    expect(addBtn).not.toBeNull();
    expect(addBtn.label).toBe("New Form");
  });

  // ── Modal focus trap ────────────────────────────────────────────────────

  it("renders the New Form modal after the add button is clicked", () => {
    const element = appendFormBuilderVisual();

    element.shadowRoot
      .querySelector('[slot="actions"]')
      .dispatchEvent(
        new CustomEvent("click", { bubbles: true, composed: false })
      );

    return Promise.resolve().then(() => {
      expect(
        element.shadowRoot.querySelector('[data-modal-root="newForm"]')
      ).not.toBeNull();
    });
  });

  it("closes the New Form modal when Escape is pressed inside it", () => {
    const element = appendFormBuilderVisual();

    element.shadowRoot
      .querySelector('[slot="actions"]')
      .dispatchEvent(
        new CustomEvent("click", { bubbles: true, composed: false })
      );

    return Promise.resolve()
      .then(() => {
        const modalRoot = element.shadowRoot.querySelector(
          '[data-modal-root="newForm"]'
        );
        expect(modalRoot).not.toBeNull();
        modalRoot.dispatchEvent(
          new KeyboardEvent("keydown", {
            key: "Escape",
            bubbles: true,
            composed: false
          })
        );
      })
      .then(() => {
        expect(
          element.shadowRoot.querySelector('[data-modal-root="newForm"]')
        ).toBeNull();
      });
  });

  it("calls preventDefault on Tab keydown inside the New Form modal", () => {
    const element = appendFormBuilderVisual();

    element.shadowRoot
      .querySelector('[slot="actions"]')
      .dispatchEvent(
        new CustomEvent("click", { bubbles: true, composed: false })
      );

    return Promise.resolve().then(() => {
      const modalRoot = element.shadowRoot.querySelector(
        '[data-modal-root="newForm"]'
      );
      expect(modalRoot).not.toBeNull();

      const tabEvent = new KeyboardEvent("keydown", {
        key: "Tab",
        bubbles: true,
        composed: false,
        cancelable: true
      });
      modalRoot.dispatchEvent(tabEvent);

      expect(tabEvent.defaultPrevented).toBe(true);
    });
  });

  it("disconnects without throwing when a modal is open", () => {
    const element = appendFormBuilderVisual();

    element.shadowRoot
      .querySelector('[slot="actions"]')
      .dispatchEvent(
        new CustomEvent("click", { bubbles: true, composed: false })
      );

    return Promise.resolve().then(() => {
      expect(() => document.body.removeChild(element)).not.toThrow();
    });
  });
});

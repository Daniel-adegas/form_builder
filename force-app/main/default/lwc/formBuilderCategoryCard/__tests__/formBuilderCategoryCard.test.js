import { createElement } from "@lwc/engine-dom";
import FormBuilderCategoryCard from "c/formBuilderCategoryCard";

function buildCategoryRow(overrides = {}) {
  return {
    isCategoryRow: true,
    Id: "cat-1",
    Name: "General",
    collapseIcon: "utility:chevrondown",
    iconName: "standard:category",
    hidePageBody: true,
    ...overrides
  };
}

function appendCategoryCard(props = {}) {
  const element = createElement("c-form-builder-category-card", {
    is: FormBuilderCategoryCard
  });
  Object.assign(element, {
    row: buildCategoryRow(),
    ...props
  });
  document.body.appendChild(element);
  return element;
}

describe("c-form-builder-category-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  describe("builderelementclick", () => {
    it("dispatches builderelementclick when the category header is clicked", () => {
      const element = appendCategoryCard();
      const handler = jest.fn();
      element.addEventListener("builderelementclick", handler);

      const header = element.shadowRoot.querySelector(
        '[data-elementtype="category"]'
      );
      expect(header).not.toBeNull();
      header.click();

      expect(handler).toHaveBeenCalledTimes(1);
      const evt = handler.mock.calls[0][0];
      expect(evt.bubbles).toBe(true);
      expect(evt.composed).toBe(true);
      expect(evt.detail).toEqual({
        elementType: "category",
        elementId: "cat-1"
      });
    });
  });

  describe("buildertogglecollapse", () => {
    it("dispatches buildertogglecollapse when the collapse control is clicked", () => {
      const element = appendCategoryCard();
      const handler = jest.fn();
      element.addEventListener("buildertogglecollapse", handler);

      const toggle = element.shadowRoot.querySelector(
        "lightning-button-icon.collapse-toggle"
      );
      expect(toggle).not.toBeNull();
      toggle.click();

      expect(handler).toHaveBeenCalledTimes(1);
      const evt = handler.mock.calls[0][0];
      expect(evt.bubbles).toBe(true);
      expect(evt.composed).toBe(true);
      expect(evt.detail).toEqual({ id: "cat-1" });
    });
  });

  describe("builderquickaddpage", () => {
    it("dispatches builderquickaddpage with categoryId from the category add button", () => {
      const element = appendCategoryCard();
      const handler = jest.fn();
      element.addEventListener("builderquickaddpage", handler);

      const addBtn = element.shadowRoot.querySelector(
        'lightning-button-icon[data-categoryid="cat-1"]'
      );
      expect(addBtn).not.toBeNull();
      addBtn.click();

      expect(handler).toHaveBeenCalledTimes(1);
      const evt = handler.mock.calls[0][0];
      expect(evt.bubbles).toBe(true);
      expect(evt.composed).toBe(true);
      expect(evt.detail).toEqual({ categoryId: "cat-1" });
    });

    it("dispatches builderquickaddpage with null categoryId from the root pages toolbar", () => {
      const element = appendCategoryCard({
        row: {
          isRootPagesRow: true,
          hidePageBody: true
        }
      });
      const handler = jest.fn();
      element.addEventListener("builderquickaddpage", handler);

      const addBtn = element.shadowRoot.querySelector("lightning-button-icon");
      expect(addBtn).not.toBeNull();
      addBtn.click();

      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler.mock.calls[0][0].detail).toEqual({ categoryId: null });
    });

    it("hides quick-add controls when suppressRepositoryChrome is true", () => {
      const element = appendCategoryCard({ suppressRepositoryChrome: true });

      expect(
        element.shadowRoot.querySelector(
          'lightning-button-icon[data-categoryid="cat-1"]'
        )
      ).toBeNull();
    });
  });

  describe("builder drag events", () => {
    it("dispatches builderdragstart with reorder payload on category dragstart", () => {
      const element = appendCategoryCard();
      const handler = jest.fn();
      element.addEventListener("builderdragstart", handler);

      const header = element.shadowRoot.querySelector(
        '[data-elementtype="category"]'
      );
      const dataTransfer = { setData: jest.fn(), effectAllowed: "" };
      const dragEvent = new CustomEvent("dragstart", {
        bubbles: true,
        composed: true
      });
      Object.defineProperty(dragEvent, "dataTransfer", {
        value: dataTransfer
      });
      header.dispatchEvent(dragEvent);

      expect(handler).toHaveBeenCalledTimes(1);
      const evt = handler.mock.calls[0][0];
      expect(evt.bubbles).toBe(true);
      expect(evt.composed).toBe(true);
      expect(evt.detail).toEqual({
        itemType: "category",
        itemId: "cat-1",
        parentId: ""
      });
      expect(dataTransfer.setData).toHaveBeenCalledWith(
        "text/plain",
        JSON.stringify({
          dragType: "reorder",
          itemType: "category",
          itemId: "cat-1",
          parentId: "",
          source: "canvas"
        })
      );
      expect(dataTransfer.effectAllowed).toBe("move");
    });

    it("dispatches builderdragend when drag ends on the category header", () => {
      const element = appendCategoryCard();
      const handler = jest.fn();
      element.addEventListener("builderdragend", handler);

      const header = element.shadowRoot.querySelector(
        '[data-elementtype="category"]'
      );
      header.dispatchEvent(
        new CustomEvent("dragend", { bubbles: true, composed: true })
      );

      expect(handler).toHaveBeenCalledTimes(1);
      const evt = handler.mock.calls[0][0];
      expect(evt.bubbles).toBe(true);
      expect(evt.composed).toBe(true);
    });
  });

  describe("categoryHeaderClass", () => {
    it("adds is-dragging-source when this row is the drag source", () => {
      const element = appendCategoryCard({ draggingSourceId: "cat-1" });
      const header = element.shadowRoot.querySelector(
        '[data-elementtype="category"]'
      );
      expect(header.classList.contains("is-dragging-source")).toBe(true);
    });
  });
});

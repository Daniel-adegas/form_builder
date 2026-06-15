import { LightningElement, api } from "lwc";

export default class FormBuilderCategoryCard extends LightningElement {
  @api row;
  @api isDragging = false;
  @api dragItemType = "";
  @api dragType = "";
  @api draggingSourceId;
  @api showScoring = false;
  /** Asset repository isolated edit: hide root/category chrome and quick adds. */
  @api suppressRepositoryChrome = false;
  /** When true, quick-add page controls are disabled (e.g. conversational single-page forms). */
  @api pageAddDisabled = false;
  @api pageAddDisabledTitle = "";

  get showRepositoryChrome() {
    return !this.suppressRepositoryChrome;
  }

  get showPageBody() {
    return !this.row?.hidePageBody;
  }

  get categoryHeaderClass() {
    let cls = "canvas-category-header";
    if (this.row?.isCategoryRow && this.draggingSourceId === this.row.Id) {
      cls += " is-dragging-source";
    }
    return cls;
  }

  handleCategoryDragStart(event) {
    event.stopPropagation();
    const itemType = event.currentTarget.dataset.itemtype;
    const itemId = event.currentTarget.dataset.id;
    const parentId = event.currentTarget.dataset.parentid || "";
    event.dataTransfer.setData(
      "text/plain",
      JSON.stringify({
        dragType: "reorder",
        itemType,
        itemId,
        parentId,
        source: "canvas"
      })
    );
    event.dataTransfer.effectAllowed = "move";
    this.dispatchEvent(
      new CustomEvent("builderdragstart", {
        detail: { itemType, itemId, parentId },
        bubbles: true,
        composed: true
      })
    );
  }

  handleDragEnd() {
    this.dispatchEvent(
      new CustomEvent("builderdragend", { bubbles: true, composed: true })
    );
  }

  handleElementClick(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("builderelementclick", {
        detail: {
          elementType: event.currentTarget.dataset.elementtype,
          elementId: event.currentTarget.dataset.id
        },
        bubbles: true,
        composed: true
      })
    );
  }

  handleToggleCollapse(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("buildertogglecollapse", {
        detail: { id: event.currentTarget.dataset.id },
        bubbles: true,
        composed: true
      })
    );
  }

  handleQuickAddPage(event) {
    event.stopPropagation();
    const cid = event.currentTarget.dataset.categoryid;
    this.dispatchEvent(
      new CustomEvent("builderquickaddpage", {
        detail: { categoryId: cid || null },
        bubbles: true,
        composed: true
      })
    );
  }
}

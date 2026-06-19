import { LightningElement, api } from "lwc";

export default class FormRendererLayoutClassic extends LightningElement {
  @api currentPage;
  @api currentPageName;
  @api currentPageDescription;
  @api currentSections;
  @api readOnly;
  @api featureSettings;

  handleValueChange(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("valuechange", {
        detail: event.detail,
        bubbles: true,
        composed: true
      })
    );
  }
}

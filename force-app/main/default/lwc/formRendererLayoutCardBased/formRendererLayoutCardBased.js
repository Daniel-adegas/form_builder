import { LightningElement, api } from "lwc";

export default class FormRendererLayoutCardBased extends LightningElement {
  @api currentPage;
  @api currentPageName;
  @api currentPageDescription;
  @api currentSections;
  @api readOnly;
  @api featureSettings;

  get questionCards() {
    const cards = [];

    for (const section of this.currentSections || []) {
      for (const question of section.visibleQuestions || []) {
        cards.push({
          ...question,
          sectionId: section.sectionId,
          sectionName: section.translatedName,
          isBonusSection: section.bonus
        });
      }
    }

    return cards;
  }

  get hasQuestions() {
    return this.questionCards.length > 0;
  }

  handleValueChange(event) {
    // Child event bubbles/composes to this host; re-dispatch once for parents.
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

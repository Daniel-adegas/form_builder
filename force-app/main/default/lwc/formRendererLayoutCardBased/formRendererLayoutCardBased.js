import { LightningElement, api } from 'lwc';

export default class FormRendererLayoutCardBased extends LightningElement {
    @api currentPage;
    @api currentPageName;
    @api currentPageDescription;
    @api currentSections;
    @api readOnly;
    @api featureSettings;
    @api handleResponse;

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
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: event.detail,
            bubbles: true,
            composed: true
        }));
    }
}
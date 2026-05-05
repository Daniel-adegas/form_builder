import { LightningElement, api } from 'lwc';

export default class FormRendererLayoutClassic extends LightningElement {
    @api currentPage;
    @api currentPageName;
    @api currentPageDescription;
    @api currentSections;
    @api isFirstPage;
    @api isLastPage;
    @api isReadOnly;
    @api showSubmitButton;
    @api readOnlyBannerText;
    @api featureSettings;
    @api handleResponse;
    @api progressWidth;
}
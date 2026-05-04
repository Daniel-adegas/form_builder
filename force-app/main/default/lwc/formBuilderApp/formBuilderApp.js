/**
 * @description       : Unified Form Builder App - single page with tabbed navigation for Documentation, Functional Builder, Visual Builder, and Form Renderer
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   18-03-2026   Daniel Murracas     Extracted renderer to standalone formRenderer LWC
 * ------------------------------------------------------------
**/
import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFeatureSettings from '@salesforce/apex/FeatureSettingsService.getFeatureSettings';

export default class FormBuilderApp extends LightningElement {

    activeTab = 'documentation';
    assetRepositoryEnabled = false;

    errorCallback(error, stack) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Component Error',
            message: error?.message || 'An unexpected error occurred',
            variant: 'error'
        }));
        console.error('FormBuilderApp error:', error, 'Stack:', stack);
    }

    connectedCallback() {
        this.loadFeatureSettings();
    }

    async loadFeatureSettings() {
        try {
            const s = await getFeatureSettings();
            this.assetRepositoryEnabled = s?.assetRepository === true;
        } catch (e) {
            this.assetRepositoryEnabled = false;
        }
    }

    get isDocumentationTab() { return this.activeTab === 'documentation'; }
    get isVisualTab() { return this.activeTab === 'visual'; }
    get isRendererTab() { return this.activeTab === 'renderer'; }
    get isRepositoryTab() { return this.activeTab === 'repository'; }

    get showAssetRepositoryTab() {
        return this.assetRepositoryEnabled === true;
    }

    getTabClass(tabName) {
        return this.activeTab === tabName ? 'tab-button active' : 'tab-button';
    }
    get docTabClass() { return this.getTabClass('documentation'); }
    get visTabClass() { return this.getTabClass('visual'); }
    get rendTabClass() { return this.getTabClass('renderer'); }
    get repoTabClass() { return this.getTabClass('repository'); }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }
}

/**
 * @description       : Inline dependency viewer and quick-creator for property panels
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FormDependencyInline extends LightningElement {
    @api elementId;
    @api elementType; // 'page', 'section', 'question', 'response'
    @api dependencies = [];
    @api allResponses = []; // { label, value }
    @api allTargets = []; // { label, value, type: 'Page'|'Section'|'Question' }

    @track showAddForm = false;
    @track newDep = {};
    @track editingDepId = null;

    get addButtonIcon() {
        return this.showAddForm ? 'utility:dash' : 'utility:add';
    }

    get saveButtonLabel() {
        return this.editingDepId ? 'Update' : 'Save';
    }

    get actionOptions() {
        return [
            { label: 'Show', value: 'Show' },
            { label: 'Hide', value: 'Hide' },
            { label: 'Require', value: 'Require' }
        ];
    }

    get targetTypeOptions() {
        const opts = [];
        if (this.allTargets.some(t => t.type === 'Category')) {
            opts.push({ label: 'Category', value: 'Category' });
        }
        opts.push(
            { label: 'Page', value: 'Page' },
            { label: 'Section', value: 'Section' },
            { label: 'Question', value: 'Question' }
        );
        return opts;
    }

    get capitalizedType() {
        if (!this.elementType) return '';
        return this.elementType.charAt(0).toUpperCase() + this.elementType.slice(1);
    }

    get incomingDeps() {
        if (!this.elementId || !this.dependencies) return [];
        if (this.elementType === 'response') return [];
        return this.dependencies.filter(dep => {
            if (this.elementType === 'category') return dep.C_Target_Category__c === this.elementId;
            if (this.elementType === 'page') return dep.C_Target_Page__c === this.elementId;
            if (this.elementType === 'section') return dep.C_Target_Section__c === this.elementId;
            if (this.elementType === 'question') return dep.C_Target_Question__c === this.elementId;
            return false;
        });
    }

    get outgoingDeps() {
        if (!this.elementId || !this.dependencies) return [];
        if (this.elementType === 'response') {
            return this.dependencies.filter(dep => dep.C_Controlling_Response__c === this.elementId);
        }
        return [];
    }

    get hasIncoming() { return this.incomingDeps.length > 0; }
    get hasOutgoing() { return this.outgoingDeps.length > 0; }
    get hasDeps() { return this.hasIncoming || this.hasOutgoing; }

    get enrichedIncoming() {
        return this.incomingDeps.map(dep => ({
            ...dep,
            actionClass: this._actionClass(dep.C_Action__c),
            controllingLabel: this._getResponseLabel(dep.C_Controlling_Response__c),
            directionLabel: 'Incoming'
        }));
    }

    get enrichedOutgoing() {
        return this.outgoingDeps.map(dep => ({
            ...dep,
            actionClass: this._actionClass(dep.C_Action__c),
            targetLabel: this._getTargetLabel(dep),
            controllingLabel: this._getResponseLabel(dep.C_Controlling_Response__c),
            directionLabel: 'Outgoing'
        }));
    }

    get isTargetDisabled() {
        return !this.newDep.C_Target_Type__c;
    }

    get filteredTargets() {
        if (!this.newDep.C_Target_Type__c) return [];
        return this.allTargets.filter(t => t.type === this.newDep.C_Target_Type__c);
    }

    get selectedTargetValue() {
        const tt = this.newDep.C_Target_Type__c;
        if (tt === 'Category') return this.newDep.C_Target_Category__c;
        if (tt === 'Page') return this.newDep.C_Target_Page__c;
        if (tt === 'Section') return this.newDep.C_Target_Section__c;
        if (tt === 'Question') return this.newDep.C_Target_Question__c;
        return '';
    }

    get targetCategoryId() {
        if (this.newDep?.C_Target_Type__c === 'Category') {
            return this.newDep.C_Target_Category__c || this.elementId || null;
        }
        return null;
    }

    get contextResponseOptions() {
        if (this.elementType === 'response') {
            return this.allResponses.filter(r => r.value === this.elementId);
        }
        if (this.elementType === 'category' && this.targetCategoryId) {
            return this.allResponses.filter(r =>
                r.value === this.newDep.C_Controlling_Response__c ||
                r.categoryId !== this.targetCategoryId
            );
        }
        return this.allResponses;
    }

    get isResponseMode() {
        return this.elementType === 'response';
    }

    _actionClass(action) {
        if (action === 'Show') return 'action-show';
        if (action === 'Hide') return 'action-hide';
        if (action === 'Require') return 'action-require';
        return 'action-show';
    }

    _getResponseLabel(responseId) {
        const found = this.allResponses.find(r => r.value === responseId);
        return found ? found.label : responseId;
    }

    _getTargetLabel(dep) {
        let targetId;
        if (dep.C_Target_Type__c === 'Category') targetId = dep.C_Target_Category__c;
        else if (dep.C_Target_Type__c === 'Page') targetId = dep.C_Target_Page__c;
        else if (dep.C_Target_Type__c === 'Section') targetId = dep.C_Target_Section__c;
        else if (dep.C_Target_Type__c === 'Question') targetId = dep.C_Target_Question__c;

        const found = this.allTargets.find(t => t.value === targetId);
        return found ? found.label : `${dep.C_Target_Type__c}: ${targetId}`;
    }

    handleEditDep(event) {
        const depId = event.currentTarget.dataset.id;
        const all = [...this.incomingDeps, ...this.outgoingDeps];
        const dep = all.find(d => d.Id === depId);
        if (!dep) return;

        this.editingDepId = depId;
        this.showAddForm = true;
        this.newDep = {
            C_Controlling_Response__c: dep.C_Controlling_Response__c,
            C_Action__c: dep.C_Action__c,
            C_Target_Type__c: dep.C_Target_Type__c,
            C_Target_Category__c: dep.C_Target_Category__c,
            C_Target_Page__c: dep.C_Target_Page__c,
            C_Target_Section__c: dep.C_Target_Section__c,
            C_Target_Question__c: dep.C_Target_Question__c
        };
    }

    handleToggleAdd() {
        this.showAddForm = !this.showAddForm;
        if (!this.showAddForm) {
            this.editingDepId = null;
            this.newDep = {};
        } else if (this.showAddForm) {
            this._prefillNewDep();
        }
    }

    _prefillNewDep() {
        const dep = {
            C_Controlling_Response__c: '',
            C_Action__c: 'Show',
            C_Target_Type__c: '',
            C_Target_Category__c: null,
            C_Target_Page__c: null,
            C_Target_Section__c: null,
            C_Target_Question__c: null
        };

        if (this.elementType === 'category') {
            dep.C_Target_Type__c = 'Category';
            dep.C_Target_Category__c = this.elementId;
        } else if (this.elementType === 'page') {
            dep.C_Target_Type__c = 'Page';
            dep.C_Target_Page__c = this.elementId;
        } else if (this.elementType === 'section') {
            dep.C_Target_Type__c = 'Section';
            dep.C_Target_Section__c = this.elementId;
        } else if (this.elementType === 'question') {
            dep.C_Target_Type__c = 'Question';
            dep.C_Target_Question__c = this.elementId;
        } else if (this.elementType === 'response') {
            dep.C_Controlling_Response__c = this.elementId;
        }

        this.newDep = dep;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.newDep = { ...this.newDep, [field]: event.detail.value };

        if (field === 'C_Target_Type__c') {
            this.newDep = {
                ...this.newDep,
                C_Target_Category__c: null,
                C_Target_Page__c: null,
                C_Target_Section__c: null,
                C_Target_Question__c: null
            };
        }
    }

    handleTargetChange(event) {
        const targetId = event.detail.value;
        const tt = this.newDep.C_Target_Type__c;
        if (tt === 'Category') {
            this.newDep = { ...this.newDep, C_Target_Category__c: targetId, C_Target_Page__c: null, C_Target_Section__c: null, C_Target_Question__c: null };
        } else if (tt === 'Page') {
            this.newDep = { ...this.newDep, C_Target_Category__c: null, C_Target_Page__c: targetId, C_Target_Section__c: null, C_Target_Question__c: null };
        } else if (tt === 'Section') {
            this.newDep = { ...this.newDep, C_Target_Category__c: null, C_Target_Page__c: null, C_Target_Section__c: targetId, C_Target_Question__c: null };
        } else if (tt === 'Question') {
            this.newDep = { ...this.newDep, C_Target_Category__c: null, C_Target_Page__c: null, C_Target_Section__c: null, C_Target_Question__c: targetId };
        }
    }

    handleSave() {
        const dep = { ...this.newDep };
        if (!dep.C_Controlling_Response__c || !dep.C_Target_Type__c || !dep.C_Action__c) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Please fill in all required dependency fields (Controlling Response, Target Type, Action).',
                variant: 'warning'
            }));
            return;
        }
        const hasTarget = dep.C_Target_Category__c || dep.C_Target_Page__c || dep.C_Target_Section__c || dep.C_Target_Question__c;
        if (!hasTarget) return;

        if (this.editingDepId) {
            this.dispatchEvent(new CustomEvent('updatedependency', {
                detail: { dependency: { ...dep, Id: this.editingDepId } },
                bubbles: true,
                composed: true
            }));
            this.editingDepId = null;
        } else {
            this.dispatchEvent(new CustomEvent('savedependency', {
                detail: { dependency: dep },
                bubbles: true,
                composed: true
            }));
        }
        this.showAddForm = false;
        this.newDep = {};
    }

    handleDelete(event) {
        event.stopPropagation();
        const depId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('deletedependency', {
            detail: { dependencyId: depId },
            bubbles: true,
            composed: true
        }));
    }

    handleCancel() {
        this.showAddForm = false;
        this.newDep = {};
        this.editingDepId = null;
    }
}

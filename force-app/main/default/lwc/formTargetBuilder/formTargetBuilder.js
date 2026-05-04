import { LightningElement, api, track } from 'lwc';
import getAllFormTargets from '@salesforce/apex/FieldMappingService.getAllFormTargets';
import saveFormTarget from '@salesforce/apex/FieldMappingService.saveFormTarget';
import deleteFormTarget from '@salesforce/apex/FieldMappingService.deleteFormTarget';
import saveFieldMapping from '@salesforce/apex/FieldMappingService.saveFieldMapping';
import deleteFieldMapping from '@salesforce/apex/FieldMappingService.deleteFieldMapping';
import getCreatableObjects from '@salesforce/apex/FieldMappingService.getCreatableObjects';
import getObjectFields from '@salesforce/apex/FieldMappingService.getObjectFields';
import getUserLookupFields from '@salesforce/apex/FieldMappingService.getUserLookupFields';

const RESOLUTION_OPTIONS = [
    { label: 'Record Context (passed by caller)', value: 'Record_Context' },
    { label: 'Running User (auto-resolve from User)', value: 'Running_User' },
    { label: 'Related Record (chain from another target)', value: 'Related_Record' },
    { label: 'Create New Record', value: 'New' },
    { label: 'Running User Account (Legacy)', value: 'Running_User_Account' },
    { label: 'Running User Contact (Legacy)', value: 'Running_User_Contact' }
];

const OPERATION_OPTIONS = [
    { label: 'Update', value: 'Update' },
    { label: 'Create', value: 'Create' },
    { label: 'Upsert', value: 'Upsert' }
];

const MAPPING_TYPE_OPTIONS = [
    { label: 'Field Value (from question)', value: 'Field_Value' },
    { label: 'Static Value', value: 'Static_Value' },
    { label: 'File Attachment', value: 'File_Attachment' },
    { label: 'Table JSON', value: 'Table_JSON' }
];

const DIRECTION_OPTIONS = [
    { label: 'Outbound (Form -> Record)', value: 'Outbound' },
    { label: 'Inbound (Record -> Form)', value: 'Inbound' },
    { label: 'Bidirectional (Both)', value: 'Bidirectional' }
];

export default class FormTargetBuilder extends LightningElement {
    _formId;
    @api
    get formId() { return this._formId; }
    set formId(value) {
        this._formId = value;
        if (value) this.loadTargets();
    }

    @api questions = [];

    @track targets = [];
    @track objectOptions = [];
    @track fieldOptions = {};
    @track isLoading = false;
    @track expandedTarget = null;
    @track isAddingTarget = false;
    @track newTarget = {};
    @track isAddingMapping = false;
    @track newMapping = {};
    @track activeMappingTarget = null;
    @track editingMappingId = null;
    @track editingTargetId = null;
    @track userLookupOptions = [];

    get resolutionOptions() {
        return RESOLUTION_OPTIONS;
    }

    get operationOptions() {
        return OPERATION_OPTIONS;
    }

    get mappingTypeOptions() {
        return MAPPING_TYPE_OPTIONS;
    }

    get directionOptions() {
        return DIRECTION_OPTIONS;
    }

    get hasTargets() {
        return this.targets && this.targets.length > 0;
    }

    get enrichedTargets() {
        return this.targets.map(t => {
            const isExpanded = this.expandedTarget === t.Id;
            const mappings = t.C_Field_Mappings__r || [];
            const hasMappings = mappings.length > 0;
            const isAddingMappingHere = this.isAddingMapping && this.activeMappingTarget === t.Id;
            const fieldOpts = this.fieldOptions[t.Id] || [];

            const enrichedMappings = mappings.map(m => {
                const questionLabel = m.C_Question__r
                    ? m.C_Question__r.C_Question_Text__c || m.C_Question__r.Name
                    : '—';
                return {
                    ...m,
                    questionLabel,
                    typeBadgeLabel: this.getMappingTypeLabel(m.C_Mapping_Type__c)
                };
            });

            const dir = t.C_Direction__c || 'Outbound';
            const dirArrow = dir === 'Inbound' ? '\u2B05' : dir === 'Bidirectional' ? '\u2B0C' : '\u27A1';
            const dirBadgeClass = `badge badge-direction badge-dir-${dir.toLowerCase()}`;

            let resDetail = this.getResolutionLabel(t.C_Resolution_Type__c);
            if (t.C_Resolution_Type__c === 'Record_Context' && t.C_Context_Key__c)
                resDetail += ` [key: ${t.C_Context_Key__c}]`;
            if ((t.C_Resolution_Type__c === 'Running_User' || t.C_Resolution_Type__c === 'Running_User_Account' || t.C_Resolution_Type__c === 'Running_User_Contact') && t.C_User_Lookup_Field__c)
                resDetail += ` [${t.C_User_Lookup_Field__c}]`;
            if (t.C_Resolution_Type__c === 'Related_Record' && t.C_Related_Field_Path__c)
                resDetail += ` [${t.C_Related_Field_Path__c}]`;

            return {
                ...t,
                isExpanded,
                hasMappings,
                isAddingMappingHere,
                fieldOpts,
                enrichedMappings,
                expandIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                activeBadgeClass: t.C_Is_Active__c ? 'badge badge-active' : 'badge badge-inactive',
                activeBadgeLabel: t.C_Is_Active__c ? 'Active' : 'Inactive',
                resolutionLabel: resDetail,
                operationLabel: this.getOperationLabel(t.C_Record_Operation__c),
                directionLabel: dir,
                directionArrow: dirArrow,
                dirBadgeClass
            };
        });
    }

    get showStaticValueInput() {
        return this.newMapping.C_Mapping_Type__c === 'Static_Value';
    }

    get mappingFormTitle() {
        return this.editingMappingId ? 'Edit Field Mapping' : 'New Field Mapping';
    }

    get targetFormTitle() {
        return this.editingTargetId ? 'Edit Form Target' : 'New Form Target';
    }

    get isNewMappingFieldValue() {
        return !this.newMapping.C_Mapping_Type__c || this.newMapping.C_Mapping_Type__c === 'Field_Value';
    }

    get showContextKey() {
        return this.newTarget.C_Resolution_Type__c === 'Record_Context';
    }

    get showUserLookupField() {
        const rt = this.newTarget.C_Resolution_Type__c;
        return rt === 'Running_User' || rt === 'Running_User_Account' || rt === 'Running_User_Contact';
    }

    get showExternalIdField() {
        return this.newTarget.C_Record_Operation__c === 'Upsert';
    }

    get showRelatedTarget() {
        return this.newTarget.C_Resolution_Type__c === 'Related_Record';
    }

    get relatedTargetOptions() {
        return this.targets
            .filter(t => t.Id !== this.editingTargetId)
            .map(t => ({ label: `${t.Name} (${t.C_Target_Object__c})`, value: t.Id }));
    }

    connectedCallback() {
        this.loadObjects();
    }

    async loadTargets() {
        this.isLoading = true;
        try {
            const data = await getAllFormTargets({ formId: this.formId });
            this.targets = data || [];
            const loadPromises = this.targets
                .filter(t => t.C_Target_Object__c)
                .map(t => this.loadFieldOptionsForTarget(t.Id, t.C_Target_Object__c));
            await Promise.all(loadPromises);
        } catch (error) {
            this.fireToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadObjects() {
        try {
            const data = await getCreatableObjects();
            this.objectOptions = data || [];
        } catch (error) {
            this.fireToast('Error', 'Failed to load objects: ' + this.reduceError(error), 'error');
        }
    }

    async loadFieldOptionsForTarget(targetId, objectName) {
        try {
            const fields = await getObjectFields({ objectName });
            this.fieldOptions = { ...this.fieldOptions, [targetId]: fields || [] };
        } catch (error) {
            this.fieldOptions = { ...this.fieldOptions, [targetId]: [] };
        }
    }

    getResolutionLabel(value) {
        const opt = RESOLUTION_OPTIONS.find(o => o.value === value);
        return opt ? opt.label : value || '—';
    }

    getOperationLabel(value) {
        const opt = OPERATION_OPTIONS.find(o => o.value === value);
        return opt ? opt.label : value || '—';
    }

    getMappingTypeLabel(value) {
        const opt = MAPPING_TYPE_OPTIONS.find(o => o.value === value);
        return opt ? opt.label : value || 'Field Value';
    }

    toggleTarget(event) {
        const targetId = event.currentTarget.dataset.id;
        this.expandedTarget = this.expandedTarget === targetId ? null : targetId;
    }

    handleAddTarget() {
        this.isAddingTarget = true;
        this.newTarget = {
            C_Form__c: this.formId,
            C_Target_Object__c: '',
            C_Resolution_Type__c: 'Record_Context',
            C_Record_Operation__c: 'Update',
            C_Direction__c: 'Outbound',
            C_Description__c: '',
            C_Context_Key__c: '',
            C_User_Lookup_Field__c: '',
            C_Related_Target__c: null,
            C_Related_Field_Path__c: '',
            C_External_Id_Field__c: '',
            C_Is_Active__c: true,
            C_Order__c: this.targets.length + 1
        };
    }

    handleEditTarget(event) {
        event.stopPropagation();
        const targetId = event.currentTarget.dataset.id;
        const target = this.targets.find(t => t.Id === targetId);
        if (!target) return;

        this.editingTargetId = targetId;
        this.isAddingTarget = true;
        this.newTarget = {
            Id: target.Id,
            C_Form__c: this.formId,
            C_Target_Object__c: target.C_Target_Object__c || '',
            C_Resolution_Type__c: target.C_Resolution_Type__c || 'Record_Context',
            C_Record_Operation__c: target.C_Record_Operation__c || 'Update',
            C_Direction__c: target.C_Direction__c || 'Outbound',
            C_Description__c: target.C_Description__c || '',
            C_Context_Key__c: target.C_Context_Key__c || '',
            C_User_Lookup_Field__c: target.C_User_Lookup_Field__c || '',
            C_Related_Target__c: target.C_Related_Target__c || null,
            C_Related_Field_Path__c: target.C_Related_Field_Path__c || '',
            C_External_Id_Field__c: target.C_External_Id_Field__c || '',
            C_Is_Active__c: target.C_Is_Active__c !== false,
            C_Order__c: target.C_Order__c || 1
        };
        const rt = target.C_Resolution_Type__c;
        if ((rt === 'Running_User' || rt === 'Running_User_Account' || rt === 'Running_User_Contact') && target.C_Target_Object__c) {
            this._loadUserLookupFields(target.C_Target_Object__c);
        }
    }

    handleCancelAddTarget() {
        this.isAddingTarget = false;
        this.editingTargetId = null;
        this.newTarget = {};
    }

    handleNewTargetFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        let value = event.detail.value;
        if (field === 'C_Is_Active__c') {
            value = event.detail.checked;
        }
        this.newTarget = { ...this.newTarget, [field]: value };
        const userTypes = ['Running_User', 'Running_User_Account', 'Running_User_Contact'];
        if (field === 'C_Resolution_Type__c') {
            if (userTypes.includes(value) && this.newTarget.C_Target_Object__c) {
                this._loadUserLookupFields(this.newTarget.C_Target_Object__c);
            } else if (!userTypes.includes(value)) {
                this.userLookupOptions = [];
            }
        }
    }

    async _loadUserLookupFields(targetObjectName) {
        try {
            this.userLookupOptions = await getUserLookupFields({ targetObjectName });
        } catch (e) {
            this.userLookupOptions = [];
        }
    }

    async handleNewTargetObjectChange(event) {
        const objectName = event.detail.value;
        this.newTarget = { ...this.newTarget, C_Target_Object__c: objectName };
        if (objectName) {
            try {
                const fields = await getObjectFields({ objectName });
                const key = this.editingTargetId || '_new';
                this.fieldOptions = { ...this.fieldOptions, [key]: fields || [] };
            } catch (error) {
                const key = this.editingTargetId || '_new';
                this.fieldOptions = { ...this.fieldOptions, [key]: [] };
            }
            const userTypes = ['Running_User', 'Running_User_Account', 'Running_User_Contact'];
            if (userTypes.includes(this.newTarget.C_Resolution_Type__c)) {
                this._loadUserLookupFields(objectName);
            }
        }
    }

    async handleSaveNewTarget() {
        if (!this.newTarget.C_Target_Object__c) {
            this.fireToast('Validation', 'Please select a target object.', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            const isEdit = !!this.editingTargetId;
            const targetToSave = { ...this.newTarget };
            if (!isEdit) {
                delete targetToSave.Id;
            }
            await saveFormTarget({ target: targetToSave });
            this.isAddingTarget = false;
            this.editingTargetId = null;
            this.newTarget = {};
            this.fireToast('Success', isEdit ? 'Form target updated.' : 'Form target created.', 'success');
            await this.loadTargets();
            this._fireMappingChanged();
        } catch (error) {
            this.fireToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteTarget(event) {
        event.stopPropagation();
        const targetId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await deleteFormTarget({ targetId });
            if (this.expandedTarget === targetId) {
                this.expandedTarget = null;
            }
            this.fireToast('Success', 'Form target deleted.', 'success');
            await this.loadTargets();
            this._fireMappingChanged();
        } catch (error) {
            this.fireToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleAddMapping(event) {
        const targetId = event.currentTarget.dataset.id;
        this.activeMappingTarget = targetId;
        this.isAddingMapping = true;
        this.newMapping = {
            C_Form_Target__c: targetId,
            C_Question__c: '',
            C_Target_Field__c: '',
            C_Mapping_Type__c: 'Field_Value',
            C_Static_Value__c: '',
            C_Is_Active__c: true
        };

        const target = this.targets.find(t => t.Id === targetId);
        if (target && target.C_Target_Object__c) {
            this.newMapping.C_Target_Object__c = target.C_Target_Object__c;
        }
    }

    handleEditMapping(event) {
        event.stopPropagation();
        const mappingId = event.currentTarget.dataset.id;
        const targetId = event.currentTarget.dataset.targetid;
        const target = this.targets.find(t => t.Id === targetId);
        if (!target) return;

        const mapping = (target.C_Field_Mappings__r || []).find(m => m.Id === mappingId);
        if (!mapping) return;

        this.expandedTarget = targetId;
        this.activeMappingTarget = targetId;
        this.isAddingMapping = true;
        this.editingMappingId = mappingId;
        this.newMapping = {
            Id: mapping.Id,
            C_Form_Target__c: targetId,
            C_Question__c: mapping.C_Question__c || '',
            C_Target_Object__c: target.C_Target_Object__c,
            C_Target_Field__c: mapping.C_Target_Field__c || '',
            C_Mapping_Type__c: mapping.C_Mapping_Type__c || 'Field_Value',
            C_Static_Value__c: mapping.C_Static_Value__c || '',
            C_Is_Active__c: mapping.C_Is_Active__c !== false
        };
    }

    handleCancelAddMapping() {
        this.isAddingMapping = false;
        this.newMapping = {};
        this.activeMappingTarget = null;
        this.editingMappingId = null;
    }

    handleMappingFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.newMapping = { ...this.newMapping, [field]: event.detail.value };
    }

    async handleSaveMappingAndReload() {
        if (!this.newMapping.C_Target_Field__c) {
            this.fireToast('Validation', 'Please select a target field.', 'warning');
            return;
        }
        if (this.newMapping.C_Mapping_Type__c === 'Field_Value' && !this.newMapping.C_Question__c) {
            this.fireToast('Validation', 'Please select a question for field-value mapping.', 'warning');
            return;
        }
        if (this.newMapping.C_Mapping_Type__c === 'Static_Value' && !this.newMapping.C_Static_Value__c) {
            this.fireToast('Validation', 'Please enter a static value.', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            const isEdit = !!this.editingMappingId;
            const mappingToSave = { ...this.newMapping };
            if (!isEdit) {
                delete mappingToSave.Id;
            }
            await saveFieldMapping({ mapping: mappingToSave });
            this.isAddingMapping = false;
            this.newMapping = {};
            this.activeMappingTarget = null;
            this.editingMappingId = null;
            this.fireToast('Success', isEdit ? 'Field mapping updated.' : 'Field mapping created.', 'success');
            await this.loadTargets();
            this._fireMappingChanged();
        } catch (error) {
            this.fireToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteMapping(event) {
        const mappingId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await deleteFieldMapping({ mappingId });
            this.fireToast('Success', 'Field mapping deleted.', 'success');
            await this.loadTargets();
            this._fireMappingChanged();
        } catch (error) {
            this.fireToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    fireToast(title, message, variant) {
        this.dispatchEvent(new CustomEvent('toast', {
            bubbles: true,
            composed: true,
            detail: { title, message, variant }
        }));
    }

    _fireMappingChanged() {
        this.dispatchEvent(new CustomEvent('mappingchanged', { bubbles: true, composed: true }));
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'Unknown error';
    }
}

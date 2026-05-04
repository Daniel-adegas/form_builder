/**
 * @description       : Inline field mapping viewer and quick-creator for property panels.
 *                      Mirrors the UX of formDependencyInline but for field mappings.
 * @author            : Daniel Murracas
 * @last modified on  : 19-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   19-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveFieldMapping from '@salesforce/apex/FieldMappingService.saveFieldMapping';
import deleteFieldMapping from '@salesforce/apex/FieldMappingService.deleteFieldMapping';
import getObjectFields from '@salesforce/apex/FieldMappingService.getObjectFields';

export default class FormFieldMappingInline extends LightningElement {
    @api questionId;
    @api mappings = [];
    @api formTargets = [];

    @track showAddForm = false;
    @track editingMappingId = null;
    @track newMapping = {};
    @track targetFieldOptions = [];
    @track isLoadingFields = false;

    get addButtonIcon() {
        return this.showAddForm ? 'utility:dash' : 'utility:add';
    }

    get saveButtonLabel() {
        return this.editingMappingId ? 'Update' : 'Save';
    }

    get hasMappings() {
        return this.mappings && this.mappings.length > 0;
    }

    get enrichedMappings() {
        return (this.mappings || []).map(m => {
            const dir = m.direction || 'Outbound';
            const arrow = dir === 'Inbound' ? '\u2B05' : dir === 'Bidirectional' ? '\u2B0C' : '\u27A1';
            return {
                ...m,
                displayField: `${m.targetObject}.${m.targetField}`,
                displayMeta: `Target: ${m.targetName} | Op: ${m.operation}`,
                directionArrow: arrow,
                directionLabel: dir
            };
        });
    }

    get formTargetOptions() {
        return (this.formTargets || []).map(t => {
            let suffix = '';
            const rt = t.C_Resolution_Type__c;
            if (rt === 'Record_Context' && t.C_Context_Key__c) suffix = ` - Context [${t.C_Context_Key__c}]`;
            else if (rt === 'Running_User' || rt === 'Running_User_Account' || rt === 'Running_User_Contact') suffix = ` - User Lookup`;
            else if (rt === 'Related_Record') suffix = ` - Related`;
            else if (rt === 'New') suffix = ` - New`;
            else if (rt === 'Record_Context') suffix = ` - Context`;
            const dir = t.C_Direction__c || 'Outbound';
            const arrow = dir === 'Inbound' ? '\u2B05' : dir === 'Bidirectional' ? '\u2B0C' : '\u27A1';
            return {
                label: `${t.Name} (${t.C_Target_Object__c}) ${arrow}${suffix}`,
                value: t.Id,
                targetObject: t.C_Target_Object__c
            };
        });
    }

    get mappingTypeOptions() {
        return [
            { label: 'Field Value', value: 'Field_Value' },
            { label: 'File Attachment', value: 'File_Attachment' },
            { label: 'Table JSON', value: 'Table_JSON' },
            { label: 'Static Value', value: 'Static_Value' }
        ];
    }

    get isStaticValueType() {
        return this.newMapping.C_Mapping_Type__c === 'Static_Value';
    }

    get isTargetFieldDisabled() {
        return !this.newMapping.C_Form_Target__c || this.isLoadingFields;
    }

    handleToggleAdd() {
        this.showAddForm = !this.showAddForm;
        if (!this.showAddForm) {
            this.editingMappingId = null;
            this.newMapping = {};
            this.targetFieldOptions = [];
        } else {
            this.newMapping = {
                C_Form_Target__c: '',
                C_Question__c: this.questionId,
                C_Target_Field__c: '',
                C_Mapping_Type__c: 'Field_Value',
                C_Static_Value__c: '',
                C_Is_Active__c: true
            };
        }
    }

    handleEditMapping(event) {
        const mappingId = event.currentTarget.dataset.id;
        const m = (this.mappings || []).find(x => x.id === mappingId);
        if (!m) return;

        this.editingMappingId = mappingId;
        this.showAddForm = true;

        const target = (this.formTargets || []).find(t => t.Id === m.targetId);
        this.newMapping = {
            C_Form_Target__c: m.targetId,
            C_Question__c: this.questionId,
            C_Target_Field__c: m.targetField,
            C_Mapping_Type__c: m.mappingType,
            C_Static_Value__c: m.staticValue || '',
            C_Is_Active__c: true
        };

        if (target) {
            this._loadFieldsForObject(target.C_Target_Object__c);
        }
    }

    async handleTargetChange(event) {
        const targetId = event.detail.value;
        this.newMapping = { ...this.newMapping, C_Form_Target__c: targetId, C_Target_Field__c: '' };

        const target = (this.formTargets || []).find(t => t.Id === targetId);
        if (target && target.C_Target_Object__c) {
            await this._loadFieldsForObject(target.C_Target_Object__c);
        } else {
            this.targetFieldOptions = [];
        }
    }

    async _loadFieldsForObject(objectName) {
        this.isLoadingFields = true;
        try {
            const fields = await getObjectFields({ objectName });
            this.targetFieldOptions = fields.map(f => ({
                label: `${f.label} (${f.value})`,
                value: f.value
            }));
        } catch (e) {
            this.targetFieldOptions = [];
        } finally {
            this.isLoadingFields = false;
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.newMapping = { ...this.newMapping, [field]: event.detail.value };
    }

    async handleSave() {
        const m = this.newMapping;
        if (!m.C_Form_Target__c || !m.C_Target_Field__c || !m.C_Mapping_Type__c) return;

        if (m.C_Mapping_Type__c === 'Field_Value' && !m.C_Question__c) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'A question is required for Field Value mapping type.',
                variant: 'warning'
            }));
            return;
        }

        try {
            const record = {
                C_Form_Target__c: m.C_Form_Target__c,
                C_Question__c: m.C_Question__c,
                C_Target_Field__c: m.C_Target_Field__c,
                C_Mapping_Type__c: m.C_Mapping_Type__c,
                C_Is_Active__c: m.C_Is_Active__c
            };

            if (m.C_Mapping_Type__c === 'Static_Value' && m.C_Static_Value__c) {
                record.C_Static_Value__c = m.C_Static_Value__c;
            }

            if (this.editingMappingId) {
                record.Id = this.editingMappingId;
            }

            await saveFieldMapping({ mapping: record });
            this.showAddForm = false;
            this.editingMappingId = null;
            this.newMapping = {};
            this.targetFieldOptions = [];
            this._fireMappingChanged();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: e?.body?.message || e?.message || 'Operation failed',
                variant: 'error'
            }));
        }
    }

    async handleDelete(event) {
        event.stopPropagation();
        const mappingId = event.currentTarget.dataset.id;
        try {
            await deleteFieldMapping({ mappingId });
            this._fireMappingChanged();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: e?.body?.message || e?.message || 'Operation failed',
                variant: 'error'
            }));
        }
    }

    handleCancel() {
        this.showAddForm = false;
        this.editingMappingId = null;
        this.newMapping = {};
        this.targetFieldOptions = [];
    }

    _fireMappingChanged() {
        this.dispatchEvent(new CustomEvent('mappingchanged', {
            bubbles: true,
            composed: true
        }));
    }
}

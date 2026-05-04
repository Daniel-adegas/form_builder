/**
 * @description       : Inline cross-field validation rule editor for the form builder property panel.
 *                      Manages a list of rules stored as JSON on C_Question__c.C_Cross_Field_Rules_JSON__c.
 * @author            : Tom De Backer
 * @last modified on  : 24-03-2026
 * @last modified by  : Tom De Backer
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   24-03-2026   Tom De Backer       Initial Version
 * ------------------------------------------------------------
**/
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const RULE_TYPES_BY_QUESTION_TYPE = {
    Date: [
        { label: 'Is on or after', value: 'dateOnOrAfter' },
        { label: 'Is after', value: 'dateAfter' },
        { label: 'Is on or before', value: 'dateOnOrBefore' },
        { label: 'Is before', value: 'dateBefore' }
    ],
    Number: [
        { label: 'Is greater than or equal to', value: 'greaterOrEqual' },
        { label: 'Is greater than', value: 'greaterThan' },
        { label: 'Is less than or equal to', value: 'lessOrEqual' },
        { label: 'Is less than', value: 'lessThan' }
    ]
};

const RULE_TYPE_LABELS = {
    dateOnOrAfter:  'on or after',
    dateAfter:      'after',
    dateOnOrBefore: 'on or before',
    dateBefore:     'before',
    greaterOrEqual: '>= (number)',
    greaterThan:    '> (number)',
    lessOrEqual:    '<= (number)',
    lessThan:       '< (number)'
};

const RULE_TYPE_BADGE_CLASS = {
    dateOnOrAfter:  'rule-badge rule-badge-green',
    dateAfter:      'rule-badge rule-badge-green',
    dateOnOrBefore: 'rule-badge rule-badge-orange',
    dateBefore:     'rule-badge rule-badge-orange',
    greaterOrEqual: 'rule-badge rule-badge-blue',
    greaterThan:    'rule-badge rule-badge-blue',
    lessOrEqual:    'rule-badge rule-badge-purple',
    lessThan:       'rule-badge rule-badge-purple'
};

export default class FormCrossFieldRuleInline extends LightningElement {
    @api rules = [];
    @api questionId;
    @api questionType;
    @api allQuestions = [];

    @track showAddForm = false;
    @track editingRuleId = null;
    @track newRule = { type: '', refQuestionId: '', message: '' };

    get addButtonIcon() {
        return this.showAddForm ? 'utility:dash' : 'utility:add';
    }

    get saveButtonLabel() {
        return this.editingRuleId ? 'Update' : 'Save';
    }

    get ruleTypeOptions() {
        return RULE_TYPES_BY_QUESTION_TYPE[this.questionType] || [];
    }

    get compatibleQuestions() {
        if (!this.allQuestions) return [];
        return this.allQuestions
            .filter(q => q.value !== this.questionId && q.type === this.questionType)
            .map(q => ({ label: q.label, value: q.value }));
    }

    get isRefQuestionDisabled() {
        return !this.newRule.type;
    }

    get enrichedRules() {
        return (this.rules || []).map(rule => {
            const refQ = (this.allQuestions || []).find(q => q.value === rule.refQuestionId);
            return {
                ...rule,
                badgeClass: RULE_TYPE_BADGE_CLASS[rule.type] || 'rule-badge rule-badge-green',
                typeLabel: RULE_TYPE_LABELS[rule.type] || rule.type,
                refQuestionLabel: refQ ? refQ.label : rule.refQuestionId,
                messageShort: rule.message && rule.message.length > 55
                    ? rule.message.substring(0, 52) + '...'
                    : rule.message
            };
        });
    }

    get hasRules() {
        return this.enrichedRules.length > 0;
    }

    get supportsCrossFieldRules() {
        return !!RULE_TYPES_BY_QUESTION_TYPE[this.questionType];
    }

    handleToggleAdd() {
        this.showAddForm = !this.showAddForm;
        if (!this.showAddForm) {
            this._resetForm();
        }
    }

    handleEditRule(event) {
        const ruleId = event.currentTarget.dataset.id;
        const rule = (this.rules || []).find(r => r.id === ruleId);
        if (!rule) return;

        this.editingRuleId = ruleId;
        this.newRule = { type: rule.type, refQuestionId: rule.refQuestionId, message: rule.message };
        this.showAddForm = true;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.newRule = { ...this.newRule, [field]: event.detail.value };

        if (field === 'type') {
            this.newRule = { ...this.newRule, refQuestionId: '' };
        }
    }

    handleSave() {
        const { type, refQuestionId, message } = this.newRule;

        if (!type || !refQuestionId || !message || !message.trim()) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Incomplete Rule',
                message: 'Please fill in all three fields: Rule Type, Compare to Question, and Error Message.',
                variant: 'warning'
            }));
            return;
        }

        if (refQuestionId === this.questionId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid Rule',
                message: 'A question cannot reference itself.',
                variant: 'error'
            }));
            return;
        }

        const existingRules = Array.isArray(this.rules) ? [...this.rules] : [];

        const duplicate = existingRules.find(r =>
            r.type === type && r.refQuestionId === refQuestionId && r.id !== this.editingRuleId
        );
        if (duplicate) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Duplicate Rule',
                message: 'A rule with the same type and referenced question already exists.',
                variant: 'warning'
            }));
            return;
        }

        let updatedRules;
        if (this.editingRuleId) {
            updatedRules = existingRules.map(r =>
                r.id === this.editingRuleId ? { ...r, type, refQuestionId, message: message.trim() } : r
            );
        } else {
            const newId = 'rule_' + Date.now();
            updatedRules = [...existingRules, { id: newId, type, refQuestionId, message: message.trim() }];
        }

        this._fireRulesChange(updatedRules);
        this.showAddForm = false;
        this._resetForm();
    }

    handleDelete(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.id;
        const updatedRules = (this.rules || []).filter(r => r.id !== ruleId);
        this._fireRulesChange(updatedRules);
    }

    handleCancel() {
        this.showAddForm = false;
        this._resetForm();
    }

    _resetForm() {
        this.editingRuleId = null;
        this.newRule = { type: '', refQuestionId: '', message: '' };
    }

    _fireRulesChange(rules) {
        this.dispatchEvent(new CustomEvent('ruleschange', {
            detail: { rules },
            bubbles: true,
            composed: true
        }));
    }
}

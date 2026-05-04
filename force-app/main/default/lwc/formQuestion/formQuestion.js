/**
 * @description       : Question renderer supporting all 9 question types
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   01-04-2026   Tom De Backer       Added disabled state support
 * 1.2   01-04-2026   Tom De Backer       Added word count support
 * 1.3   06-04-2026   KDO-2643            Character countdown (separate from word counter)
 * ------------------------------------------------------------
**/
import { LightningElement, api, track } from 'lwc';
import {
    characterCount,
    nativeMaxlengthFromCharLimit,
    parseCharMaxLength
} from 'c/formCharCountUtil';
import { countWords, maxWordsExceededMessage } from 'c/formWordCountUtil';

const PULSE_MS = 320;
/** Shown as inline SLDS help only (never via setCustomValidity — avoids browser/Lightning popups). */
const REQUIRED_VALUE_MISSING_MESSAGE = 'Complete this field.';

export default class FormQuestion extends LightningElement {
    @api question;
    @api sectionId;
    @api readOnly = false;
    /** Feature toggles from FeatureSettingsService (passed by formRenderer). */
    @api featureSettings;

    @track _longTextLive;
    @track _charCountdownShortTextLive;
    @track _pulseClass = '';
    @track _longTextTouched = false;
    _renderedQuestionId;
    _lastWordCountForPulse = null;
    _pulseTimer;

    renderedCallback() {
        const id = this.question?.questionId;
        if (id !== this._renderedQuestionId) {
            this._renderedQuestionId = id;
            this._longTextLive = undefined;
            this._charCountdownShortTextLive = undefined;
            this._lastWordCountForPulse = null;
            if (this._pulseTimer) {
                window.clearTimeout(this._pulseTimer);
                this._pulseTimer = null;
            }
            this._pulseClass = '';
            this._longTextTouched = false;
        }
    }

    get isDisabled() {
        return (
            this.readOnly === true ||
            this.readOnly === 'true' ||
            this.question?.isDisabled === true
        );
    }

    get isShortText() {
        return this.question?.questionType === 'Text';
    }

    get isLongText() {
        return this.question?.questionType === 'Long Text';
    }

    get isTextQuestion() {
        return this.isShortText || this.isLongText;
    }

    get isNumberQuestion() {
        return this.question?.questionType === 'Number';
    }

    get normalizedDecimalPlaces() {
        const n = this.question?.numberDecimalPlaces;
        if (n == null || n === '') return null;
        const num = Number(n);
        if (!Number.isFinite(num)) return null;
        return Math.max(0, Math.min(10, Math.floor(num)));
    }

    get numberStep() {
        const places = this.normalizedDecimalPlaces;
        if (places == null || places === 0) return '1';
        const inv = Math.pow(10, -places);
        return inv >= 0.0001 ? String(inv) : inv.toFixed(places);
    }

    get crossFieldErrorMessage() {
        const m = this.question?.crossFieldError;
        if (m == null) return '';
        const s = String(m).trim();
        return s || '';
    }

    get placeholder() {
        return this.question?.placeholder || '';
    }

    get maxLength() {
        return this.question?.maxLength || undefined;
    }

    get nativeTextareaMaxlength() {
        const m = this.question?.maxLength;
        if (m == null || m === '') return undefined;
        const n = Number(m);
        if (!Number.isFinite(n) || n <= 0) return undefined;
        return Math.floor(n);
    }

    get effectiveMaxWordCount() {
        const n = Number(this.question?.maxWordCount);
        if (!Number.isFinite(n) || n <= 0) return 0;
        return Math.floor(n);
    }

    get showWordCounter() {
        return this.isLongText && this.effectiveMaxWordCount > 0;
    }

    get showCharacterCountdownFeature() {
        return this.featureSettings?.characterCountdown === true;
    }

    get effectiveCharMaxLengthInt() {
        return parseCharMaxLength(this.question?.maxLength);
    }

    get showCharCountdownShortText() {
        return (
            this.isShortText &&
            this.showCharacterCountdownFeature &&
            this.effectiveCharMaxLengthInt > 0
        );
    }

    /** Native textarea when word counter and/or character countdown needs live updates. */
    get useNativeLongTextEditor() {
        if (!this.isLongText) {
            return false;
        }
        return (
            this.showWordCounter ||
            (this.showCharacterCountdownFeature && this.effectiveCharMaxLengthInt > 0)
        );
    }

    /** Long text footer: character count (separate `if` from word counter in template). */
    get showLongTextCharCountdownFooter() {
        return (
            this.isLongText &&
            this.showCharacterCountdownFeature &&
            this.effectiveCharMaxLengthInt > 0
        );
    }

    get charCountdownShortDisplayValue() {
        if (
            this._charCountdownShortTextLive !== undefined &&
            this._charCountdownShortTextLive !== null
        ) {
            return this._charCountdownShortTextLive;
        }
        return this.question?.textValue ?? '';
    }

    get charCountdownShortCurrentLength() {
        return characterCount(this.charCountdownShortDisplayValue);
    }

    get charCountdownMaxDisplay() {
        return this.effectiveCharMaxLengthInt;
    }

    get charCountdownTextareaMaxlength() {
        return nativeMaxlengthFromCharLimit(this.question?.maxLength);
    }

    get charCountdownLongCurrentLength() {
        return characterCount(this.longTextDisplayValue);
    }

    get longTextDisplayValue() {
        if (this._longTextLive !== undefined && this._longTextLive !== null) {
            return this._longTextLive;
        }
        return this.question?.textValue ?? '';
    }

    get currentWordCount() {
        return countWords(this.longTextDisplayValue);
    }

    get maxWordCountDisplay() {
        return this.effectiveMaxWordCount;
    }

    get wordCounterOverLimit() {
        return this.effectiveMaxWordCount > 0 && this.currentWordCount > this.effectiveMaxWordCount;
    }

    /** Same pattern as cross-field errors: slds-form-element__help under the control. */
    get wordLimitErrorMessage() {
        if (!this.isLongText || !this.showWordCounter || !this.wordCounterOverLimit) {
            return '';
        }
        return maxWordsExceededMessage(this.effectiveMaxWordCount);
    }

    get longTextValueTrimmed() {
        if (this.isLongText && this.useNativeLongTextEditor) {
            return String(this.longTextDisplayValue ?? '').trim();
        }
        const tv = this.question?.textValue;
        return String(tv ?? '').trim();
    }

    /** Inline required message (after blur/input/submit validation), no constraint API popup. */
    get longTextRequiredInlineMessage() {
        if (!this.isLongText || this.isDisabled || !this.isRequired) {
            return '';
        }
        if (this.longTextValueTrimmed !== '') {
            return '';
        }
        if (!this._longTextTouched) {
            return '';
        }
        return REQUIRED_VALUE_MISSING_MESSAGE;
    }

    get wordCounterRowClass() {
        const base = 'word-counter-row slds-text-body_small';
        return this.wordCounterOverLimit ? `${base} word-counter-row--error` : `${base} word-counter-row--muted`;
    }

    get wordCounterNumClass() {
        return `word-count-num ${this._pulseClass}`.trim();
    }

    get minValue() {
        return this.question?.minValue != null ? this.question.minValue : undefined;
    }

    get maxValue() {
        return this.question?.maxValue != null ? this.question.maxValue : undefined;
    }

    get validationPattern() {
        return this.question?.validationPattern || undefined;
    }

    get validationMessage() {
        return this.question?.validationMessage || 'Invalid format';
    }

    get isDateQuestion() {
        return this.question?.questionType === 'Date';
    }

    get isCheckboxQuestion() {
        return this.question?.questionType === 'Checkbox';
    }

    get isFileQuestion() {
        return this.question?.questionType === 'File';
    }

    get isTableQuestion() {
        return this.question?.questionType === 'Table';
    }

    get isPicklist() {
        return this.question?.questionType === 'Picklist';
    }

    get isMultiSelect() {
        return this.question?.questionType === 'Multi-Select';
    }

    get multiSelectValue() {
        if (!this.question.value) return [];
        if (Array.isArray(this.question.value)) return this.question.value;
        return String(this.question.value).split(';').filter(v => v);
    }

    get checkboxValue() {
        return this.multiSelectValue;
    }

    get questionLabel() {
        return this.question.questionText || this.question.questionName;
    }

    get helpText() {
        return this.question.helpText;
    }

    get isRequired() {
        return this.question.isRequired === true;
    }

    get requiredValueMissingMessage() {
        return REQUIRED_VALUE_MISSING_MESSAGE;
    }

    get responseOptions() {
        if (!this.question.responses) return [];
        return this.question.responses
            .filter(r => r && (r.responseText || r.responseName) && r.responseId)
            .map(r => ({
                label: String(r.responseText || r.responseName),
                value: String(r.responseId)
            }));
    }

    get checkboxOptions() {
        if (!this.question.responses) return [];
        return this.question.responses
            .filter(r => r && (r.responseText || r.responseName) && r.responseId)
            .map(r => ({
                label: String(r.responseText || r.responseName),
                value: String(r.responseId)
            }));
    }

    _applyCharCountdownNativeValidity(target, value, requiredEmptyCustomValidity) {
        if (this.isDisabled) {
            target.setCustomValidity('');
            return;
        }
        const str = value != null ? String(value) : '';
        const trimmedEmpty = str.trim() === '';
        if (this.isRequired && trimmedEmpty) {
            target.setCustomValidity(requiredEmptyCustomValidity);
            return;
        }
        if (this.validationPattern) {
            const ok = new RegExp(this.validationPattern).test(str);
            target.setCustomValidity(ok ? '' : this.validationMessage);
            return;
        }
        target.setCustomValidity('');
    }

    _applyCharCountdownShortNativeValidity(target, value) {
        this._applyCharCountdownNativeValidity(target, value, REQUIRED_VALUE_MISSING_MESSAGE);
    }

    _applyCharCountdownLongNativeValidity(target, value) {
        this._applyCharCountdownNativeValidity(target, value, '');
    }

    _applyLongTextValidity(target, value) {
        if (this.isDisabled) {
            target.setCustomValidity('');
            return;
        }
        const v = value != null ? value : target.value;
        const str = v == null ? '' : String(v);
        const trimmedEmpty = str.trim() === '';

        if (this.isRequired && trimmedEmpty) {
            target.setCustomValidity('');
            return;
        }

        const max = this.effectiveMaxWordCount;
        if (max > 0 && countWords(str) > max) {
            target.setCustomValidity('');
            return;
        }
        if (this.validationPattern) {
            const ok = new RegExp(this.validationPattern).test(str);
            target.setCustomValidity(ok ? '' : this.validationMessage);
            return;
        }
        target.setCustomValidity('');
    }

    _triggerCountPulse(newCount) {
        if (this._lastWordCountForPulse === null) {
            this._lastWordCountForPulse = newCount;
            return;
        }
        if (this._lastWordCountForPulse === newCount) return;
        this._lastWordCountForPulse = newCount;
        if (this._pulseTimer) {
            window.clearTimeout(this._pulseTimer);
            this._pulseTimer = null;
        }
        this._pulseClass = '';
        window.requestAnimationFrame(() => {
            this._pulseClass = 'word-count-num--pulse';
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._pulseTimer = window.setTimeout(() => {
                this._pulseClass = '';
                this._pulseTimer = null;
            }, PULSE_MS);
        });
    }

    handlePicklistChange(event) {
        const selectedValue = event.detail.value;
        const selectedResponse = this.question.responses.find(r => String(r.responseId) === String(selectedValue));
        this.dispatchValueChange(selectedValue, selectedResponse ? selectedResponse.responseText : '');
    }

    handleMultiSelectChange(event) {
        const selectedValues = event.detail.value;
        this.dispatchValueChange(selectedValues.join(';'), selectedValues.join(';'));
    }

    handleCheckboxChange(event) {
        const selectedValues = event.detail.value;
        this.dispatchValueChange(selectedValues.join(';'), selectedValues.join(';'));
    }

    handleTextChange(event) {
        this.dispatchValueChange(null, event.detail.value);
    }

    handleCharCountdownShortInput(event) {
        const value = event.target.value;
        this._charCountdownShortTextLive = value;
        this._applyCharCountdownShortNativeValidity(event.target, value);
        event.target.reportValidity();
        this.dispatchValueChange(null, value);
    }

    handleCharCountdownShortBlur(event) {
        this._applyCharCountdownShortNativeValidity(event.target, event.target.value);
        event.target.reportValidity();
    }

    handleLongTextChange(event) {
        this._longTextTouched = true;
        const value = event.detail.value;
        this.dispatchValueChange(null, value);
    }

    handleLongTextNativeInput(event) {
        this._longTextTouched = true;
        const value = event.target.value;
        this._longTextLive = value;
        if (this.showWordCounter) {
            const wc = countWords(value);
            this._triggerCountPulse(wc);
            this._applyLongTextValidity(event.target, value);
        } else {
            this._applyCharCountdownLongNativeValidity(event.target, value);
        }
        event.target.reportValidity();
        this.dispatchValueChange(null, value);
    }

    handleLongTextNativeBlur(event) {
        this._longTextTouched = true;
        if (this.showWordCounter) {
            this._applyLongTextValidity(event.target, event.target.value);
        } else {
            this._applyCharCountdownLongNativeValidity(event.target, event.target.value);
        }
        event.target.reportValidity();
    }

    handleLongTextBlur(event) {
        this._longTextTouched = true;
        const value = event.target.value;
        this._applyLongTextValidity(event.target, value);
        event.target.reportValidity();
    }

    handleNumberChange(event) {
        let raw = event.detail.value;
        const places = this.normalizedDecimalPlaces;
        if (places != null && raw != null && raw !== '') {
            const n = parseFloat(raw);
            if (Number.isFinite(n)) {
                if (places === 0) {
                    raw = String(Math.round(n));
                } else {
                    const factor = Math.pow(10, places);
                    raw = String(Math.round(n * factor) / factor);
                }
            }
        }
        this.dispatchValueChange(null, raw);
    }

    handleDateChange(event) {
        this.dispatchValueChange(null, event.detail.value);
    }

    handleTableChange(event) {
        const tableData = event.detail.rows;
        this.dispatchValueChange(null, JSON.stringify(tableData));
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (files && files.length > 0) {
            const fileNames = Array.from(files).map(f => f.name).join('; ');
            this.dispatchValueChange(null, fileNames);
        }
    }

    /**
     * Re-run Long Text validity and show native / base-component validity (used before submit).
     */
    @api
    reportInputValidity() {
        if (this.isShortText) {
            const shortNative = this.template.querySelector('input.char-countdown-short-native');
            if (shortNative) {
                this._applyCharCountdownShortNativeValidity(shortNative, shortNative.value);
                if (typeof shortNative.reportValidity === 'function') {
                    shortNative.reportValidity();
                }
                return;
            }
        }
        if (!this.isLongText) {
            return;
        }
        this._longTextTouched = true;
        const nativeLong = this.template.querySelector('textarea.long-text-native');
        if (nativeLong) {
            const v = nativeLong.value;
            if (this.showWordCounter) {
                this._applyLongTextValidity(nativeLong, v);
            } else {
                this._applyCharCountdownLongNativeValidity(nativeLong, v);
            }
            if (typeof nativeLong.reportValidity === 'function') {
                nativeLong.reportValidity();
            }
            return;
        }
        const lt = this.template.querySelector('lightning-textarea');
        if (lt) {
            const v = this.question?.textValue ?? '';
            this._applyLongTextValidity(lt, v);
            if (typeof lt.reportValidity === 'function') {
                lt.reportValidity();
            }
        }
    }

    dispatchValueChange(value, textValue) {
        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    sectionId: this.sectionId,
                    questionId: this.question.questionId,
                    value: value,
                    textValue: textValue
                },
                bubbles: true,
                composed: true
            })
        );
    }
}
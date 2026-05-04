/**
 * @description       : Interactive column builder for Table-type questions
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

export default class FormTableColumnBuilder extends LightningElement {
    @track columnList = [];
    _columnsValue;

    @api
    get columns() {
        return this._columnsValue;
    }
    set columns(value) {
        this._columnsValue = value;
        this.parseColumns(value);
    }

    parseColumns(value) {
        if (!value) {
            this.columnList = [];
            return;
        }

        try {
            const parsed = JSON.parse(value);
            if (Array.isArray(parsed)) {
                this.columnList = parsed.map((item, idx) => ({
                    id: idx,
                    name: item.label || item.name || item,
                    isFirst: idx === 0,
                    isLast: idx === parsed.length - 1
                }));
                return;
            }
        } catch (e) {
            // Not JSON — fall through to comma-separated
        }

        const names = value.split(',').map(n => n.trim()).filter(n => n);
        this.columnList = names.map((name, idx) => ({
            id: idx,
            name,
            isFirst: idx === 0,
            isLast: idx === names.length - 1
        }));
    }

    get hasColumns() {
        return this.columnList.length > 0;
    }

    handleNameChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const updated = this.columnList.map((col, i) => {
            if (i === idx) {
                return { ...col, name: event.target.value };
            }
            return col;
        });
        this.columnList = this.refreshFlags(updated);
        this.fireChange();
    }

    handleAdd() {
        const newCol = { id: Date.now(), name: '', isFirst: false, isLast: true };
        const updated = [...this.columnList, newCol];
        this.columnList = this.refreshFlags(updated);

        // Focus the new input after render
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const inputs = this.template.querySelectorAll('[data-index]');
            if (inputs.length > 0) {
                inputs[inputs.length - 1].focus();
            }
        }, 100);

        this.fireChange();
    }

    handleRemove(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const updated = this.columnList.filter((_, i) => i !== idx);
        this.columnList = this.refreshFlags(updated);
        this.fireChange();
    }

    handleMoveUp(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        if (idx === 0) return;
        const updated = [...this.columnList];
        [updated[idx - 1], updated[idx]] = [updated[idx], updated[idx - 1]];
        this.columnList = this.refreshFlags(updated);
        this.fireChange();
    }

    handleMoveDown(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        if (idx >= this.columnList.length - 1) return;
        const updated = [...this.columnList];
        [updated[idx], updated[idx + 1]] = [updated[idx + 1], updated[idx]];
        this.columnList = this.refreshFlags(updated);
        this.fireChange();
    }

    refreshFlags(list) {
        return list.map((col, idx) => ({
            ...col,
            id: idx,
            isFirst: idx === 0,
            isLast: idx === list.length - 1
        }));
    }

    fireChange() {
        const csv = this.columnList.map(c => c.name).join(',');
        this.dispatchEvent(new CustomEvent('columnschange', {
            detail: { value: csv }
        }));
    }
}

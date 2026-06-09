/**
 * @description       : Editable table input component for table-type questions
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

export default class FormQuestionTable extends LightningElement {
    @api label = 'Table Input';
    @api columnConfig = '[{"label":"Column 1","fieldName":"col1"},{"label":"Column 2","fieldName":"col2"}]';
    @api initialData;
    @api disabled = false;
    
    @track rows = [];
    rowCounter = 0;

    get columns() {
        if (!this.columnConfig) {
            return [{ label: 'Column 1', fieldName: 'col1' }, { label: 'Column 2', fieldName: 'col2' }];
        }
        if (typeof this.columnConfig === 'object') {
            return Array.isArray(this.columnConfig) ? this.columnConfig : [this.columnConfig];
        }
        
        // Try JSON format first
        try {
            const parsed = JSON.parse(this.columnConfig);
            if (Array.isArray(parsed)) {
                return parsed;
            }
        } catch (e) {
            // Not JSON, continue to comma-separated parsing
        }
        
        // Handle comma-separated format: "Column1,Column2,Column3"
        const columnNames = this.columnConfig.split(',').map(col => col.trim());
        return columnNames.map((name, index) => ({
            label: name,
            fieldName: 'col' + index
        }));
    }

    get tableData() {
        return this.rows.map(row => ({
            rowId: row.id,
            cells: this.columns.map(col => ({
                key: `${row.id}-${col.fieldName}`,
                fieldName: col.fieldName,
                value: row[col.fieldName] || ''
            }))
        }));
    }

    connectedCallback() {
        if (this.initialData) {
            try {
                const parsed = JSON.parse(this.initialData);
                if (Array.isArray(parsed) && parsed.length > 0) {
                    this.rows = parsed.map((row, idx) => {
                        this.rowCounter = idx + 1;
                        return { ...row, id: this.rowCounter };
                    });
                    return;
                }
            } catch (e) {
                // fall through to default
            }
        }
        if (this.rows.length === 0) {
            this.addRow();
        }
    }

    addRow() {
        if (this.disabled === true || this.disabled === 'true') return;
        this.rowCounter++;
        const newRow = { id: this.rowCounter };
        this.columns.forEach(col => {
            newRow[col.fieldName] = '';
        });
        this.rows = [...this.rows, newRow];
        this.fireChangeEvent();
    }

    removeRow(event) {
        if (this.disabled === true || this.disabled === 'true') return;
        const rowId = parseInt(event.target.dataset.rowId, 10);
        this.rows = this.rows.filter(row => row.id !== rowId);
        this.fireChangeEvent();
    }

    handleCellChange(event) {
        if (this.disabled === true || this.disabled === 'true') return;
        const rowId = parseInt(event.target.dataset.rowId, 10);
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        this.rows = this.rows.map(row => {
            if (row.id === rowId) {
                return { ...row, [field]: value };
            }
            return row;
        });
        
        this.fireChangeEvent();
    }

    fireChangeEvent() {
        this.dispatchEvent(new CustomEvent('tablechange', {
            detail: { rows: this.rows }
        }));
    }

    @api
    getValue() {
        return this.rows;
    }
}
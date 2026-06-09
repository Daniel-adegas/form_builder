/**
 * Table questions persist row JSON in textValue (see formQuestion.handleTableChange).
 * Required validation must treat whitespace-only cells and default empty rows as "no answer".
 *
 * Cell keys must match formQuestionTable column fieldNames (C_Table_Columns__c / column-config).
 * Relying on a fixed list of "metadata" keys is unsafe: real columns can be named rowId, rowIndex,
 * numeric keys, etc., and future row metadata would falsely satisfy "required".
 */

/**
 * Resolve column definitions the same way as formQuestionTable "columns" getter.
 * @param {unknown} columnConfig
 * @returns {Array<{ label?: string, fieldName?: string }>}
 */
function resolveTableColumns(columnConfig) {
  if (!columnConfig) {
    return [
      { label: "Column 1", fieldName: "col1" },
      { label: "Column 2", fieldName: "col2" }
    ];
  }
  if (typeof columnConfig === "object") {
    return Array.isArray(columnConfig) ? columnConfig : [columnConfig];
  }

  try {
    const parsed = JSON.parse(columnConfig);
    if (Array.isArray(parsed)) {
      return parsed;
    }
  } catch {
    // Not JSON — comma-separated labels (form builder CSV)
  }

  const columnNames = String(columnConfig)
    .split(",")
    .map((col) => col.trim());
  return columnNames.map((name, index) => ({
    label: name,
    fieldName: "col" + index
  }));
}

/**
 * Keys on each row object that correspond to user-editable cells (matches formQuestionTable addRow).
 * @param {unknown} columnConfig
 * @returns {string[]}
 */
function tableRowAnswerKeys(columnConfig) {
  const columns = resolveTableColumns(columnConfig);
  return columns.map((col) => {
    if (
      col.fieldName !== undefined &&
      col.fieldName !== null &&
      col.fieldName !== ""
    ) {
      return String(col.fieldName);
    }
    // formQuestionTable: newRow[col.fieldName] with missing fieldName → key "undefined"
    return "undefined";
  });
}

/**
 * @param {string|null|undefined} textValue — JSON.stringify(rows) from formQuestionTable
 * @param {unknown} [columnConfig] — question.tableColumns / C_Table_Columns__c (optional; default columns if omitted/falsy)
 */
export function tableQuestionHasAnswer(textValue, columnConfig) {
  if (textValue == null) {
    return false;
  }
  const t = String(textValue).trim();
  if (t === "" || t === "[]" || t === "{}") {
    return false;
  }
  const answerKeys = tableRowAnswerKeys(columnConfig);
  try {
    const parsed = JSON.parse(t);
    if (!Array.isArray(parsed) || parsed.length === 0) {
      return false;
    }
    return parsed.some((row) => {
      if (!row || typeof row !== "object") {
        return false;
      }
      return answerKeys.some((key) => {
        if (!Object.prototype.hasOwnProperty.call(row, key)) {
          return false;
        }
        const cell = row[key];
        return String(cell ?? "").trim() !== "";
      });
    });
  } catch {
    return t !== "";
  }
}

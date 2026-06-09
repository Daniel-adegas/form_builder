/**
 * Table questions persist row JSON in textValue (see formQuestion.handleTableChange).
 * Required validation must treat whitespace-only cells and default empty rows as "no answer".
 */
export function tableQuestionHasAnswer(textValue) {
    if (textValue == null) {
        return false;
    }
    const t = String(textValue).trim();
    if (t === '' || t === '[]' || t === '{}') {
        return false;
    }
    try {
        const parsed = JSON.parse(t);
        if (!Array.isArray(parsed) || parsed.length === 0) {
            return false;
        }
        return parsed.some((row) => {
            if (!row || typeof row !== 'object') {
                return false;
            }
            return Object.entries(row).some(([key, cell]) => {
                if (key === 'id' || key === 'rowId') {
                    return false;
                }
                return String(cell ?? '').trim() !== '';
            });
        });
    } catch (e) {
        return t !== '';
    }
}

/**
 * Shared word counting and default validation copy for Long Text max word count.
 */
export function countWords(text) {
    if (text == null || text === '') {
        return 0;
    }
    const m = String(text).trim().match(/\S+/g);
    return m ? m.length : 0;
}

export function maxWordsExceededMessage(maxWords) {
    const n = Number(maxWords);
    if (!Number.isFinite(n) || n <= 0) {
        return 'Maximum word count exceeded.';
    }
    return `Maximum ${Math.floor(n)} words allowed.`;
}

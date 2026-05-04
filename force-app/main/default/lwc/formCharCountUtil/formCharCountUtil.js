/**
 * Shared character counting and max-length parsing for Text / Long Text character countdown.
 */
export function characterCount(text) {
    if (text == null) {
        return 0;
    }
    return String(text).length;
}

export function parseCharMaxLength(maxLength) {
    const m = maxLength;
    if (m == null || m === '') {
        return 0;
    }
    const n = Number(m);
    if (!Number.isFinite(n) || n <= 0) {
        return 0;
    }
    return Math.floor(n);
}

export function nativeMaxlengthFromCharLimit(maxLength) {
    const n = parseCharMaxLength(maxLength);
    return n > 0 ? n : undefined;
}

/**
 * Shared drag/drop helpers for form builder canvas LWCs.
 */
export function isDropCompatible(accepts, dragItemType) {
    if (!accepts || !dragItemType) {
        return true;
    }
    return accepts.split(',').map(s => s.trim()).includes(dragItemType);
}

export function buildDropZoneClass({ isDragging, dragItemType, accepts, isDragOver, alwaysExpanded }) {
    let cls = 'drop-zone';
    if (alwaysExpanded || (isDragging && isDropCompatible(accepts, dragItemType))) {
        cls += ' drop-zone-active';
    }
    if (isDragOver) {
        cls += ' drag-over';
    }
    return cls;
}

export function buildEmptyDropClass({ isDragging, dragItemType, accepts, isDragOver }) {
    let cls = 'empty-section-drop';
    if (isDragging && isDropCompatible(accepts, dragItemType)) {
        cls += ' drop-zone-active';
    }
    if (isDragOver) {
        cls += ' drag-over';
    }
    return cls;
}

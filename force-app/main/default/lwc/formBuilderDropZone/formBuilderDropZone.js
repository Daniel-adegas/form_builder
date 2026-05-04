import { LightningElement, api, track } from 'lwc';
import { isDropCompatible, buildDropZoneClass, buildEmptyDropClass } from 'c/formBuilderDragUtil';

export default class FormBuilderDropZone extends LightningElement {
    @api dropzone;
    @api accepts;
    /** @type {string|undefined} */
    @api parentId;
    @api position = 0;
    @api isDragging = false;
    @api dragItemType = '';
    @api dragType = '';
    /** When true, line drop zone always uses expanded (active) height like the top-of-canvas slot */
    @api alwaysExpanded = false;
    /** 'line' | 'empty' */
    @api variant = 'line';
    /** Shown inside line zone when isDragging and label set */
    @api dragLabel = '';

    @track isDragOver = false;

    get isLine() {
        return this.variant === 'line';
    }

    get isEmpty() {
        return this.variant === 'empty';
    }

    get lineClass() {
        return buildDropZoneClass({
            isDragging: this.isDragging,
            dragItemType: this.dragItemType,
            accepts: this.accepts,
            isDragOver: this.isDragOver,
            alwaysExpanded: this.alwaysExpanded
        });
    }

    get emptyClass() {
        return buildEmptyDropClass({
            isDragging: this.isDragging,
            dragItemType: this.dragItemType,
            accepts: this.accepts,
            isDragOver: this.isDragOver
        });
    }

    get showInnerLabel() {
        return this.variant === 'line' && this.isDragging && this.dragLabel;
    }

    get positionNum() {
        const p = this.position;
        return typeof p === 'number' ? p : parseInt(String(p), 10) || 0;
    }

    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        if (!isDropCompatible(this.accepts, this.dragItemType)) {
            event.dataTransfer.dropEffect = 'none';
            return;
        }
        event.dataTransfer.dropEffect = this.dragType === 'reorder' ? 'move' : 'copy';
        this.isDragOver = true;
    }

    handleDragLeave() {
        this.isDragOver = false;
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragOver = false;
        let data;
        try {
            data = JSON.parse(event.dataTransfer.getData('text/plain'));
        } catch {
            return;
        }
        this.dispatchEvent(
            new CustomEvent('builderdrop', {
                detail: {
                    data,
                    dropzone: this.dropzone,
                    parentId: this.parentId,
                    position: this.positionNum,
                    accepts: this.accepts
                },
                bubbles: true,
                composed: true
            })
        );
    }
}

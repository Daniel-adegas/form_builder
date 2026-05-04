import { LightningElement, api } from 'lwc';

export default class FormBuilderPageCard extends LightningElement {
    @api page;
    /** 'category' | 'rootPages' */
    @api pageDropzone;
    @api pageDropParentId;
    @api isDragging = false;
    @api dragItemType = '';
    @api dragType = '';
    @api draggingSourceId;
    @api showScoring = false;
    @api suppressRepositoryChrome = false;

    get pageHeaderClass() {
        let cls = 'canvas-page-header';
        if (this.draggingSourceId === this.page?.Id) {
            cls += ' is-dragging-source';
        }
        return cls;
    }

    handleDragStart(event) {
        event.stopPropagation();
        const itemType = event.currentTarget.dataset.itemtype;
        const itemId = event.currentTarget.dataset.id;
        const parentId = event.currentTarget.dataset.parentid || '';
        event.dataTransfer.setData(
            'text/plain',
            JSON.stringify({
                dragType: 'reorder',
                itemType,
                itemId,
                parentId,
                source: 'canvas'
            })
        );
        event.dataTransfer.effectAllowed = 'move';
        this.dispatchEvent(
            new CustomEvent('builderdragstart', {
                detail: { itemType, itemId, parentId },
                bubbles: true,
                composed: true
            })
        );
    }

    handleDragEnd() {
        this.dispatchEvent(new CustomEvent('builderdragend', { bubbles: true, composed: true }));
    }

    handleElementClick(event) {
        event.stopPropagation();
        this.dispatchEvent(
            new CustomEvent('builderelementclick', {
                detail: {
                    elementType: event.currentTarget.dataset.elementtype,
                    elementId: event.currentTarget.dataset.id
                },
                bubbles: true,
                composed: true
            })
        );
    }

    handleToggleCollapse(event) {
        event.stopPropagation();
        this.dispatchEvent(
            new CustomEvent('buildertogglecollapse', {
                detail: { id: event.currentTarget.dataset.id },
                bubbles: true,
                composed: true
            })
        );
    }

    handleQuickAddSection(event) {
        event.stopPropagation();
        this.dispatchEvent(
            new CustomEvent('builderquickaddsection', {
                detail: { pageId: event.currentTarget.dataset.pageid },
                bubbles: true,
                composed: true
            })
        );
    }
}

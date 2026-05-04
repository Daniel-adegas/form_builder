import { LightningElement, api } from 'lwc';

export default class FormBuilderSectionCard extends LightningElement {
    @api section;
    @api pageId;
    @api isDragging = false;
    @api dragItemType = '';
    @api dragType = '';
    @api draggingSourceId;
    @api showScoring = false;
    @api suppressRepositoryChrome = false;

    get sectionHeaderClass() {
        let cls = 'canvas-section-header';
        if (this.draggingSourceId === this.section?.Id) {
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

    handleQuickAddQuestion(event) {
        event.stopPropagation();
        this.dispatchEvent(
            new CustomEvent('builderquickaddquestion', {
                detail: { sectionId: event.currentTarget.dataset.sectionid },
                bubbles: true,
                composed: true
            })
        );
    }
}

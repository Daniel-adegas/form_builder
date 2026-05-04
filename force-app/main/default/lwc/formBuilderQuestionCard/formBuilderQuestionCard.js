import { LightningElement, api } from 'lwc';

export default class FormBuilderQuestionCard extends LightningElement {
    @api question;
    @api sectionId;
    @api isDragging = false;
    @api dragItemType = '';
    @api dragType = '';
    @api draggingSourceId;
    @api showScoring = false;
    @api suppressRepositoryChrome = false;

    get isDraggingSource() {
        return this.draggingSourceId === this.question?.Id;
    }

    get questionHeaderClass() {
        let cls = this.question?.cssClass || 'canvas-question';
        if (this.isDraggingSource) {
            cls += ' is-dragging-source';
        }
        return cls;
    }

    get responsesForTemplate() {
        const list = this.question?.responses || [];
        return list.map(r => {
            let cls = r.cssClass || 'canvas-response';
            if (this.draggingSourceId === r.Id) {
                cls += ' is-dragging-source';
            }
            return { ...r, rowClass: cls };
        });
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

    handleQuickAddResponse(event) {
        event.stopPropagation();
        this.dispatchEvent(
            new CustomEvent('builderquickaddresponse', {
                detail: { questionId: event.currentTarget.dataset.questionid },
                bubbles: true,
                composed: true
            })
        );
    }

    handleResponseDragStart(event) {
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
}

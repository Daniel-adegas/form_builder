import { createElement } from '@lwc/engine-dom';
import FormRendererLayoutConversational from 'c/formRendererLayoutConversational';

function buildSections(questionIds) {
    return [
        {
            sectionId: 'sec-1',
            translatedName: 'Section A',
            visibleQuestions: questionIds.map((questionId) => ({
                questionId,
                questionLayoutClass: 'slds-col slds-size_1-of-1',
                questionType: 'Text',
                questionText: `Question ${questionId}`,
                textValue: ''
            }))
        }
    ];
}

async function flushPromises(times = 1) {
    for (let i = 0; i < times; i += 1) {
        await Promise.resolve();
    }
}

function primaryActionButton(element) {
    const buttons = [...element.shadowRoot.querySelectorAll('lightning-button')];
    expect(buttons.length).toBeGreaterThanOrEqual(2);
    return buttons[1];
}

describe('c-form-renderer-layout-conversational', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('after being on the last question of page 1, switching currentPage resets to the first question and primary is OK until the real last question', async () => {
        const element = createElement('c-form-renderer-layout-conversational', {
            is: FormRendererLayoutConversational
        });

        element.currentPage = { pageId: 'page-1' };
        element.currentSections = buildSections(['p1-q1', 'p1-q2']);
        element.readOnly = false;
        element.previewMode = false;

        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.counter').textContent).toBe('1 of 2');
        expect(primaryActionButton(element).label).toBe('OK');

        primaryActionButton(element).click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('.counter').textContent).toBe('2 of 2');
        expect(primaryActionButton(element).label).toBe('Submit');

        const finishSpy = jest.fn();
        element.addEventListener('finish', finishSpy);

        element.currentPage = { pageId: 'page-2' };
        element.currentSections = buildSections(['p2-q1', 'p2-q2', 'p2-q3']);
        await flushPromises();

        const formQuestion = element.shadowRoot.querySelector('c-form-question');
        expect(formQuestion.question.questionId).toBe('p2-q1');
        expect(element.shadowRoot.querySelector('.counter').textContent).toBe('1 of 3');
        expect(primaryActionButton(element).label).toBe('OK');

        primaryActionButton(element).click();
        await flushPromises();
        expect(finishSpy).not.toHaveBeenCalled();
        expect(element.shadowRoot.querySelector('.counter').textContent).toBe('2 of 3');

        primaryActionButton(element).click();
        await flushPromises();
        expect(finishSpy).not.toHaveBeenCalled();

        expect(primaryActionButton(element).label).toBe('Submit');
        primaryActionButton(element).click();
        await flushPromises();

        expect(finishSpy).toHaveBeenCalledTimes(1);
    });

    it('blocks finish on the last question when readOnly or previewMode is effective (auto-submit guard)', async () => {
        const element = createElement('c-form-renderer-layout-conversational', {
            is: FormRendererLayoutConversational
        });

        element.currentPage = { pageId: 'page-a' };
        element.currentSections = buildSections(['only-q']);
        element.readOnly = true;
        element.previewMode = false;

        document.body.appendChild(element);
        await flushPromises();

        const finishSpy = jest.fn();
        element.addEventListener('finish', finishSpy);

        expect(primaryActionButton(element).label).toBe('Submit');
        expect(primaryActionButton(element).disabled).toBe(true);

        primaryActionButton(element).click();
        await flushPromises();
        expect(finishSpy).not.toHaveBeenCalled();
    });
});

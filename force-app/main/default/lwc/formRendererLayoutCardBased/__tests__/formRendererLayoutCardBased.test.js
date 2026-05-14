import { createElement } from '@lwc/engine-dom';
import FormRendererLayoutCardBased from 'c/formRendererLayoutCardBased';

function buildMinimalSections(overrides = {}) {
    return [
        {
            sectionId: 'sec-1',
            translatedName: 'Section A',
            bonus: false,
            visibleQuestions: [
                {
                    questionId: 'q-1',
                    questionLayoutClass: 'slds-col slds-size_1-of-1',
                    questionType: 'Text',
                    questionText: 'First question',
                    textValue: '',
                    ...overrides.question
                }
            ],
            ...overrides.section
        }
    ];
}

describe('c-form-renderer-layout-card-based', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders page title, description, section label, and wires c-form-question', async () => {
        const element = createElement('c-form-renderer-layout-card-based', {
            is: FormRendererLayoutCardBased
        });
        element.currentPageName = 'Page One';
        element.currentPageDescription = 'Page subtitle';
        element.currentSections = buildMinimalSections();
        element.readOnly = false;
        element.featureSettings = { someFlag: true };

        document.body.appendChild(element);
        await Promise.resolve();

        const root = element.shadowRoot;
        expect(root.querySelector('.card-layout')).not.toBeNull();

        const title = root.querySelector('.page-header h2');
        expect(title).not.toBeNull();
        expect(title.textContent).toBe('Page One');

        const desc = root.querySelector('.page-description');
        expect(desc).not.toBeNull();
        expect(desc.textContent).toBe('Page subtitle');

        const card = root.querySelector('.question-card');
        expect(card).not.toBeNull();
        expect(card.querySelector('.section-label').textContent).toBe('Section A');

        const formQuestion = root.querySelector('c-form-question');
        expect(formQuestion).not.toBeNull();
        expect(formQuestion.sectionId).toBe('sec-1');
        expect(formQuestion.readOnly).toBe(false);
        expect(formQuestion.featureSettings).toEqual({ someFlag: true });
        expect(formQuestion.question.questionId).toBe('q-1');
        expect(formQuestion.question.sectionName).toBe('Section A');
        expect(formQuestion.question.isBonusSection).toBe(false);
    });

    it('shows bonus badge when section.bonus is true', async () => {
        const element = createElement('c-form-renderer-layout-card-based', {
            is: FormRendererLayoutCardBased
        });
        element.currentPageName = 'P';
        element.currentSections = buildMinimalSections({
            section: { bonus: true }
        });

        document.body.appendChild(element);
        await Promise.resolve();

        const badge = element.shadowRoot.querySelector('.bonus-badge');
        expect(badge).not.toBeNull();
        expect(badge.textContent.trim()).toBe('Bonus');
    });

    it('shows empty state when there are no question cards', async () => {
        const element = createElement('c-form-renderer-layout-card-based', {
            is: FormRendererLayoutCardBased
        });
        element.currentPageName = 'Empty page';
        element.currentSections = [
            {
                sectionId: 'empty-sec',
                translatedName: 'Empty section',
                visibleQuestions: []
            }
        ];

        document.body.appendChild(element);
        await Promise.resolve();

        const empty = element.shadowRoot.querySelector('.empty-state');
        expect(empty).not.toBeNull();
        expect(empty.textContent.trim()).toBe('No questions on this page.');
        expect(element.shadowRoot.querySelector('.question-card-grid')).toBeNull();
    });

    it('re-dispatches valuechange from c-form-question with the same detail (bubbles, composed)', async () => {
        const element = createElement('c-form-renderer-layout-card-based', {
            is: FormRendererLayoutCardBased
        });
        element.currentPageName = 'P';
        element.currentSections = buildMinimalSections();

        const hostListener = jest.fn();
        element.addEventListener('valuechange', hostListener);

        document.body.appendChild(element);
        await Promise.resolve();

        const formQuestion = element.shadowRoot.querySelector('c-form-question');
        expect(formQuestion).not.toBeNull();

        const detail = {
            sectionId: 'sec-1',
            questionId: 'q-1',
            value: 'new-value',
            textValue: 'new text'
        };
        formQuestion.dispatchEvent(
            new CustomEvent('valuechange', {
                detail,
                bubbles: true,
                composed: true
            })
        );

        expect(hostListener).toHaveBeenCalledTimes(1);
        const forwarded = hostListener.mock.calls[0][0];
        expect(forwarded.bubbles).toBe(true);
        expect(forwarded.composed).toBe(true);
        expect(forwarded.detail).toEqual(detail);
    });
});

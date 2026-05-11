import { createElement } from '@lwc/engine-dom';
import FormRendererLayoutWizard from 'c/formRendererLayoutWizard';

function buildProgressSteps() {
    return [
        {
            pageId: 'page-1',
            stepIndex: 1,
            translatedPageName: 'First step'
        },
        {
            pageId: 'page-2',
            stepIndex: 2,
            translatedPageName: 'Second step'
        }
    ];
}

function buildFormStructure(questionOverrides = {}) {
    return [
        {
            pageId: 'page-1',
            sections: [
                {
                    sectionId: 'sec-a',
                    questions: [
                        {
                            questionId: 'q-a1',
                            questionText: 'Question A1',
                            questionType: 'Text',
                            value: '',
                            textValue: ''
                        },
                        {
                            questionId: 'q-a2',
                            questionText: 'Question A2',
                            questionType: 'Text',
                            value: 'answered',
                            textValue: ''
                        },
                        {
                            questionId: 'q-json',
                            questionText: 'JSON picklist',
                            questionType: 'Text',
                            value: '{"x":"y"}',
                            textValue: ''
                        }
                    ]
                }
            ]
        },
        {
            pageId: 'page-2',
            sections: [
                {
                    sectionId: 'sec-b',
                    questions: [
                        {
                            questionId: 'q-b1',
                            questionText: 'Question B1',
                            questionType: 'Text',
                            value: '',
                            textValue: ''
                        }
                    ]
                }
            ]
        }
    ].map(page => ({
        ...page,
        sections: page.sections.map(sec => ({
            ...sec,
            questions: sec.questions.map(q => ({ ...q, ...questionOverrides[q.questionId] }))
        }))
    }));
}

describe('c-form-renderer-layout-wizard', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    describe('hasRealValue', () => {
        let element;

        beforeEach(() => {
            element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            document.body.appendChild(element);
        });

        it('returns false for null, undefined, and blank strings', () => {
            expect(element.hasRealValue(null)).toBe(false);
            expect(element.hasRealValue(undefined)).toBe(false);
            expect(element.hasRealValue('')).toBe(false);
            expect(element.hasRealValue('   ')).toBe(false);
        });

        it('returns false for empty JSON container literals', () => {
            expect(element.hasRealValue('[]')).toBe(false);
            expect(element.hasRealValue('{}')).toBe(false);
            expect(element.hasRealValue('  []  ')).toBe(false);
        });

        it('returns true for ordinary non-empty strings and numeric-ish values', () => {
            expect(element.hasRealValue('hello')).toBe(true);
            expect(element.hasRealValue(0)).toBe(true);
            expect(element.hasRealValue(false)).toBe(true);
        });

        it('treats JSON arrays as answered only when a cell has non-whitespace text', () => {
            expect(element.hasRealValue('[{}]')).toBe(false);
            expect(element.hasRealValue('[{"col":""}]')).toBe(false);
            expect(element.hasRealValue('[{"a":""},{"b":"x"}]')).toBe(true);
        });

        it('treats JSON objects as answered only when a value is non-whitespace', () => {
            expect(element.hasRealValue('{"k":""}')).toBe(false);
            expect(element.hasRealValue('{"k":"v"}')).toBe(true);
        });

        it('returns true for invalid JSON that still has non-empty text after trim', () => {
            expect(element.hasRealValue('[not-json')).toBe(true);
        });

        it('returns consistent results when the same JSON string is evaluated again (memo path)', () => {
            const payload = '[{"id":"1"}]';
            expect(element.hasRealValue(payload)).toBe(true);
            expect(element.hasRealValue(payload)).toBe(true);
        });
    });

    describe('sidebarPages', () => {
        it('returns an empty list when there are no progress steps', () => {
            const element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            element.progressSteps = [];
            element.formStructure = buildFormStructure();
            document.body.appendChild(element);

            expect(element.sidebarPages).toEqual([]);
        });

        it('builds per-step question nav from formStructure and preserves step fields', () => {
            const element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            element.progressSteps = buildProgressSteps();
            element.formStructure = buildFormStructure();
            document.body.appendChild(element);

            const pages = element.sidebarPages;
            expect(pages).toHaveLength(2);

            expect(pages[0].pageId).toBe('page-1');
            expect(pages[0].index).toBe(0);
            expect(pages[0].stepIndex).toBe(1);
            expect(pages[0].translatedPageName).toBe('First step');

            const qIds = pages[0].questions.map(q => q.questionId);
            expect(qIds).toEqual(['q-a1', 'q-a2', 'q-json']);

            expect(pages[0].questions[0].questionText).toBe('Question A1');
            expect(pages[0].questions[0].isAnswered).toBe(false);
            expect(pages[0].questions[1].isAnswered).toBe(true);
            expect(pages[0].questions[2].isAnswered).toBe(true);

            expect(pages[1].questions).toHaveLength(1);
            expect(pages[1].questions[0].isAnswered).toBe(false);
        });

        it('omits sections and questions listed in hiddenElements', () => {
            const element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            element.progressSteps = buildProgressSteps();
            element.formStructure = buildFormStructure();
            element.hiddenElements = { 'sec-a': true };
            document.body.appendChild(element);

            expect(element.sidebarPages[0].questions).toHaveLength(0);

            element.hiddenElements = { 'q-a1': true };
            expect(element.sidebarPages[0].questions.map(q => q.questionId)).toEqual([
                'q-a2',
                'q-json'
            ]);
        });

        it('marks the active question with the highlight itemClass', () => {
            const element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            element.progressSteps = buildProgressSteps();
            element.formStructure = buildFormStructure();
            document.body.appendChild(element);

            element.activeQuestionId = 'q-a2';
            const pages = element.sidebarPages;
            const active = pages[0].questions.find(q => q.questionId === 'q-a2');
            const inactive = pages[0].questions.find(q => q.questionId === 'q-a1');

            expect(active.itemClass).toBe('question-nav-item question-nav-active');
            expect(inactive.itemClass).toBe('question-nav-item');
        });

        it('uses live question data from currentSections when resolving answered state', () => {
            const element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            element.progressSteps = buildProgressSteps();
            element.formStructure = buildFormStructure();
            element.currentSections = [
                {
                    sectionId: 'sec-a',
                    visibleQuestions: [
                        {
                            questionId: 'q-a1',
                            questionType: 'Text',
                            questionText: 'Live Q',
                            value: 'typed-live',
                            textValue: ''
                        }
                    ]
                }
            ];
            document.body.appendChild(element);

            const qNav = element.sidebarPages[0].questions.find(q => q.questionId === 'q-a1');
            expect(qNav.isAnswered).toBe(true);
        });

        it('reflects answerState overrides from user input over static structure values', () => {
            const element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            element.progressSteps = [{ pageId: 'page-1', stepIndex: 1, translatedPageName: 'S' }];
            element.formStructure = buildFormStructure();
            document.body.appendChild(element);

            expect(
                element.sidebarPages[0].questions.find(q => q.questionId === 'q-a2').isAnswered
            ).toBe(true);

            element.answerState = {
                'q-a2': { value: '', textValue: '' }
            };
            expect(
                element.sidebarPages[0].questions.find(q => q.questionId === 'q-a2').isAnswered
            ).toBe(false);
        });

        it('yields no questions for a step whose pageId is missing from formStructure', () => {
            const element = createElement('c-form-renderer-layout-wizard', {
                is: FormRendererLayoutWizard
            });
            element.progressSteps = [
                { pageId: 'unknown-page', stepIndex: 9, translatedPageName: 'Ghost' }
            ];
            element.formStructure = buildFormStructure();
            document.body.appendChild(element);

            expect(element.sidebarPages[0].questions).toEqual([]);
        });
    });
});

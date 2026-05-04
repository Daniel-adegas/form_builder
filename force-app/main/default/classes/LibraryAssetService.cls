/**
 * Question/Section repository: promote form elements to library assets (Library RT on questions/responses;
 * question-only promote uses Form RT on the parent section shell) and inject library clones into forms (Form RT).
 * Omits dependencies, field mappings, and cross-field rules; does not set C_Source_* lookups (snapshot-only clones).
 */
public with sharing class LibraryAssetService {

    private static final String LIBRARY_FORM_NAME = 'Form Builder — Asset Library';
    private static final String LIBRARY_PAGE_NAME = 'Library Root';

    private static Id rtQuestionForm;
    private static Id rtQuestionLibrary;
    private static Id rtResponseForm;
    private static Id rtResponseLibrary;
    private static Id rtSectionForm;
    private static Id rtSectionLibrary;

    private static Id cachedLibraryFormId;
    private static Id cachedLibraryPageId;

    /**
     * Field API names that formTranslationInline saves on C_Question__c only (no page/section).
     * Used to re-anchor legacy section-only rows when the source subtree has exactly one question.
     */
    private static final Set<String> QUESTION_INLINE_TRANSLATION_FIELDS = new Set<String>{
        'C_Question_Text__c',
        'C_Help_Text__c',
        'C_Placeholder__c'
    };

    private static Id questionFormRt() {
        if (rtQuestionForm == null) {
            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form');
            if (rtInfo == null) {
                throw new AuraHandledException('Missing RecordType: C_Question__c.Form');
            }
            rtQuestionForm = rtInfo.getRecordTypeId();
        }
        return rtQuestionForm;
    }

    private static Id questionLibraryRt() {
        if (rtQuestionLibrary == null) {
            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Library');
            if (rtInfo == null) {
                throw new AuraHandledException('Missing RecordType: C_Question__c.Library');
            }
            rtQuestionLibrary = rtInfo.getRecordTypeId();
        }
        return rtQuestionLibrary;
    }

    private static Id responseFormRt() {
        if (rtResponseForm == null) {
            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.C_Response__c.getRecordTypeInfosByDeveloperName().get('Form');
            if (rtInfo == null) {
                throw new AuraHandledException('Missing RecordType: C_Response__c.Form');
            }
            rtResponseForm = rtInfo.getRecordTypeId();
        }
        return rtResponseForm;
    }

    private static Id responseLibraryRt() {
        if (rtResponseLibrary == null) {
            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.C_Response__c.getRecordTypeInfosByDeveloperName().get('Library');
            if (rtInfo == null) {
                throw new AuraHandledException('Missing RecordType: C_Response__c.Library');
            }
            rtResponseLibrary = rtInfo.getRecordTypeId();
        }
        return rtResponseLibrary;
    }

    private static Id sectionFormRt() {
        if (rtSectionForm == null) {
            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.C_Section__c.getRecordTypeInfosByDeveloperName().get('Form');
            if (rtInfo == null) {
                throw new AuraHandledException('Missing RecordType: C_Section__c.Form');
            }
            rtSectionForm = rtInfo.getRecordTypeId();
        }
        return rtSectionForm;
    }

    private static Id sectionLibraryRt() {
        if (rtSectionLibrary == null) {
            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.C_Section__c.getRecordTypeInfosByDeveloperName().get('Library');
            if (rtInfo == null) {
                throw new AuraHandledException('Missing RecordType: C_Section__c.Library');
            }
            rtSectionLibrary = rtInfo.getRecordTypeId();
        }
        return rtSectionLibrary;
    }

    private static Id getOrCreateLibraryFormId() {
        if (cachedLibraryFormId != null) return cachedLibraryFormId;
        List<C_Form__c> existing = [
            SELECT Id
            FROM C_Form__c
            WHERE C_Hide_From_Form_Builder__c = TRUE AND Name = :LIBRARY_FORM_NAME
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            cachedLibraryFormId = existing[0].Id;
            return cachedLibraryFormId;
        }
        C_Form__c f = new C_Form__c(
            Name = LIBRARY_FORM_NAME,
            C_Description__c = 'Internal container for reusable question and section assets.',
            C_Status__c = 'Draft',
            C_Version__c = 1,
            C_Default_Language__c = 'en',
            C_Hide_From_Form_Builder__c = true
        );
        try {
            insert f;
            cachedLibraryFormId = f.Id;
        } catch (DmlException e) {
            // Concurrent call inserted first; re-query for the winner
            List<C_Form__c> raceWinner = [
                SELECT Id FROM C_Form__c
                WHERE C_Hide_From_Form_Builder__c = TRUE AND Name = :LIBRARY_FORM_NAME
                LIMIT 1
            ];
            if (raceWinner.isEmpty()) throw e;
            cachedLibraryFormId = raceWinner[0].Id;
        }
        return cachedLibraryFormId;
    }

    private static Id getLibraryRootPageId() {
        if (cachedLibraryPageId != null) return cachedLibraryPageId;
        Id formId = getOrCreateLibraryFormId();
        List<C_Page__c> pages = [SELECT Id FROM C_Page__c WHERE C_Form__c = :formId ORDER BY C_Order__c LIMIT 1];
        if (!pages.isEmpty()) {
            cachedLibraryPageId = pages[0].Id;
            return cachedLibraryPageId;
        }
        C_Page__c p = new C_Page__c(
            Name = LIBRARY_PAGE_NAME,
            C_Description__c = 'Root page for library sections',
            C_Form__c = formId,
            C_Order__c = 1
        );
        insert p;
        cachedLibraryPageId = p.Id;
        return cachedLibraryPageId;
    }

    private static Id libraryFormIdForValidation() {
        if (cachedLibraryFormId != null) return cachedLibraryFormId;
        List<C_Form__c> existing = [
            SELECT Id
            FROM C_Form__c
            WHERE C_Hide_From_Form_Builder__c = TRUE AND Name = :LIBRARY_FORM_NAME
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            cachedLibraryFormId = existing[0].Id;
        }
        return cachedLibraryFormId;
    }

    private static void assertTargetFormNotLibrary(Id formId) {
        Id libId = libraryFormIdForValidation();
        if (libId != null && formId == libId) {
            throw new AuraHandledException('Cannot use the asset library form as the target.');
        }
    }

    /**
     * Returns the hidden asset-library container form Id, creating it if missing.
     * Not cacheable: lazy-create may insert the form (cacheable Apex cannot perform DML).
     */
    @AuraEnabled
    public static Id getAssetLibraryFormId() {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }
            return getOrCreateLibraryFormId();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<C_Question__c> searchLibraryQuestions(String searchTerm) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }
            Id libFormId = getOrCreateLibraryFormId();
            Set<Id> pageIds = new Map<Id, C_Page__c>([SELECT Id FROM C_Page__c WHERE C_Form__c = :libFormId]).keySet();
            if (pageIds.isEmpty()) {
                return new List<C_Question__c>();
            }
            Set<Id> sectionIds = new Map<Id, C_Section__c>([
                SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds
            ]).keySet();
            if (sectionIds.isEmpty()) {
                return new List<C_Question__c>();
            }
            String likeTerm = buildLikeClause(searchTerm);
            Id libQrt = questionLibraryRt();
            return [
                SELECT Id, Name, C_Question_Text__c, C_Type__c
                FROM C_Question__c
                WHERE RecordTypeId = :libQrt AND C_Section__c IN :sectionIds AND Name LIKE :likeTerm
                ORDER BY Name
                LIMIT 100
            ];
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<C_Section__c> searchLibrarySections(String searchTerm) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }
            Id libFormId = getOrCreateLibraryFormId();
            Set<Id> pageIds = new Map<Id, C_Page__c>([SELECT Id FROM C_Page__c WHERE C_Form__c = :libFormId]).keySet();
            if (pageIds.isEmpty()) {
                return new List<C_Section__c>();
            }
            String likeTerm = buildLikeClause(searchTerm);
            Id libSrt = sectionLibraryRt();
            return [
                SELECT Id, Name, C_Order__c
                FROM C_Section__c
                WHERE RecordTypeId = :libSrt AND C_Page__c IN :pageIds AND Name LIKE :likeTerm
                ORDER BY Name
                LIMIT 100
            ];
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String buildLikeClause(String raw) {
        if (String.isBlank(raw)) {
            return '%';
        }
        String esc = raw.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
        return '%' + esc + '%';
    }

    /**
     * Match formTranslationInline + TranslationService.saveTranslation: a single parent lookup on C_Translation__c
     * so TranslationReader.buildKey aligns with formRenderer.getTranslated.
     */
    private static void applyInlineStyleTranslationAnchors(C_Translation__c row) {
        if (row == null) {
            return;
        }
        if (row.C_Response__c != null) {
            row.C_Category__c = null;
            row.C_Page__c = null;
            row.C_Section__c = null;
            row.C_Question__c = null;
        } else if (row.C_Question__c != null) {
            row.C_Category__c = null;
            row.C_Page__c = null;
            row.C_Section__c = null;
            row.C_Response__c = null;
        } else if (row.C_Section__c != null) {
            row.C_Category__c = null;
            row.C_Page__c = null;
            row.C_Question__c = null;
            row.C_Response__c = null;
        } else if (row.C_Page__c != null) {
            row.C_Category__c = null;
            row.C_Section__c = null;
            row.C_Question__c = null;
            row.C_Response__c = null;
        } else if (row.C_Category__c != null) {
            row.C_Page__c = null;
            row.C_Section__c = null;
            row.C_Question__c = null;
            row.C_Response__c = null;
        } else {
            row.C_Category__c = null;
            row.C_Page__c = null;
            row.C_Section__c = null;
            row.C_Question__c = null;
            row.C_Response__c = null;
        }
    }

    private static Boolean isQuestionInlineTranslationField(String fieldApiName) {
        return fieldApiName != null && QUESTION_INLINE_TRANSLATION_FIELDS.contains(fieldApiName);
    }

    /**
     * Legacy rows may store question-level fields with only C_Section__c set. When the subtree has exactly one question,
     * attach to that question's clone so runtime Question_* keys resolve. Multi-question sections are left unchanged.
     */
    private static void maybeAssignSingleQuestionForSectionScopedQuestionField(
        C_Translation__c nt,
        C_Translation__c sourceRow,
        Integer sourceQuestionCount,
        Id newQuestionIdWhenSingle
    ) {
        if (nt == null || sourceRow == null) {
            return;
        }
        if (sourceQuestionCount != 1 || newQuestionIdWhenSingle == null) {
            return;
        }
        if (nt.C_Response__c != null || nt.C_Question__c != null) {
            return;
        }
        if (!isQuestionInlineTranslationField(nt.C_Field_Name__c)) {
            return;
        }
        if (sourceRow.C_Question__c != null || sourceRow.C_Response__c != null) {
            return;
        }
        if (sourceRow.C_Section__c == null) {
            return;
        }
        nt.C_Question__c = newQuestionIdWhenSingle;
        nt.C_Section__c = null;
    }

    @AuraEnabled
    public static Id injectLibraryQuestion(Id libraryQuestionId, Id targetSectionId, Integer positionZeroBased) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }

            C_Section__c targetSec = [
                SELECT Id, C_Page__c, C_Page__r.C_Form__c
                FROM C_Section__c
                WHERE Id = :targetSectionId
                LIMIT 1
            ];
            assertTargetFormNotLibrary(targetSec.C_Page__r.C_Form__c);

            C_Question__c src = [
                SELECT
                    Id,
                    RecordTypeId,
                    Name,
                    C_Weight__c,
                    C_Type__c,
                    C_Question_Text__c,
                    C_Help_Text__c,
                    C_Order__c,
                    C_Accepted_File_Types__c,
                    C_Table_Columns__c,
                    C_Is_Required__c,
                    C_Is_Disabled__c,
                    C_Validation_Message__c,
                    C_Validation_Pattern__c,
                    C_Placeholder__c,
                    C_Max_Length__c,
                    C_Max_Word_Count__c,
                    C_Min_Value__c,
                    C_Max_Value__c,
                    C_Table_Min_Rows__c,
                    C_Table_Max_Rows__c,
                    C_Max_Files__c,
                    C_Max_File_Size_MB__c,
                    C_Number_Decimal_Places__c,
                    C_Layout_Span__c
                FROM C_Question__c
                WHERE Id = :libraryQuestionId
                LIMIT 1
            ];
            if (src.RecordTypeId != questionLibraryRt()) {
                throw new AuraHandledException('Source question must be a library asset.');
            }

            C_Form__c targetForm = [SELECT Id, Name FROM C_Form__c WHERE Id = :targetSec.C_Page__r.C_Form__c LIMIT 1];

            Integer oneBased = (positionZeroBased != null) ? positionZeroBased + 1 : null;
            shiftQuestionOrdersForInsert(targetSectionId, oneBased);

            C_Question__c nq = src.clone(false, false, false, false);
            nq.RecordTypeId = questionFormRt();
            nq.C_Section__c = targetSectionId;
            nq.C_Order__c = (oneBased != null && oneBased > 0) ? oneBased : nextQuestionOrder(targetSectionId);
            nq.C_Cross_Field_Rules_JSON__c = null;
            nq.C_Source_Question__c = null;
            String sn = targetForm.Name + ' ' + nq.Name;
            nq.C_Search_Name__c = sn.length() <= 255 ? sn : sn.left(255);
            insert nq;

            List<C_Response__c> srcResponses = getResponsesForQuestions(new Set<Id>{ src.Id });
            Map<Id, C_Response__c> oldIdNewResp = cloneResponsesForQuestions(
                srcResponses,
                new Map<Id, C_Question__c>{ src.Id => nq },
                true
            );

            cloneTranslationsForQuestionSubtree(src.Id, oldIdNewResp, nq.Id, targetSec.C_Page__c, targetSectionId);

            return nq.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Integer nextQuestionOrder(Id sectionId) {
        AggregateResult ar = [SELECT MAX(C_Order__c) mo FROM C_Question__c WHERE C_Section__c = :sectionId];
        Decimal m = (Decimal) ar.get('mo');
        return m == null ? 1 : m.intValue() + 1;
    }

    private static void shiftQuestionOrdersForInsert(Id sectionId, Integer oneBasedInsert) {
        if (oneBasedInsert == null || oneBasedInsert < 1) {
            return;
        }
        List<C_Question__c> shift = [
            SELECT Id, C_Order__c
            FROM C_Question__c
            WHERE C_Section__c = :sectionId AND C_Order__c >= :oneBasedInsert
            ORDER BY C_Order__c DESC
        ];
        for (C_Question__c q : shift) {
            q.C_Order__c = q.C_Order__c + 1;
        }
        if (!shift.isEmpty()) {
            update shift;
        }
    }

    private static List<C_Response__c> getResponsesForQuestions(Set<Id> sourceQuestionIds) {
        if (sourceQuestionIds == null || sourceQuestionIds.isEmpty()) {
            return new List<C_Response__c>();
        }
        return [
            SELECT
                Id,
                C_Question__c,
                Name,
                C_Response_Text__c,
                C_Points__c,
                C_Order__c,
                C_Locks_Question__c,
                C_Requires_Details__c
            FROM C_Response__c
            WHERE C_Question__c IN :sourceQuestionIds
            ORDER BY C_Question__c, C_Order__c
        ];
    }

    private static Map<Id, C_Response__c> cloneResponsesForQuestions(
        List<C_Response__c> srcRows,
        Map<Id, C_Question__c> oldIdNewQuestion,
        Boolean useFormResponseRt
    ) {
        Map<Id, C_Response__c> oldIdNew = new Map<Id, C_Response__c>();
        if (srcRows == null || srcRows.isEmpty() || oldIdNewQuestion == null || oldIdNewQuestion.isEmpty()) {
            return oldIdNew;
        }

        List<C_Response__c> toInsert = new List<C_Response__c>();
        List<Id> sourceResponseIds = new List<Id>();
        for (C_Response__c r : srcRows) {
            C_Question__c nq = oldIdNewQuestion.get(r.C_Question__c);
            if (nq == null || nq.Id == null) {
                continue;
            }
            C_Response__c nr = r.clone(false, false, false, false);
            nr.C_Question__c = nq.Id;
            nr.RecordTypeId = useFormResponseRt ? responseFormRt() : responseLibraryRt();
            nr.C_Source_Response__c = null;
            String rs = nq.C_Search_Name__c + ' ' + nr.Name;
            nr.C_Search_Name__c = rs.length() <= 255 ? rs : rs.left(255);
            toInsert.add(nr);
            sourceResponseIds.add(r.Id);
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (Integer idx = 0; idx < sourceResponseIds.size(); idx++) {
                oldIdNew.put(sourceResponseIds[idx], toInsert[idx]);
            }
        }
        return oldIdNew;
    }

    private static void cloneTranslationsForQuestionSubtree(
        Id sourceQuestionId,
        Map<Id, C_Response__c> oldIdNewResp,
        Id newQuestionId,
        Id targetPageId,
        Id targetSectionId
    ) {
        Set<Id> oldRespIds = oldIdNewResp.keySet();
        List<C_Translation__c> trans = [
            SELECT Id, C_Language__c, C_Translated_Text__c, C_Field_Name__c, RecordTypeId, C_Question__c, C_Response__c, C_Section__c
            FROM C_Translation__c
            WHERE C_Question__c = :sourceQuestionId OR C_Response__c IN :oldRespIds
        ];
        if (trans.isEmpty()) {
            return;
        }
        List<C_Translation__c> toIns = new List<C_Translation__c>();
        for (C_Translation__c t : trans) {
            C_Translation__c nt = t.clone(false, false, false, false);
            nt.C_Category__c = null;
            nt.C_Page__c = targetPageId;
            nt.C_Section__c = targetSectionId;
            if (t.C_Question__c != null) {
                nt.C_Question__c = newQuestionId;
                nt.C_Response__c = null;
            } else if (t.C_Response__c != null) {
                C_Response__c mapped = oldIdNewResp.get(t.C_Response__c);
                nt.C_Response__c = mapped != null ? mapped.Id : null;
                nt.C_Question__c = null;
            }
            maybeAssignSingleQuestionForSectionScopedQuestionField(nt, t, 1, newQuestionId);
            applyInlineStyleTranslationAnchors(nt);
            toIns.add(nt);
        }
        if (!toIns.isEmpty()) {
            insert toIns;
        }
    }

    @AuraEnabled
    public static Id injectLibrarySection(Id librarySectionId, Id targetPageId, Integer positionZeroBased) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }

            C_Page__c targetPage = [SELECT Id, C_Form__c FROM C_Page__c WHERE Id = :targetPageId LIMIT 1];
            assertTargetFormNotLibrary(targetPage.C_Form__c);

            C_Section__c srcSec = [
                SELECT Id, RecordTypeId, Name, C_Bonus__c, C_Order__c, C_Weight__c, C_Excluded_From_Weight__c
                FROM C_Section__c
                WHERE Id = :librarySectionId
                LIMIT 1
            ];
            if (srcSec.RecordTypeId != sectionLibraryRt()) {
                throw new AuraHandledException('Source section must be a library asset.');
            }

            Integer oneBased = (positionZeroBased != null) ? positionZeroBased + 1 : null;
            shiftSectionOrdersForInsert(targetPageId, oneBased);

            C_Section__c newSec = srcSec.clone(false, false, false, false);
            newSec.RecordTypeId = sectionFormRt();
            newSec.C_Page__c = targetPageId;
            newSec.C_Order__c = (oneBased != null && oneBased > 0) ? oneBased : nextSectionOrder(targetPageId);
            insert newSec;

            List<C_Question__c> srcQs = [
                SELECT
                    Id,
                    Name,
                    C_Weight__c,
                    C_Type__c,
                    C_Question_Text__c,
                    C_Help_Text__c,
                    C_Order__c,
                    C_Accepted_File_Types__c,
                    C_Table_Columns__c,
                    C_Is_Required__c,
                    C_Is_Disabled__c,
                    C_Validation_Message__c,
                    C_Validation_Pattern__c,
                    C_Placeholder__c,
                    C_Max_Length__c,
                    C_Max_Word_Count__c,
                    C_Min_Value__c,
                    C_Max_Value__c,
                    C_Table_Min_Rows__c,
                    C_Table_Max_Rows__c,
                    C_Max_Files__c,
                    C_Max_File_Size_MB__c,
                    C_Number_Decimal_Places__c,
                    C_Layout_Span__c
                FROM C_Question__c
                WHERE C_Section__c = :librarySectionId
                ORDER BY C_Order__c
            ];

            C_Form__c targetForm = [SELECT Id, Name FROM C_Form__c WHERE Id = :targetPage.C_Form__c LIMIT 1];

            Map<Id, C_Question__c> oldIdNewQ = new Map<Id, C_Question__c>();
            for (C_Question__c sq : srcQs) {
                C_Question__c nq = sq.clone(false, false, false, false);
                nq.RecordTypeId = questionFormRt();
                nq.C_Section__c = newSec.Id;
                nq.C_Cross_Field_Rules_JSON__c = null;
                nq.C_Source_Question__c = null;
                String sn = targetForm.Name + ' ' + nq.Name;
                nq.C_Search_Name__c = sn.length() <= 255 ? sn : sn.left(255);
                oldIdNewQ.put(sq.Id, nq);
            }
            if (!oldIdNewQ.isEmpty()) {
                insert oldIdNewQ.values();
            }

            Set<Id> srcQIdSet = oldIdNewQ.keySet();
            List<C_Response__c> srcResponses = getResponsesForQuestions(srcQIdSet);
            Map<Id, C_Response__c> allOldNewResp = cloneResponsesForQuestions(srcResponses, oldIdNewQ, true);

            Set<Id> srcRespIds = new Set<Id>();
            for (C_Response__c rr : srcResponses) {
                srcRespIds.add(rr.Id);
            }
            List<C_Translation__c> trans = [
                SELECT Id, C_Language__c, C_Translated_Text__c, C_Field_Name__c, RecordTypeId, C_Question__c, C_Response__c, C_Section__c
                FROM C_Translation__c
                WHERE C_Section__c = :librarySectionId OR C_Question__c IN :srcQIdSet OR C_Response__c IN :srcRespIds
            ];

            if (!trans.isEmpty()) {
                Id newQuestionIdWhenSingle = null;
                if (srcQs.size() == 1) {
                    newQuestionIdWhenSingle = oldIdNewQ.get(srcQs[0].Id).Id;
                }
                List<C_Translation__c> toIns = new List<C_Translation__c>();
                for (C_Translation__c t : trans) {
                    C_Translation__c nt = t.clone(false, false, false, false);
                    nt.C_Category__c = null;
                    nt.C_Page__c = targetPageId;
                    if (t.C_Section__c != null) {
                        nt.C_Section__c = newSec.Id;
                        nt.C_Question__c = null;
                        nt.C_Response__c = null;
                    } else if (t.C_Question__c != null) {
                        C_Question__c nq = oldIdNewQ.get(t.C_Question__c);
                        nt.C_Section__c = newSec.Id;
                        nt.C_Question__c = nq != null ? nq.Id : null;
                        nt.C_Response__c = null;
                    } else if (t.C_Response__c != null) {
                        C_Response__c nr = allOldNewResp.get(t.C_Response__c);
                        nt.C_Section__c = newSec.Id;
                        nt.C_Response__c = nr != null ? nr.Id : null;
                        nt.C_Question__c = null;
                    }
                    maybeAssignSingleQuestionForSectionScopedQuestionField(nt, t, srcQs.size(), newQuestionIdWhenSingle);
                    applyInlineStyleTranslationAnchors(nt);
                    toIns.add(nt);
                }
                insert toIns;
            }

            return newSec.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Integer nextSectionOrder(Id pageId) {
        AggregateResult ar = [SELECT MAX(C_Order__c) mo FROM C_Section__c WHERE C_Page__c = :pageId];
        Decimal m = (Decimal) ar.get('mo');
        return m == null ? 1 : m.intValue() + 1;
    }

    private static void shiftSectionOrdersForInsert(Id pageId, Integer oneBasedInsert) {
        if (oneBasedInsert == null || oneBasedInsert < 1) {
            return;
        }
        List<C_Section__c> shift = [
            SELECT Id, C_Order__c
            FROM C_Section__c
            WHERE C_Page__c = :pageId AND C_Order__c >= :oneBasedInsert
            ORDER BY C_Order__c DESC
        ];
        for (C_Section__c s : shift) {
            s.C_Order__c = s.C_Order__c + 1;
        }
        if (!shift.isEmpty()) {
            update shift;
        }
    }

    @AuraEnabled
    public static Id promoteQuestionToLibrary(Id formQuestionId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }

            C_Question__c fq = [
                SELECT
                    Id,
                    RecordTypeId,
                    Name,
                    C_Weight__c,
                    C_Type__c,
                    C_Question_Text__c,
                    C_Help_Text__c,
                    C_Order__c,
                    C_Accepted_File_Types__c,
                    C_Table_Columns__c,
                    C_Is_Required__c,
                    C_Is_Disabled__c,
                    C_Validation_Message__c,
                    C_Validation_Pattern__c,
                    C_Placeholder__c,
                    C_Max_Length__c,
                    C_Max_Word_Count__c,
                    C_Min_Value__c,
                    C_Max_Value__c,
                    C_Table_Min_Rows__c,
                    C_Table_Max_Rows__c,
                    C_Max_Files__c,
                    C_Max_File_Size_MB__c,
                    C_Number_Decimal_Places__c,
                    C_Layout_Span__c,
                    C_Section__c,
                    C_Section__r.C_Page__c,
                    C_Section__r.C_Page__r.C_Form__c
                FROM C_Question__c
                WHERE Id = :formQuestionId
                LIMIT 1
            ];
            if (fq.RecordTypeId == questionLibraryRt()) {
                throw new AuraHandledException('Only form questions can be published to the library.');
            }
            assertTargetFormNotLibrary(fq.C_Section__r.C_Page__r.C_Form__c);

            Id libPageId = getLibraryRootPageId();
            Integer secOrder = nextSectionOrder(libPageId);
            String baseName = String.isBlank(fq.Name) ? 'Question' : fq.Name;
            String secName = baseName.length() > 75 ? baseName.left(75) + '…' : baseName;
            // Form RT: internal parent row only. Library RT sections are listed in searchLibrarySections;
            // this shell must not appear as a reusable section asset beside promoteSectionToLibrary rows.
            C_Section__c libSec = new C_Section__c(
                Name = 'Lib: ' + secName,
                C_Page__c = libPageId,
                C_Order__c = secOrder,
                C_Weight__c = 0,
                C_Bonus__c = false,
                C_Excluded_From_Weight__c = false,
                RecordTypeId = sectionFormRt()
            );
            insert libSec;

            C_Question__c nq = fq.clone(false, false, false, false);
            nq.RecordTypeId = questionLibraryRt();
            nq.C_Section__c = libSec.Id;
            nq.C_Order__c = 1;
            nq.C_Cross_Field_Rules_JSON__c = null;
            nq.C_Source_Question__c = null;
            nq.C_Search_Name__c = LIBRARY_FORM_NAME + ' ' + nq.Name;
            if (nq.C_Search_Name__c.length() > 255) {
                nq.C_Search_Name__c = nq.C_Search_Name__c.left(255);
            }
            insert nq;

            List<C_Response__c> srcResponses = getResponsesForQuestions(new Set<Id>{ fq.Id });
            Map<Id, C_Response__c> oldNew = cloneResponsesForQuestions(
                srcResponses,
                new Map<Id, C_Question__c>{ fq.Id => nq },
                false
            );

            Set<Id> srcRespIds = new Set<Id>();
            for (C_Response__c srcResp : srcResponses) {
                srcRespIds.add(srcResp.Id);
            }
            List<C_Translation__c> trans = [
                SELECT Id, C_Language__c, C_Translated_Text__c, C_Field_Name__c, RecordTypeId, C_Question__c, C_Response__c, C_Section__c
                FROM C_Translation__c
                WHERE C_Question__c = :fq.Id OR C_Response__c IN :srcRespIds
            ];
            if (!trans.isEmpty()) {
                List<C_Translation__c> toIns = new List<C_Translation__c>();
                for (C_Translation__c t : trans) {
                    C_Translation__c nt = t.clone(false, false, false, false);
                    nt.C_Category__c = null;
                    nt.C_Page__c = libPageId;
                    nt.C_Section__c = libSec.Id;
                    if (t.C_Question__c != null) {
                        nt.C_Question__c = nq.Id;
                        nt.C_Response__c = null;
                    } else {
                        C_Response__c nr = oldNew.get(t.C_Response__c);
                        nt.C_Response__c = nr != null ? nr.Id : null;
                        nt.C_Question__c = null;
                    }
                    maybeAssignSingleQuestionForSectionScopedQuestionField(nt, t, 1, nq.Id);
                    applyInlineStyleTranslationAnchors(nt);
                    toIns.add(nt);
                }
                insert toIns;
            }

            return nq.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id promoteSectionToLibrary(Id formSectionId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }

            C_Section__c fsec = [
                SELECT
                    Id,
                    RecordTypeId,
                    Name,
                    C_Bonus__c,
                    C_Order__c,
                    C_Weight__c,
                    C_Excluded_From_Weight__c,
                    C_Page__c,
                    C_Page__r.C_Form__c
                FROM C_Section__c
                WHERE Id = :formSectionId
                LIMIT 1
            ];
            if (fsec.RecordTypeId == sectionLibraryRt()) {
                throw new AuraHandledException('Only form sections can be published to the library.');
            }
            assertTargetFormNotLibrary(fsec.C_Page__r.C_Form__c);

            Id libPageId = getLibraryRootPageId();
            Integer ord = nextSectionOrder(libPageId);

            C_Section__c nsec = fsec.clone(false, false, false, false);
            nsec.RecordTypeId = sectionLibraryRt();
            nsec.C_Page__c = libPageId;
            nsec.C_Order__c = ord;
            insert nsec;

            List<C_Question__c> srcQs = [
                SELECT
                    Id,
                    Name,
                    C_Weight__c,
                    C_Type__c,
                    C_Question_Text__c,
                    C_Help_Text__c,
                    C_Order__c,
                    C_Accepted_File_Types__c,
                    C_Table_Columns__c,
                    C_Is_Required__c,
                    C_Is_Disabled__c,
                    C_Validation_Message__c,
                    C_Validation_Pattern__c,
                    C_Placeholder__c,
                    C_Max_Length__c,
                    C_Max_Word_Count__c,
                    C_Min_Value__c,
                    C_Max_Value__c,
                    C_Table_Min_Rows__c,
                    C_Table_Max_Rows__c,
                    C_Max_Files__c,
                    C_Max_File_Size_MB__c,
                    C_Number_Decimal_Places__c,
                    C_Layout_Span__c
                FROM C_Question__c
                WHERE C_Section__c = :formSectionId
                ORDER BY C_Order__c
            ];

            Map<Id, C_Question__c> oldIdNewQ = new Map<Id, C_Question__c>();
            for (C_Question__c sq : srcQs) {
                C_Question__c nq = sq.clone(false, false, false, false);
                // Form RT: children belong to the library *section* asset only. Standalone library questions
                // (browse/inject via searchLibraryQuestions / injectLibraryQuestion) use questionLibraryRt().
                nq.RecordTypeId = questionFormRt();
                nq.C_Section__c = nsec.Id;
                nq.C_Cross_Field_Rules_JSON__c = null;
                nq.C_Source_Question__c = null;
                nq.C_Search_Name__c = LIBRARY_FORM_NAME + ' ' + nq.Name;
                if (nq.C_Search_Name__c.length() > 255) {
                    nq.C_Search_Name__c = nq.C_Search_Name__c.left(255);
                }
                oldIdNewQ.put(sq.Id, nq);
            }
            if (!oldIdNewQ.isEmpty()) {
                insert oldIdNewQ.values();
            }

            Set<Id> srcQIds = oldIdNewQ.keySet();
            List<C_Response__c> srcResponses = getResponsesForQuestions(srcQIds);
            Map<Id, C_Response__c> allOldNewResp = cloneResponsesForQuestions(srcResponses, oldIdNewQ, true);
            Set<Id> srcRespIds = new Set<Id>();
            for (C_Response__c srcResp : srcResponses) {
                srcRespIds.add(srcResp.Id);
            }

            List<C_Translation__c> trans = [
                SELECT Id, C_Language__c, C_Translated_Text__c, C_Field_Name__c, RecordTypeId, C_Question__c, C_Response__c, C_Section__c
                FROM C_Translation__c
                WHERE C_Section__c = :formSectionId OR C_Question__c IN :srcQIds OR C_Response__c IN :srcRespIds
            ];
            if (!trans.isEmpty()) {
                Id newQuestionIdWhenSingle = null;
                if (srcQs.size() == 1) {
                    newQuestionIdWhenSingle = oldIdNewQ.get(srcQs[0].Id).Id;
                }
                List<C_Translation__c> toIns = new List<C_Translation__c>();
                for (C_Translation__c t : trans) {
                    C_Translation__c nt = t.clone(false, false, false, false);
                    nt.C_Category__c = null;
                    nt.C_Page__c = libPageId;
                    if (t.C_Section__c != null) {
                        nt.C_Section__c = nsec.Id;
                        nt.C_Question__c = null;
                        nt.C_Response__c = null;
                    } else if (t.C_Question__c != null) {
                        C_Question__c nq = oldIdNewQ.get(t.C_Question__c);
                        nt.C_Section__c = nsec.Id;
                        nt.C_Question__c = nq != null ? nq.Id : null;
                        nt.C_Response__c = null;
                    } else if (t.C_Response__c != null) {
                        C_Response__c nr = allOldNewResp.get(t.C_Response__c);
                        nt.C_Section__c = nsec.Id;
                        nt.C_Response__c = nr != null ? nr.Id : null;
                        nt.C_Question__c = null;
                    }
                    maybeAssignSingleQuestionForSectionScopedQuestionField(nt, t, srcQs.size(), newQuestionIdWhenSingle);
                    applyInlineStyleTranslationAnchors(nt);
                    toIns.add(nt);
                }
                insert toIns;
            }

            return nsec.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}

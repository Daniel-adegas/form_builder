/**
 * @description       : Backend service for Form Builder LWCs - CRUD operations on form elements
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   18-03-2026   Daniel Murracas     Bulkified queries, added error handling
 * 1.2   01-04-2026   Tom De Backer       Added pruneStaleCategoryTargetsIfEmpty helper
 * 1.3   01-04-2026   Tom De Backer       Strip cross-field JSON rules that reference deleted questions
 * ------------------------------------------------------------
**/
public with sharing class FormBuilderService {

    @AuraEnabled
    public static List<C_Form__c> getForms() {
        try {
            return [SELECT Id, Name, C_Description__c, C_Status__c, C_Version__c, C_Default_Language__c,
                           CreatedDate, LastModifiedDate
                    FROM C_Form__c
                    WHERE C_Hide_From_Form_Builder__c != TRUE
                    ORDER BY LastModifiedDate DESC LIMIT 200];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Form__c saveForm(C_Form__c form) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            if (form.Id != null) {
                C_Form__c existing = [SELECT C_Hide_From_Form_Builder__c FROM C_Form__c WHERE Id = :form.Id LIMIT 1];
                if (existing.C_Hide_From_Form_Builder__c == true) {
                    throw new AuraHandledException('This form cannot be modified (internal asset library container).');
                }
            }
            upsert form;
            return form;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteForm(Id formId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            C_Form__c formRow = [SELECT Id, C_Hide_From_Form_Builder__c FROM C_Form__c WHERE Id = :formId LIMIT 1];
            if (formRow.C_Hide_From_Form_Builder__c == true) {
                throw new AuraHandledException('This form cannot be deleted (internal asset library container).');
            }
            Set<Id> pageIds = new Set<Id>();
            for (C_Page__c p : [SELECT Id FROM C_Page__c WHERE C_Form__c = :formId]) pageIds.add(p.Id);

            Set<Id> sectionIds = new Set<Id>();
            for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds]) sectionIds.add(s.Id);

            Set<Id> questionIds = new Set<Id>();
            for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds]) questionIds.add(q.Id);

            Set<Id> responseIds = new Set<Id>();
            for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds]) responseIds.add(r.Id);

            Set<Id> categoryIds = new Set<Id>();
            for (C_Category__c cat : [SELECT Id FROM C_Category__c WHERE C_Form__c = :formId]) categoryIds.add(cat.Id);

            delete [SELECT Id FROM C_Dependency__c WHERE C_Controlling_Response__c IN :responseIds
                    OR C_Target_Category__c IN :categoryIds OR C_Target_Page__c IN :pageIds
                    OR C_Target_Section__c IN :sectionIds OR C_Target_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Translation__c WHERE C_Category__c IN :categoryIds OR C_Page__c IN :pageIds
                    OR C_Section__c IN :sectionIds OR C_Question__c IN :questionIds OR C_Response__c IN :responseIds];
            delete [SELECT Id FROM C_Field_Mapping__c WHERE C_Form_Target__c IN (SELECT Id FROM C_Form_Target__c WHERE C_Form__c = :formId)];
            delete [SELECT Id FROM C_Form_Target__c WHERE C_Form__c = :formId];
            delete [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds];
            delete [SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds];
            delete [SELECT Id FROM C_Page__c WHERE C_Form__c = :formId];
            delete [SELECT Id FROM C_Category__c WHERE C_Form__c = :formId];
            delete new C_Form__c(Id = formId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<C_Category__c> getCategories(Id formId) {
        try {
            return [SELECT Id, Name, C_Form__c, C_Order__c, C_Description__c, C_Icon__c, C_Is_Active__c
                    FROM C_Category__c WHERE C_Form__c = :formId ORDER BY C_Order__c];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Category__c saveCategory(C_Category__c category) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            upsert category;
            return category;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteCategory(Id categoryId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }

            C_Category__c catRecord = [SELECT Id, C_Form__c FROM C_Category__c WHERE Id = :categoryId LIMIT 1];

            Set<Id> pageIds = new Set<Id>();
            for (C_Page__c p : [SELECT Id FROM C_Page__c WHERE C_Category__c = :categoryId]) pageIds.add(p.Id);

            Set<Id> sectionIds = new Set<Id>();
            for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds]) sectionIds.add(s.Id);

            Set<Id> questionIds = new Set<Id>();
            for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds]) questionIds.add(q.Id);

            Set<Id> responseIds = new Set<Id>();
            for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds]) responseIds.add(r.Id);

            stripCrossFieldRulesReferencingIds(catRecord.C_Form__c, questionIds);

            delete [SELECT Id FROM C_Dependency__c WHERE C_Controlling_Response__c IN :responseIds
                    OR C_Target_Category__c = :categoryId OR C_Target_Page__c IN :pageIds
                    OR C_Target_Section__c IN :sectionIds OR C_Target_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Translation__c WHERE C_Category__c = :categoryId OR C_Page__c IN :pageIds
                    OR C_Section__c IN :sectionIds OR C_Question__c IN :questionIds OR C_Response__c IN :responseIds];
            delete [SELECT Id FROM C_Field_Mapping__c WHERE C_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds];
            delete [SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds];
            delete [SELECT Id FROM C_Page__c WHERE C_Category__c = :categoryId];
            delete new C_Category__c(Id = categoryId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<C_Page__c> getPages(Id formId) {
        try {
            return [SELECT Id, Name, C_Description__c, C_Order__c, C_Form__c, C_Category__c
                    FROM C_Page__c WHERE C_Form__c = :formId ORDER BY C_Order__c];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Page__c savePage(C_Page__c page) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            upsert page;
            return page;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deletePage(Id pageId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }

            C_Page__c pRecord = [SELECT Id, C_Category__c, C_Form__c FROM C_Page__c WHERE Id = :pageId LIMIT 1];

            Set<Id> sectionIds = new Set<Id>();
            for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c = :pageId]) sectionIds.add(s.Id);

            Set<Id> questionIds = new Set<Id>();
            for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds]) questionIds.add(q.Id);

            Set<Id> responseIds = new Set<Id>();
            for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds]) responseIds.add(r.Id);

            stripCrossFieldRulesReferencingIds(pRecord.C_Form__c, questionIds);

            delete [SELECT Id FROM C_Dependency__c WHERE C_Controlling_Response__c IN :responseIds
                    OR C_Target_Page__c = :pageId OR C_Target_Section__c IN :sectionIds OR C_Target_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Translation__c WHERE C_Page__c = :pageId OR C_Section__c IN :sectionIds
                    OR C_Question__c IN :questionIds OR C_Response__c IN :responseIds];

            delete [SELECT Id FROM C_Field_Mapping__c WHERE C_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds];
            delete [SELECT Id FROM C_Section__c WHERE C_Page__c = :pageId];
            delete new C_Page__c(Id = pageId);

            pruneStaleCategoryTargetsIfEmpty(singletonCategorySet(pRecord.C_Category__c));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<C_Section__c> getSections(Id pageId) {
        try {
            return [SELECT Id, Name, C_Page__c, C_Order__c, C_Weight__c, C_Bonus__c, C_Excluded_From_Weight__c
                    FROM C_Section__c WHERE C_Page__c = :pageId ORDER BY C_Order__c];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Section__c saveSection(C_Section__c section) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            if (section.Id != null) {
                C_Section__c existing = [
                    SELECT C_Page__r.C_Form__r.C_Hide_From_Form_Builder__c
                    FROM C_Section__c WHERE Id = :section.Id LIMIT 1
                ];
                if (existing.C_Page__r.C_Form__r.C_Hide_From_Form_Builder__c == true) {
                    throw new AuraHandledException('This section cannot be modified (internal asset library container).');
                }
            }
            if (section.Id == null && section.RecordTypeId == null) {
                Schema.RecordTypeInfo rtInfo =
                    Schema.SObjectType.C_Section__c.getRecordTypeInfosByDeveloperName().get('Form');
                if (rtInfo == null) {
                    throw new AuraHandledException('Missing RecordType: C_Section__c.Form');
                }
                section.RecordTypeId = rtInfo.getRecordTypeId();
            }
            upsert section;
            return section;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteSection(Id sectionId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }

            C_Section__c sRecord = [SELECT Id, C_Page__r.C_Category__c, C_Page__r.C_Form__c FROM C_Section__c WHERE Id = :sectionId LIMIT 1];

            Set<Id> questionIds = new Set<Id>();
            for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c = :sectionId]) questionIds.add(q.Id);

            Set<Id> responseIds = new Set<Id>();
            for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds]) responseIds.add(r.Id);

            stripCrossFieldRulesReferencingIds(sRecord.C_Page__r.C_Form__c, questionIds);

            delete [SELECT Id FROM C_Dependency__c WHERE C_Controlling_Response__c IN :responseIds
                    OR C_Target_Section__c = :sectionId OR C_Target_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Translation__c WHERE C_Section__c = :sectionId
                    OR C_Question__c IN :questionIds OR C_Response__c IN :responseIds];
            delete [SELECT Id FROM C_Field_Mapping__c WHERE C_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds];
            delete [SELECT Id FROM C_Question__c WHERE C_Section__c = :sectionId];
            delete new C_Section__c(Id = sectionId);

            pruneStaleCategoryTargetsIfEmpty(singletonCategorySet(sRecord.C_Page__r.C_Category__c));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<C_Question__c> getQuestions(Id sectionId) {
        try {
            return [SELECT Id, Name, C_Question_Text__c, C_Help_Text__c, C_Section__c, C_Order__c,
                           C_Type__c, C_Is_Required__c, C_Is_Disabled__c, C_Weight__c, C_Placeholder__c,
                           C_Max_Length__c, C_Max_Word_Count__c, C_Min_Value__c, C_Max_Value__c,
                           C_Table_Columns__c, C_Table_Min_Rows__c, C_Table_Max_Rows__c,
                           C_Accepted_File_Types__c, C_Max_Files__c, C_Max_File_Size_MB__c,
                           C_Validation_Pattern__c, C_Validation_Message__c,
                           C_Number_Decimal_Places__c, C_Layout_Span__c,
                           C_Cross_Field_Rules_JSON__c
                    FROM C_Question__c WHERE C_Section__c = :sectionId ORDER BY C_Order__c];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Question__c saveQuestion(C_Question__c question) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            upsert question;
            return question;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteQuestion(Id questionId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }

            C_Question__c qRecord = [
                SELECT Id, C_Section__r.C_Page__r.C_Category__c, C_Section__r.C_Page__r.C_Form__c
                FROM C_Question__c WHERE Id = :questionId LIMIT 1
            ];

            stripCrossFieldRulesReferencingIds(qRecord.C_Section__r.C_Page__r.C_Form__c, new Set<Id>{ questionId });

            Set<Id> responseIds = new Set<Id>();
            for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c = :questionId]) responseIds.add(r.Id);

            delete [SELECT Id FROM C_Dependency__c WHERE C_Controlling_Response__c IN :responseIds
                    OR C_Target_Question__c = :questionId];
            delete [SELECT Id FROM C_Translation__c WHERE C_Question__c = :questionId OR C_Response__c IN :responseIds];
            delete [SELECT Id FROM C_Field_Mapping__c WHERE C_Question__c = :questionId];
            delete [SELECT Id FROM C_Response__c WHERE C_Question__c = :questionId];
            delete new C_Question__c(Id = questionId);

            pruneStaleCategoryTargetsIfEmpty(singletonCategorySet(qRecord.C_Section__r.C_Page__r.C_Category__c));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<C_Response__c> getResponses(Id questionId) {
        try {
            return [SELECT Id, Name, C_Response_Text__c, C_Question__c, C_Order__c, C_Points__c,
                           C_Requires_Details__c, C_Locks_Question__c
                    FROM C_Response__c WHERE C_Question__c = :questionId ORDER BY C_Order__c];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Response__c saveResponse(C_Response__c response) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            upsert response;
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteResponse(Id responseId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            delete [SELECT Id FROM C_Dependency__c WHERE C_Controlling_Response__c = :responseId];
            delete [SELECT Id FROM C_Translation__c WHERE C_Response__c = :responseId];
            delete new C_Response__c(Id = responseId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<C_Dependency__c> getDependencies(Id formId) {
        try {
            Set<Id> pageIds = new Set<Id>();
            for (C_Page__c p : [SELECT Id FROM C_Page__c WHERE C_Form__c = :formId]) {
                pageIds.add(p.Id);
            }
            Set<Id> sectionIds = new Set<Id>();
            for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds]) {
                sectionIds.add(s.Id);
            }
            Set<Id> questionIds = new Set<Id>();
            for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds]) {
                questionIds.add(q.Id);
            }
            Set<Id> responseIds = new Set<Id>();
            for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds]) {
                responseIds.add(r.Id);
            }

            Set<Id> formCategoryIds = new Set<Id>();
            for (C_Category__c cat : [SELECT Id FROM C_Category__c WHERE C_Form__c IN (SELECT C_Form__c FROM C_Page__c WHERE Id IN :pageIds)]) {
                formCategoryIds.add(cat.Id);
            }

            return [SELECT Id, Name, C_Controlling_Response__c, C_Target_Type__c, C_Action__c,
                           C_Target_Category__c, C_Target_Page__c, C_Target_Section__c, C_Target_Question__c,
                           C_Logic_Group__c, C_Logic_Operator__c
                    FROM C_Dependency__c
                    WHERE C_Controlling_Response__c IN :responseIds
                       OR C_Target_Category__c IN :formCategoryIds
                       OR C_Target_Page__c IN :pageIds
                       OR C_Target_Section__c IN :sectionIds
                       OR C_Target_Question__c IN :questionIds];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Dependency__c saveDependency(C_Dependency__c dep) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            upsert dep;
            return dep;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteDependency(Id depId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            delete new C_Dependency__c(Id = depId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getFullFormStructure(Id formId) {
        try {
            Map<String, Object> result = new Map<String, Object>();

            C_Form__c form = [SELECT Id, Name, C_Description__c, C_Status__c, C_Version__c, C_Default_Language__c
                              FROM C_Form__c WHERE Id = :formId LIMIT 1];
            result.put('form', form);

            List<C_Category__c> categories = [
                SELECT Id, Name, C_Form__c, C_Order__c, C_Description__c, C_Icon__c, C_Is_Active__c
                FROM C_Category__c WHERE C_Form__c = :formId ORDER BY C_Order__c
            ];
            result.put('categories', categories);

            Set<Id> categoryIds = new Set<Id>();
            for (C_Category__c cat : categories) { categoryIds.add(cat.Id); }

            List<C_Page__c> pages = [SELECT Id, Name, C_Description__c, C_Order__c, C_Form__c, C_Category__c
                                     FROM C_Page__c WHERE C_Form__c = :formId ORDER BY C_Order__c];
            result.put('pages', pages);

            Map<Id, List<C_Page__c>> pagesByCategory = new Map<Id, List<C_Page__c>>();
            List<C_Page__c> uncategorizedPages = new List<C_Page__c>();
            for (C_Page__c p : pages) {
                Id catKey = p.C_Category__c;
                if (p.C_Category__c == null) {
                    uncategorizedPages.add(p);
                }
                if (!pagesByCategory.containsKey(catKey)) {
                    pagesByCategory.put(catKey, new List<C_Page__c>());
                }
                pagesByCategory.get(catKey).add(p);
            }
            result.put('pagesByCategory', pagesByCategory);
            result.put('uncategorizedPages', uncategorizedPages);

            Set<Id> pageIds = new Set<Id>();
            for (C_Page__c p : pages) { pageIds.add(p.Id); }

            List<C_Section__c> allSections = [
                SELECT Id, Name, C_Page__c, C_Order__c, C_Weight__c, C_Bonus__c, C_Excluded_From_Weight__c
                FROM C_Section__c WHERE C_Page__c IN :pageIds ORDER BY C_Order__c
            ];
            Map<Id, List<C_Section__c>> sectionsByPage = new Map<Id, List<C_Section__c>>();
            Set<Id> allSectionIds = new Set<Id>();
            for (C_Section__c s : allSections) {
                allSectionIds.add(s.Id);
                if (!sectionsByPage.containsKey(s.C_Page__c)) {
                    sectionsByPage.put(s.C_Page__c, new List<C_Section__c>());
                }
                sectionsByPage.get(s.C_Page__c).add(s);
            }
            result.put('sectionsByPage', sectionsByPage);

            List<C_Question__c> allQuestions = [
                SELECT Id, Name, C_Question_Text__c, C_Help_Text__c, C_Section__c, C_Order__c,
                       C_Type__c, C_Is_Required__c, C_Is_Disabled__c, C_Weight__c, C_Placeholder__c,
                       C_Max_Length__c, C_Max_Word_Count__c, C_Min_Value__c, C_Max_Value__c,
                       C_Table_Columns__c, C_Table_Min_Rows__c, C_Table_Max_Rows__c,
                       C_Accepted_File_Types__c, C_Max_Files__c, C_Max_File_Size_MB__c,
                       C_Validation_Pattern__c, C_Validation_Message__c,
                       C_Number_Decimal_Places__c, C_Layout_Span__c,
                       C_Cross_Field_Rules_JSON__c
                FROM C_Question__c WHERE C_Section__c IN :allSectionIds ORDER BY C_Order__c
            ];
            Map<Id, List<C_Question__c>> questionsBySection = new Map<Id, List<C_Question__c>>();
            Set<Id> allQuestionIds = new Set<Id>();
            for (C_Question__c q : allQuestions) {
                allQuestionIds.add(q.Id);
                if (!questionsBySection.containsKey(q.C_Section__c)) {
                    questionsBySection.put(q.C_Section__c, new List<C_Question__c>());
                }
                questionsBySection.get(q.C_Section__c).add(q);
            }
            result.put('questionsBySection', questionsBySection);

            List<C_Response__c> allResponses = [
                SELECT Id, Name, C_Response_Text__c, C_Question__c, C_Order__c, C_Points__c,
                       C_Requires_Details__c, C_Locks_Question__c
                FROM C_Response__c WHERE C_Question__c IN :allQuestionIds ORDER BY C_Order__c
            ];
            Map<Id, List<C_Response__c>> responsesByQuestion = new Map<Id, List<C_Response__c>>();
            Set<Id> allResponseIds = new Set<Id>();
            for (C_Response__c r : allResponses) {
                allResponseIds.add(r.Id);
                if (!responsesByQuestion.containsKey(r.C_Question__c)) {
                    responsesByQuestion.put(r.C_Question__c, new List<C_Response__c>());
                }
                responsesByQuestion.get(r.C_Question__c).add(r);
            }
            result.put('responsesByQuestion', responsesByQuestion);

            List<C_Dependency__c> deps = [
                SELECT Id, Name, C_Controlling_Response__c, C_Target_Type__c, C_Action__c,
                       C_Target_Category__c, C_Target_Page__c, C_Target_Section__c, C_Target_Question__c,
                       C_Logic_Group__c, C_Logic_Operator__c
                FROM C_Dependency__c
                WHERE C_Controlling_Response__c IN :allResponseIds
                   OR C_Target_Category__c IN :categoryIds
                   OR C_Target_Page__c IN :pageIds
                   OR C_Target_Section__c IN :allSectionIds
                   OR C_Target_Question__c IN :allQuestionIds
            ];
            result.put('dependencies', deps);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void reorderItems(String objectType, List<Map<String, Object>> items) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            List<SObject> toUpdate = new List<SObject>();
            for (Map<String, Object> item : items) {
                if (item.get('id') == null) {
                    throw new AuraHandledException('Missing required "id" in reorder item');
                }
                if (item.get('order') == null) {
                    throw new AuraHandledException('Missing required "order" in reorder item');
                }
                Id itemId = (Id) item.get('id');
                Integer newOrder = ((Decimal) item.get('order')).intValue();

                if (objectType == 'Category') {
                    toUpdate.add(new C_Category__c(Id = itemId, C_Order__c = newOrder));
                } else if (objectType == 'Page') {
                    toUpdate.add(new C_Page__c(Id = itemId, C_Order__c = newOrder));
                } else if (objectType == 'Section') {
                    toUpdate.add(new C_Section__c(Id = itemId, C_Order__c = newOrder));
                } else if (objectType == 'Question') {
                    toUpdate.add(new C_Question__c(Id = itemId, C_Order__c = newOrder));
                } else if (objectType == 'Response') {
                    toUpdate.add(new C_Response__c(Id = itemId, C_Order__c = newOrder));
                } else {
                    throw new AuraHandledException('Unknown object type: ' + objectType);
                }
            }
            update toUpdate;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void moveItem(String objectType, Id itemId, Id newParentId, Integer newPosition) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            List<SObject> toUpdate = new List<SObject>();

            if (objectType == 'Page') {
                C_Page__c page = [SELECT Id, C_Category__c, C_Order__c FROM C_Page__c WHERE Id = :itemId];
                Id oldParentId = page.C_Category__c;

                page.C_Category__c = newParentId;
                page.C_Order__c = newPosition;
                toUpdate.add(page);

                if (oldParentId != newParentId && oldParentId != null) {
                    Integer idx = 1;
                    for (C_Page__c p : [SELECT Id FROM C_Page__c WHERE C_Category__c = :oldParentId AND Id != :itemId ORDER BY C_Order__c]) {
                        toUpdate.add(new C_Page__c(Id = p.Id, C_Order__c = idx++));
                    }
                }

                Integer idx = 1;
                for (C_Page__c p : [SELECT Id FROM C_Page__c WHERE C_Category__c = :newParentId AND Id != :itemId ORDER BY C_Order__c]) {
                    if (idx >= newPosition) {
                        toUpdate.add(new C_Page__c(Id = p.Id, C_Order__c = idx + 1));
                    } else {
                        toUpdate.add(new C_Page__c(Id = p.Id, C_Order__c = idx));
                    }
                    idx++;
                }

            } else if (objectType == 'Section') {
                C_Section__c section = [SELECT Id, C_Page__c, C_Order__c FROM C_Section__c WHERE Id = :itemId];
                Id oldParentId = section.C_Page__c;

                section.C_Page__c = newParentId;
                section.C_Order__c = newPosition;
                toUpdate.add(section);

                if (oldParentId != newParentId) {
                    Integer idx = 1;
                    for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c = :oldParentId AND Id != :itemId ORDER BY C_Order__c]) {
                        toUpdate.add(new C_Section__c(Id = s.Id, C_Order__c = idx++));
                    }
                }

                Integer idx = 1;
                for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c = :newParentId AND Id != :itemId ORDER BY C_Order__c]) {
                    if (idx >= newPosition) {
                        toUpdate.add(new C_Section__c(Id = s.Id, C_Order__c = idx + 1));
                    } else {
                        toUpdate.add(new C_Section__c(Id = s.Id, C_Order__c = idx));
                    }
                    idx++;
                }

            } else if (objectType == 'Question') {
                C_Question__c question = [SELECT Id, C_Section__c, C_Order__c FROM C_Question__c WHERE Id = :itemId];
                Id oldParentId = question.C_Section__c;

                question.C_Section__c = newParentId;
                question.C_Order__c = newPosition;
                toUpdate.add(question);

                if (oldParentId != newParentId) {
                    Integer idx = 1;
                    for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c = :oldParentId AND Id != :itemId ORDER BY C_Order__c]) {
                        toUpdate.add(new C_Question__c(Id = q.Id, C_Order__c = idx++));
                    }
                }

                Integer idx = 1;
                for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c = :newParentId AND Id != :itemId ORDER BY C_Order__c]) {
                    if (idx >= newPosition) {
                        toUpdate.add(new C_Question__c(Id = q.Id, C_Order__c = idx + 1));
                    } else {
                        toUpdate.add(new C_Question__c(Id = q.Id, C_Order__c = idx));
                    }
                    idx++;
                }

            } else if (objectType == 'Response') {
                C_Response__c response = [SELECT Id, Name, C_Question__c, C_Order__c, C_Response_Text__c,
                                                 C_Points__c, C_Requires_Details__c, C_Locks_Question__c
                                          FROM C_Response__c WHERE Id = :itemId];
                Id oldParentId = response.C_Question__c;

                if (oldParentId != newParentId) {
                    C_Response__c newResp = new C_Response__c(
                        Name = response.Name,
                        C_Question__c = newParentId,
                        C_Order__c = newPosition,
                        C_Response_Text__c = response.C_Response_Text__c,
                        C_Points__c = response.C_Points__c,
                        C_Requires_Details__c = response.C_Requires_Details__c,
                        C_Locks_Question__c = response.C_Locks_Question__c
                    );
                    insert newResp;

                    List<C_Dependency__c> depsToRemap = [SELECT Id, C_Controlling_Response__c FROM C_Dependency__c WHERE C_Controlling_Response__c = :response.Id];
                    for (C_Dependency__c d : depsToRemap) d.C_Controlling_Response__c = newResp.Id;
                    if (!depsToRemap.isEmpty()) update depsToRemap;

                    List<C_Translation__c> transToRemap = [SELECT Id, C_Response__c FROM C_Translation__c WHERE C_Response__c = :response.Id];
                    for (C_Translation__c t : transToRemap) t.C_Response__c = newResp.Id;
                    if (!transToRemap.isEmpty()) update transToRemap;

                    delete response;

                    Integer ridx = 1;
                    for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c = :oldParentId ORDER BY C_Order__c]) {
                        toUpdate.add(new C_Response__c(Id = r.Id, C_Order__c = ridx++));
                    }
                    ridx = 1;
                    for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c = :newParentId ORDER BY C_Order__c]) {
                        toUpdate.add(new C_Response__c(Id = r.Id, C_Order__c = ridx++));
                    }
                } else {
                    response.C_Order__c = newPosition;
                    toUpdate.add(response);
                    Integer ridx = 1;
                    for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c = :newParentId AND Id != :itemId ORDER BY C_Order__c]) {
                        if (ridx >= newPosition) {
                            toUpdate.add(new C_Response__c(Id = r.Id, C_Order__c = ridx + 1));
                        } else {
                            toUpdate.add(new C_Response__c(Id = r.Id, C_Order__c = ridx));
                        }
                        ridx++;
                    }
                }
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id cloneForm(Id formId, String newFormName) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) { throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.'); }
            CloneFormAction.FlowInputs input = new CloneFormAction.FlowInputs();
            input.formId = formId;
            input.formName = newFormName;
            List<Id> clonedIds = CloneFormAction.cloneForm(new List<CloneFormAction.FlowInputs>{ input });
            return (clonedIds != null && !clonedIds.isEmpty()) ? clonedIds[0] : null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Set<Id> getSectionIdsForForm(Id formId) {
        Set<Id> sectionIds = new Set<Id>();
        if (formId == null) {
            return sectionIds;
        }
        Set<Id> pageIds = new Set<Id>();
        for (C_Page__c p : [SELECT Id FROM C_Page__c WHERE C_Form__c = :formId]) {
            pageIds.add(p.Id);
        }
        for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds]) {
            sectionIds.add(s.Id);
        }
        return sectionIds;
    }

    /**
     * Removes cross-field rule entries whose refQuestionId points at a question being deleted.
     * Survivors in the same form are updated before the delete DML runs.
     */
    private static void stripCrossFieldRulesReferencingIds(Id formId, Set<Id> removedQuestionIds) {
        if (formId == null || removedQuestionIds == null || removedQuestionIds.isEmpty()) {
            return;
        }
        Set<Id> sectionIds = getSectionIdsForForm(formId);
        if (sectionIds.isEmpty()) {
            return;
        }

        // Long Text Area cannot be filtered in SOQL; filter blanks in Apex.
        List<C_Question__c> candidates = [
            SELECT Id, C_Cross_Field_Rules_JSON__c
            FROM C_Question__c
            WHERE C_Section__c IN :sectionIds
              AND Id NOT IN :removedQuestionIds
        ];

        List<C_Question__c> toUpdate = new List<C_Question__c>();
        for (C_Question__c q : candidates) {
            String raw = q.C_Cross_Field_Rules_JSON__c;
            if (String.isBlank(raw)) {
                continue;
            }
            Object parsed;
            try {
                parsed = JSON.deserializeUntyped(raw);
            } catch (Exception e) {
                continue;
            }
            if (!(parsed instanceof List<Object>)) {
                continue;
            }
            List<Object> rules = (List<Object>) parsed;
            List<Object> kept = new List<Object>();
            for (Object o : rules) {
                if (!(o instanceof Map<String, Object>)) {
                    kept.add(o);
                    continue;
                }
                Map<String, Object> rule = (Map<String, Object>) o;
                Object refObj = rule.get('refQuestionId');
                if (refObj == null) {
                    kept.add(o);
                    continue;
                }
                Id refQId;
                try {
                    refQId = (Id) String.valueOf(refObj);
                } catch (Exception e) {
                    kept.add(o);
                    continue;
                }
                if (removedQuestionIds.contains(refQId)) {
                    continue;
                }
                kept.add(o);
            }
            if (kept.size() == rules.size()) {
                continue;
            }
            C_Question__c upd = new C_Question__c(Id = q.Id);
            if (kept.isEmpty()) {
                upd.C_Cross_Field_Rules_JSON__c = null;
            } else {
                upd.C_Cross_Field_Rules_JSON__c = JSON.serialize(kept);
            }
            toUpdate.add(upd);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    /**
     * Builds a single-element category set for prune helpers (skips null uncategorized pages).
     */
    private static Set<Id> singletonCategorySet(Id categoryId) {
        Set<Id> ids = new Set<Id>();
        if (categoryId != null) {
            ids.add(categoryId);
        }
        return ids;
    }

    /**
     * Deletes C_Dependency__c records whose C_Target_Category__c points to a category
     * in {@code categoryIds} that no longer has any questions under its pages.
     * Uses one SOQL to detect remaining questions; callers pass only categories affected by the delete.
     */
    private static void pruneStaleCategoryTargetsIfEmpty(Set<Id> categoryIds) {
        if (categoryIds == null || categoryIds.isEmpty()) {
            return;
        }
        Set<Id> toCheck = new Set<Id>(categoryIds);
        toCheck.remove(null);
        if (toCheck.isEmpty()) {
            return;
        }

        Set<Id> categoriesStillWithQuestions = new Set<Id>();
        for (C_Question__c q : [
            SELECT C_Section__r.C_Page__r.C_Category__c
            FROM C_Question__c
            WHERE C_Section__r.C_Page__r.C_Category__c IN :toCheck
        ]) {
            if (q.C_Section__r != null && q.C_Section__r.C_Page__r != null
                    && q.C_Section__r.C_Page__r.C_Category__c != null) {
                categoriesStillWithQuestions.add(q.C_Section__r.C_Page__r.C_Category__c);
            }
        }

        Set<Id> emptyCategoryIds = new Set<Id>(toCheck);
        emptyCategoryIds.removeAll(categoriesStillWithQuestions);
        if (!emptyCategoryIds.isEmpty()) {
            delete [SELECT Id FROM C_Dependency__c WHERE C_Target_Category__c IN :emptyCategoryIds];
        }
    }
}
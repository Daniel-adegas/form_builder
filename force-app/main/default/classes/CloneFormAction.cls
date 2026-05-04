/**
 * @description       : Invocable action to deep clone a form with all related records
 * @author            : Daniel Murracas
 * @last modified on  : 17-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   17-03-2026   Daniel Murracas     Clone Form Targets, Field Mappings, Translations
 * ------------------------------------------------------------
**/
public with sharing class CloneFormAction {
    
    public class CloneFormException extends Exception {}

    @InvocableMethod(label='Clone Form' description='Clone the form and all related objects')
    public static List<Id> cloneForm(List<FlowInputs> request) {
        if (!FeatureUtil.isFormBuilderAdmin()) {
            throw new CloneFormException('Insufficient permissions. Forms_Admin permission set required.');
        }
        if (request.size() == 0) throw new CloneFormException('Parameters invalid');
        
        Id formId = request[0].formId;
        String newFormName = request[0].formName;
        
        if (formId == null || newFormName == null) throw new CloneFormException('Parameters invalid');
        
        List<C_Form__c> existingForm = [
            SELECT Id, Name, C_Status__c 
            FROM C_Form__c 
            WHERE Id = :formId
        ];
        
        if (existingForm.size() == 0) throw new CloneFormException('No existing form found for the input');
        
        C_Form__c newForm = existingForm[0].clone(false, false, false, false);
        newForm.Name = newFormName;
        newForm.C_Status__c = 'Draft';
        String currentSearchName;
        insert newForm;
        
        // Clone Categories
        List<C_Category__c> existingCategories = [
            SELECT Id, Name, C_Form__c, C_Order__c, C_Description__c, C_Icon__c, C_Is_Active__c
            FROM C_Category__c
            WHERE C_Form__c = :existingForm[0].Id
        ];

        Map<Id, C_Category__c> oldIdNewCategory = new Map<Id, C_Category__c>();
        List<C_Category__c> newCategories = new List<C_Category__c>();
        for (C_Category__c cat : existingCategories) {
            C_Category__c newCat = cat.clone(false, false, false, false);
            newCat.C_Form__c = newForm.Id;
            newCategories.add(newCat);
            oldIdNewCategory.put(cat.Id, newCat);
        }
        if (!newCategories.isEmpty()) {
            insert newCategories;
        }

        List<C_Page__c> existingPages = [
            SELECT Id, C_Form__c, Name, C_Order__c, C_Description__c, C_Category__c
            FROM C_Page__c 
            WHERE C_Form__c = :existingForm[0].Id
        ];
        
        List<C_Page__c> newPages = new List<C_Page__c>();
        Map<Id, C_Page__c> oldIdNewPage = new Map<Id, C_Page__c>();
        
        for (C_Page__c page : existingPages) {
            C_Page__c newPage = page.clone(false, false, false, false);
            newPage.C_Form__c = newForm.Id;
            if (page.C_Category__c != null && oldIdNewCategory.containsKey(page.C_Category__c)) {
                newPage.C_Category__c = oldIdNewCategory.get(page.C_Category__c).Id;
            }
            newPages.add(newPage);
            oldIdNewPage.put(page.Id, newPage);
        }
        insert newPages;
        
        List<C_Section__c> existingSections = [
            SELECT Id, C_Page__c, Name, C_Bonus__c, C_Order__c, C_Weight__c 
            FROM C_Section__c 
            WHERE C_Page__c IN :(new Map<Id, C_Page__c>(existingPages)).keySet()
        ];
        
        List<C_Section__c> newSections = new List<C_Section__c>();
        Map<Id, C_Section__c> oldIdNewSection = new Map<Id, C_Section__c>();
        
        for (C_Section__c section : existingSections) {
            C_Section__c newSection = section.clone(false, false, false, false);
            newSection.C_Page__c = oldIdNewPage.get(section.C_Page__c).Id;
            newSections.add(newSection);
            oldIdNewSection.put(section.Id, newSection);
        }
        insert newSections;
    
        Map<Id, C_Question__c> oldIdNewQuestion = new Map<Id, C_Question__c>();
        List<C_Question__c> oldQuestions = [
            SELECT Id, C_Section__c, Name, C_Weight__c, C_Type__c,
                   C_Question_Text__c, C_Help_Text__c, C_Order__c,
                   C_Accepted_File_Types__c, C_Table_Columns__c, C_Is_Required__c,
                   C_Validation_Message__c, C_Validation_Pattern__c, C_Placeholder__c,
                   C_Max_Length__c, C_Max_Word_Count__c, C_Min_Value__c, C_Max_Value__c,
                   C_Table_Min_Rows__c, C_Table_Max_Rows__c,
                   C_Max_Files__c, C_Max_File_Size_MB__c, C_Search_Name__c,
                   C_Cross_Field_Rules_JSON__c
            FROM C_Question__c 
            WHERE C_Section__c IN :(new Map<Id, C_Section__c>(existingSections)).keySet()
        ];
        
        for (C_Question__c question : oldQuestions) {
            C_Question__c newQuestion = question.clone(false, false, false, false);
            newQuestion.C_Section__c = oldIdNewSection.get(question.C_Section__c).Id;
            currentSearchName = newForm.Name + ' ' + newQuestion.Name;
            newQuestion.C_Search_Name__c = (currentSearchName.length() <= 255) ? currentSearchName : currentSearchName.left(255);
            oldIdNewQuestion.put(question.Id, newQuestion);
        }
        insert (oldIdNewQuestion.values());

        Map<Id, C_Response__c> oldIdNewResponse = new Map<Id, C_Response__c>();
        List<C_Response__c> oldResponses = [
            SELECT Id, C_Question__c, Name, C_Response_Text__c, C_Points__c, C_Order__c, 
                   C_Locks_Question__c, C_Requires_Details__c, C_Search_Name__c
            FROM C_Response__c 
            WHERE C_Question__c IN :(new Map<Id, C_Question__c>(oldQuestions)).keySet()
        ];
        
        for (C_Response__c response : oldResponses) {
            C_Response__c newResponse = response.clone(false, false, false, false);
            newResponse.C_Question__c = oldIdNewQuestion.get(response.C_Question__c).Id;
            String questionSearchName = oldIdNewQuestion.get(response.C_Question__c).C_Search_Name__c;
            currentSearchName = questionSearchName + ' ' + response.Name;
            newResponse.C_Search_Name__c = (currentSearchName.length() <= 255) ? currentSearchName : currentSearchName.left(255);
            oldIdNewResponse.put(response.Id, newResponse);
        }
        insert (oldIdNewResponse.values());

        List<C_Dependency__c> oldDependencies = [
            SELECT Id, C_Controlling_Response__c, C_Target_Type__c,
                   C_Target_Category__c, C_Target_Page__c, C_Target_Section__c, C_Target_Question__c, 
                   C_Action__c, C_Logic_Group__c, C_Logic_Operator__c
            FROM C_Dependency__c 
            WHERE C_Controlling_Response__c IN :(new Map<Id, C_Response__c>(oldResponses)).keySet()
        ];

        List<C_Dependency__c> newDependencies = new List<C_Dependency__c>();
        for (C_Dependency__c dependency : oldDependencies) {
            C_Dependency__c newDependency = dependency.clone(false, false, false, false);
            
            C_Response__c mappedResp = dependency.C_Controlling_Response__c == null ? null : oldIdNewResponse.get(dependency.C_Controlling_Response__c);
            newDependency.C_Controlling_Response__c = mappedResp != null ? mappedResp.Id : null;

            C_Category__c mappedCategory = dependency.C_Target_Category__c == null ? null : oldIdNewCategory.get(dependency.C_Target_Category__c);
            newDependency.C_Target_Category__c = mappedCategory != null ? mappedCategory.Id : null;
            
            C_Page__c mappedPage = dependency.C_Target_Page__c == null ? null : oldIdNewPage.get(dependency.C_Target_Page__c);
            newDependency.C_Target_Page__c = mappedPage != null ? mappedPage.Id : null;
            
            C_Section__c mappedSection = dependency.C_Target_Section__c == null ? null : oldIdNewSection.get(dependency.C_Target_Section__c);
            newDependency.C_Target_Section__c = mappedSection != null ? mappedSection.Id : null;
            
            C_Question__c mappedQuestion = dependency.C_Target_Question__c == null ? null : oldIdNewQuestion.get(dependency.C_Target_Question__c);
            newDependency.C_Target_Question__c = mappedQuestion != null ? mappedQuestion.Id : null;
            
            if (newDependency.C_Controlling_Response__c != null) {
                newDependencies.add(newDependency);
            }
        }
        insert newDependencies;

        // Clone Form Targets
        List<C_Form_Target__c> oldTargets = [
            SELECT Id, C_Form__c, C_Target_Object__c, C_Resolution_Type__c,
                   C_Record_Operation__c, C_Order__c, C_Is_Active__c,
                   C_External_Id_Field__c, C_Description__c
            FROM C_Form_Target__c
            WHERE C_Form__c = :formId
        ];

        Map<Id, C_Form_Target__c> oldIdNewTarget = new Map<Id, C_Form_Target__c>();
        for (C_Form_Target__c target : oldTargets) {
            C_Form_Target__c newTarget = target.clone(false, false, false, false);
            newTarget.C_Form__c = newForm.Id;
            oldIdNewTarget.put(target.Id, newTarget);
        }
        if (!oldIdNewTarget.isEmpty()) {
            insert oldIdNewTarget.values();
        }

        // Clone Field Mappings
        Set<Id> oldQuestionIds = (new Map<Id, C_Question__c>(oldQuestions)).keySet();
        List<C_Field_Mapping__c> oldMappings = [
            SELECT Id, C_Form_Target__c, C_Question__c, C_Target_Object__c,
                   C_Target_Field__c, C_Mapping_Type__c, C_Static_Value__c,
                   C_Record_Source__c, C_Record_Operation__c, C_Is_Active__c,
                   C_External_Id_Field__c
            FROM C_Field_Mapping__c
            WHERE C_Question__c IN :oldQuestionIds
        ];

        List<C_Field_Mapping__c> newMappings = new List<C_Field_Mapping__c>();
        for (C_Field_Mapping__c mapping : oldMappings) {
            C_Field_Mapping__c newMapping = mapping.clone(false, false, false, false);
            C_Question__c mappedQ = mapping.C_Question__c == null ? null : oldIdNewQuestion.get(mapping.C_Question__c);
            newMapping.C_Question__c = mappedQ != null ? mappedQ.Id : null;
            C_Form_Target__c mappedT = mapping.C_Form_Target__c == null ? null : oldIdNewTarget.get(mapping.C_Form_Target__c);
            newMapping.C_Form_Target__c = mappedT != null ? mappedT.Id : null;
            newMappings.add(newMapping);
        }
        if (!newMappings.isEmpty()) {
            insert newMappings;
        }

        // Clone Translations
        Set<Id> oldCategoryIds = oldIdNewCategory.keySet();
        Set<Id> oldPageIds = (new Map<Id, C_Page__c>(existingPages)).keySet();
        Set<Id> oldSectionIds = (new Map<Id, C_Section__c>(existingSections)).keySet();
        Set<Id> oldResponseIds = (new Map<Id, C_Response__c>(oldResponses)).keySet();
        List<C_Translation__c> oldTranslations = [
            SELECT Id, C_Category__c, C_Page__c, C_Section__c, C_Question__c, C_Response__c,
                   C_Language__c, C_Translated_Text__c, C_Field_Name__c, RecordTypeId
            FROM C_Translation__c
            WHERE C_Category__c IN :oldCategoryIds
               OR C_Page__c IN :oldPageIds
               OR C_Section__c IN :oldSectionIds
               OR C_Question__c IN :oldQuestionIds
               OR C_Response__c IN :oldResponseIds
        ];

        List<C_Translation__c> newTranslations = new List<C_Translation__c>();
        for (C_Translation__c trans : oldTranslations) {
            C_Translation__c newTrans = trans.clone(false, false, false, false);
            if (trans.C_Category__c != null) {
                C_Category__c mc = oldIdNewCategory.get(trans.C_Category__c);
                newTrans.C_Category__c = mc != null ? mc.Id : null;
            }
            if (trans.C_Page__c != null) {
                C_Page__c mp = oldIdNewPage.get(trans.C_Page__c);
                newTrans.C_Page__c = mp != null ? mp.Id : null;
            }
            if (trans.C_Section__c != null) {
                C_Section__c ms = oldIdNewSection.get(trans.C_Section__c);
                newTrans.C_Section__c = ms != null ? ms.Id : null;
            }
            if (trans.C_Question__c != null) {
                C_Question__c mq = oldIdNewQuestion.get(trans.C_Question__c);
                newTrans.C_Question__c = mq != null ? mq.Id : null;
            }
            if (trans.C_Response__c != null) {
                C_Response__c mr = oldIdNewResponse.get(trans.C_Response__c);
                newTrans.C_Response__c = mr != null ? mr.Id : null;
            }
            newTranslations.add(newTrans);
        }
        if (!newTranslations.isEmpty()) {
            insert newTranslations;
        }

        return new List<Id>{ newForm.Id };
    }
    
    public class FlowInputs {
        @InvocableVariable
        public Id formId;
        
        @InvocableVariable
        public String formName;
    }
}
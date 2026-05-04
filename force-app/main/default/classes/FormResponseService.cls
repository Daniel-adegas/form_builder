/**
 * @description       : Service class for processing and saving form responses from JSON
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
public with sharing class FormResponseService {
    
    @InvocableMethod(label='Process Form Responses' description='Processes and saves form responses from JSON data')
    public static List<FormSubmissionInfo> saveFormResponses(List<FormSubmissionInfo> parameters) {
        return new ResponseProcessor().process(parameters);
    }

    private without sharing class ResponseProcessor {
        public List<FormSubmissionInfo> process(List<FormSubmissionInfo> parameters) {
        for (FormSubmissionInfo param : parameters) {
            Map<Id, Map<Id, String>> responseBySectionId = getResponses(param.json);

            Map<Id, C_Section__c> sections = new Map<Id, C_Section__c>([
                SELECT Id, Name, C_Weight__c, C_Bonus__c, C_Order__c, C_Excluded_From_Weight__c 
                FROM C_Section__c 
                WHERE Id = :responseBySectionId.keySet()
            ]);
            
            List<C_Section_Response__c> existingSectionResponses = [
                SELECT Id, C_Section__c, C_Order__c, C_Excluded_From_Weight__c 
                FROM C_Section_Response__c 
                WHERE C_Section__c = :sections.keySet() 
                AND C_Form_Submission__c = :param.formSubmissionId
            ];
            
            List<C_Section_Response__c> sectionResponses = new List<C_Section_Response__c>();

            for (C_Section__c section : sections.values()) {
                C_Section_Response__c sectionResponse = new C_Section_Response__c();

                for (C_Section_Response__c existing : existingSectionResponses) {
                    if (existing.C_Section__c == section.Id) {
                        sectionResponse.Id = existing.Id;
                        break;
                    }
                }
 
                sectionResponse.Name = section.Name;
                sectionResponse.C_Section_Name__c = section.Name;
                sectionResponse.C_Weight__c = section.C_Weight__c;
                if (sectionResponse.Id == null) {
                    sectionResponse.C_Form_Submission__c = param.formSubmissionId;
                }
                sectionResponse.C_Bonus__c = section.C_Bonus__c;
                sectionResponse.C_Section__c = section.Id;
                sectionResponse.C_Order__c = section.C_Order__c;
                sectionResponse.C_Excluded_From_Weight__c = section.C_Excluded_From_Weight__c;
                sectionResponses.add(sectionResponse);
            }

            upsert sectionResponses;
            saveQuestionResponses(responseBySectionId, sectionResponses, param.formSubmissionId);
        }
        
        return new List<FormSubmissionInfo>();
    }

    private void saveQuestionResponses(
        Map<Id, Map<Id, String>> responseBySectionId, 
        List<C_Section_Response__c> sectionResponses, 
        Id formSubmissionId
    ) {
        List<Id> sectionResponseIds = new List<Id>();
        for (C_Section_Response__c secResp : sectionResponses) {
            sectionResponseIds.add(secResp.Id);
        }

        Set<Id> allResponseIds = new Set<Id>();
        for (String sectionId : responseBySectionId.keySet()) {
            for (String respId : responseBySectionId.get(sectionId).keySet()) {
                allResponseIds.add(respId);
            }
        }

        Map<Id, C_Response__c> allResponses = new Map<Id, C_Response__c>([
            SELECT Id, C_Points__c, C_Locks_Question__c, C_Question__c, C_Question__r.C_Weight__c, 
                   C_Question__r.C_Question_Text__c, C_Question__r.C_Type__c,
                   C_Response_Text__c, C_Question__r.C_Section__r.Id 
            FROM C_Response__c 
            WHERE Id = :allResponseIds
        ]);

        List<C_Question_Response__c> existingQuestionResponses = [
            SELECT Id, C_Response__c, C_Section_Response__c 
            FROM C_Question_Response__c 
            WHERE C_Response__c = :allResponses.keySet() 
            AND C_Section_Response__c = :sectionResponseIds
        ];
        
        Map<Id, Set<Id>> responseIdsBySection = new Map<Id, Set<Id>>();
        for (String sectionId : responseBySectionId.keySet()) {
            Set<Id> sectionRespIds = new Set<Id>();
            for (String respId : responseBySectionId.get(sectionId).keySet()) {
                sectionRespIds.add(respId);
            }
            responseIdsBySection.put(sectionId, sectionRespIds);
        }

        Map<Id, Id> existingResponseMap = new Map<Id, Id>();
        for (C_Question_Response__c existing : existingQuestionResponses) {
            existingResponseMap.put(existing.C_Response__c, existing.Id);
        }

        Map<Id, Id> sectionResponseIdBySectionId = new Map<Id, Id>();
        for (C_Section_Response__c secResp : sectionResponses) {
            sectionResponseIdBySectionId.put(secResp.C_Section__c, secResp.Id);
        }

        List<C_Question_Response__c> questionResponses = new List<C_Question_Response__c>();

        for (String sectionKey : responseBySectionId.keySet()) {
            Set<Id> sectionSpecificResponseIds = responseIdsBySection.get(sectionKey);
            if (sectionSpecificResponseIds == null) continue;

            for (Id responseId : sectionSpecificResponseIds) {
                C_Question_Response__c questionResponse = new C_Question_Response__c();

                if (existingResponseMap.containsKey(responseId)) {
                    questionResponse.Id = existingResponseMap.get(responseId);
                }

                C_Response__c resp = allResponses.get(responseId);
                if (resp != null && resp.C_Question__r.C_Section__r.Id == sectionKey) {
                    if (questionResponse.Id == null) {
                        questionResponse.C_Section_Response__c = sectionResponseIdBySectionId.get(sectionKey);
                    }
                    questionResponse.C_Response__c = resp.Id;
                    questionResponse.C_Question__c = resp.C_Question__c;
                    questionResponse.C_Response_Details__c = responseBySectionId.get(sectionKey).get(resp.Id);
                    questionResponse.C_Response_Points__c = resp.C_Points__c;
                    questionResponse.C_Response_Text__c = resp.C_Response_Text__c;
                    questionResponse.C_Question_Text__c = resp.C_Question__r.C_Question_Text__c;
                    questionResponse.C_Question_Type__c = resp.C_Question__r.C_Type__c;
                    if (resp.C_Locks_Question__c == true) {
                        questionResponse.C_Question_Weight__c = 0;
                    } else {
                        questionResponse.C_Question_Weight__c = resp.C_Question__r.C_Weight__c;
                    }
                    questionResponses.add(questionResponse);
                }
            }
        }

        List<Database.UpsertResult> results = Database.upsert(questionResponses, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Question Response upsert failed: ' + err.getMessage() + ' Fields: ' + err.getFields());
                }
            }
        }
        
        List<C_Form_Submission__c> submissionToUpdate = [
            SELECT Id, C_Status__c 
            FROM C_Form_Submission__c 
            WHERE Id = :formSubmissionId 
            LIMIT 1
        ];
        submissionToUpdate.get(0).C_Status__c = 'Validated';
        update submissionToUpdate;
    }
    } // end ResponseProcessor

    private static Map<Id, Map<Id, String>> getResponses(String json) {
        ResponseWrapper.MainWrapper mw = (ResponseWrapper.MainWrapper) System.JSON.deserialize(
            '{"sections":' + json + '}', 
            ResponseWrapper.MainWrapper.class
        );
        
        Map<Id, Map<Id, String>> responseBySectionId = new Map<Id, Map<Id, String>>();
        
        for (ResponseWrapper.ResponseSectionWrapper rsw : mw.sections) {
            String sectionId = rsw.sectionId;
            Map<Id, String> responsesIdText = new Map<Id, String>();
            
            if (rsw.hidden == false) { 
                for (ResponseWrapper.ResponseQuestionWrapper rqw : rsw.questions) {
                    if (rqw.hidden == false && rqw.value != null) {
                        if (responseBySectionId.keySet().contains(sectionId)) {
                            responsesIdText = responseBySectionId.get(sectionId);
                        }
                        responsesIdText.put(rqw.value, rqw.textValue);
                        responseBySectionId.put(sectionId, responsesIdText);
                    }
                }
            }
        }
        return responseBySectionId;
    }

    public class FormSubmissionInfo {
        @InvocableVariable 
        public String json;

        @InvocableVariable 
        public Id formSubmissionId;
    }
}

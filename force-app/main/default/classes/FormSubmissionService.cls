/**
 * @description       : Service class for creating, retrieving, draft-saving, and submitting form submissions.
 *                      Handles full submit orchestration: response record creation, scoring, and field mapping.
 * @author            : Daniel Murracas
 * @last modified on  : 19-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   18-03-2026   Daniel Murracas     Added draft/resume/submit, error handling
 * 2.0   19-03-2026   Daniel Murracas     Full submit orchestration: create response records, scoring, field mapping
 * ------------------------------------------------------------
**/
public with sharing class FormSubmissionService {
  
    public static String insertFormSubmission(String recordId) {
        return insertFormSubmission(recordId, null);
    }

    @AuraEnabled
    public static String insertFormSubmission(String recordId, Id formId) {
        try {
            C_Form_Submission__c formSubmission = new C_Form_Submission__c();
            formSubmission.Name = 'Form Submission';
            formSubmission.C_Status__c = 'In Progress';
            if (formId != null) {
                formSubmission.C_Form__c = formId;
            }
            
            if (String.isNotBlank(recordId)) {
                Id recId = (Id) recordId;
                if (recId.getSobjectType() == Schema.Account.getSObjectType()) {
                    formSubmission.C_Account__c = recordId;
                } else if (recId.getSobjectType() == Schema.Lead.getSObjectType()) {
                    formSubmission.C_Lead__c = recordId;
                } else if (recId.getSobjectType() == Schema.Contact.getSObjectType()) {
                    formSubmission.C_Contact__c = recordId;
                }
            }
            
            insert formSubmission;
            return formSubmission.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, String> getOrCreateSubmission(Id formId, String recordContextJson) {
        try {
            Map<String, String> result = new Map<String, String>();

            List<C_Form_Submission__c> drafts = [
                SELECT Id, C_Draft_State_JSON__c, C_Status__c, C_Record_Context_JSON__c
                FROM C_Form_Submission__c
                WHERE C_Form__c = :formId
                AND C_Status__c = 'Draft'
                AND OwnerId = :UserInfo.getUserId()
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];

            if (!drafts.isEmpty()) {
                if (String.isNotBlank(recordContextJson) && String.isBlank(drafts[0].C_Record_Context_JSON__c)) {
                    drafts[0].C_Record_Context_JSON__c = recordContextJson;
                    update drafts[0];
                }
                result.put('submissionId', drafts[0].Id);
                result.put('draftJson', drafts[0].C_Draft_State_JSON__c);
                result.put('isResume', 'true');
                return result;
            }

            C_Form_Submission__c submission = new C_Form_Submission__c();
            submission.Name = 'Form Submission';
            submission.C_Form__c = formId;
            submission.C_Status__c = 'Draft';

            if (String.isNotBlank(recordContextJson)) {
                submission.C_Record_Context_JSON__c = recordContextJson;
                String contextId = extractDefaultContextId(recordContextJson);
                if (String.isNotBlank(contextId)) {
                    try {
                        Id recId = (Id) contextId;
                        if (recId.getSobjectType() == Schema.Account.getSObjectType()) {
                            submission.C_Account__c = contextId;
                        } else if (recId.getSobjectType() == Schema.Lead.getSObjectType()) {
                            submission.C_Lead__c = contextId;
                        } else if (recId.getSobjectType() == Schema.Contact.getSObjectType()) {
                            submission.C_Contact__c = contextId;
                        }
                        submission.C_Record_Id__c = contextId;
                    } catch (Exception ex) { /* not a valid ID, skip */ }
                }
            }

            insert submission;
            result.put('submissionId', submission.Id);
            result.put('draftJson', null);
            result.put('isResume', 'false');
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String extractDefaultContextId(String recordContextJson) {
        if (String.isBlank(recordContextJson)) return null;
        if (!recordContextJson.trim().startsWith('{')) return recordContextJson.trim();
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(recordContextJson);
            if (parsed.size() == 1) {
                return String.valueOf(parsed.values()[0]);
            }
        } catch (Exception e) { /* not valid JSON */ }
        return null;
    }

    @AuraEnabled
    public static void saveDraftState(Id submissionId, String draftJson) {
        try {
            C_Form_Submission__c submission = new C_Form_Submission__c(
                Id = submissionId,
                C_Draft_State_JSON__c = draftJson,
                C_Status__c = 'Draft'
            );
            update submission;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Full submit orchestration:
     * 1. Read the draft JSON from the submission
     * 2. Load the form structure (sections, questions, responses)
     * 3. Create C_Section_Response__c and C_Question_Response__c records
     * 4. Calculate scoring via ScoringService
     * 5. Execute field mappings via FieldMappingService
     * 6. Update submission status to Submitted
     *
     * Steps 3-5 are gated behind the C_Enable_Response_Records__c hierarchy custom setting.
     * When disabled, the submission is recorded but ScoringService and FieldMappingService
     * are skipped because both read from the response records that step 3 produces; running
     * them against missing data would silently write 0 / no outbound mappings.
     */
    @AuraEnabled
    public static void submitForm(Id submissionId) {
        try {
            List<C_Form_Submission__c> submissions = [
                SELECT Id, C_Form__c, C_Draft_State_JSON__c, C_Account__c, C_Lead__c, C_Contact__c
                FROM C_Form_Submission__c
                WHERE Id = :submissionId
                LIMIT 1
            ];
            if (submissions.isEmpty()) {
                throw new AuraHandledException('Submission not found: ' + submissionId);
            }
            C_Form_Submission__c submission = submissions[0];

            Map<String, Boolean> features = FeatureSettingsService.getFeatureSettings();
            Boolean responseRecordsEnabled = features.get('responseRecords') == true;

            List<String> processingErrors = new List<String>();

            if (responseRecordsEnabled) {
                if (String.isNotBlank(submission.C_Draft_State_JSON__c)) {
                    createResponseRecords(submission);
                }

                try {
                    ScoringService.calculateSubmissionScore(submissionId);
                } catch (Exception scoringEx) {
                    processingErrors.add('Scoring: ' + scoringEx.getMessage());
                    System.debug(LoggingLevel.ERROR, 'Scoring failed for submission ' + submissionId + ': ' + scoringEx.getMessage());
                }

                try {
                    FieldMappingService.processFieldMappings(submissionId);
                } catch (Exception mappingEx) {
                    processingErrors.add('Field Mapping: ' + mappingEx.getMessage());
                    System.debug(LoggingLevel.ERROR, 'Field mapping failed for submission ' + submissionId + ': ' + mappingEx.getMessage());
                }
            }

            submission.C_Status__c = processingErrors.isEmpty() ? 'Submitted' : 'Submitted with Errors';
            submission.C_Submitted_Date__c = Datetime.now();
            update submission;

            if (!processingErrors.isEmpty()) {
                throw new AuraHandledException('Form submitted but with processing warnings: ' + String.join(processingErrors, '; '));
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void createResponseRecords(C_Form_Submission__c submission) {
        Map<String, Object> draft = (Map<String, Object>) JSON.deserializeUntyped(submission.C_Draft_State_JSON__c);
        Map<String, Object> responses = (Map<String, Object>) draft.get('responses');
        if (responses == null || responses.isEmpty()) return;

        List<C_Section__c> sections = [
            SELECT Id, Name, C_Weight__c, C_Bonus__c, C_Excluded_From_Weight__c, C_Order__c,
                   C_Page__c
            FROM C_Section__c
            WHERE C_Page__c IN (SELECT Id FROM C_Page__c WHERE C_Form__c = :submission.C_Form__c)
            ORDER BY C_Order__c
        ];

        Map<Id, List<C_Question__c>> questionsBySection = new Map<Id, List<C_Question__c>>();
        Set<Id> sectionIds = new Set<Id>();
        for (C_Section__c s : sections) sectionIds.add(s.Id);

        for (C_Question__c q : [
            SELECT Id, Name, C_Section__c, C_Type__c, C_Question_Text__c, C_Weight__c
            FROM C_Question__c
            WHERE C_Section__c IN :sectionIds
            ORDER BY C_Order__c
        ]) {
            if (!questionsBySection.containsKey(q.C_Section__c)) {
                questionsBySection.put(q.C_Section__c, new List<C_Question__c>());
            }
            questionsBySection.get(q.C_Section__c).add(q);
        }

        Set<Id> questionIds = new Set<Id>();
        for (List<C_Question__c> qs : questionsBySection.values()) {
            for (C_Question__c q : qs) questionIds.add(q.Id);
        }

        Map<Id, List<C_Response__c>> responsesByQuestion = new Map<Id, List<C_Response__c>>();
        for (C_Response__c r : [
            SELECT Id, Name, C_Response_Text__c, C_Question__c, C_Points__c, C_Locks_Question__c
            FROM C_Response__c
            WHERE C_Question__c IN :questionIds
        ]) {
            if (!responsesByQuestion.containsKey(r.C_Question__c)) {
                responsesByQuestion.put(r.C_Question__c, new List<C_Response__c>());
            }
            responsesByQuestion.get(r.C_Question__c).add(r);
        }

        List<C_Section_Response__c> sectionResponsesToInsert = new List<C_Section_Response__c>();
        Map<Id, C_Section_Response__c> sectionResponseMap = new Map<Id, C_Section_Response__c>();

        for (C_Section__c section : sections) {
            C_Section_Response__c sr = new C_Section_Response__c();
            sr.C_Form_Submission__c = submission.Id;
            sr.C_Section__c = section.Id;
            sr.C_Section_Name__c = section.Name;
            sr.C_Weight__c = section.C_Weight__c;
            sr.C_Bonus__c = section.C_Bonus__c;
            sr.C_Excluded_From_Weight__c = section.C_Excluded_From_Weight__c;
            sr.C_Order__c = section.C_Order__c;
            sr.C_Max_Points__c = 0;
            sr.C_Earned_Points__c = 0;
            sectionResponsesToInsert.add(sr);
            sectionResponseMap.put(section.Id, sr);
        }
        insert sectionResponsesToInsert;

        List<C_Question_Response__c> questionResponsesToInsert = new List<C_Question_Response__c>();

        for (C_Section__c section : sections) {
            C_Section_Response__c sr = sectionResponseMap.get(section.Id);
            List<C_Question__c> sectionQuestions = questionsBySection.get(section.Id);
            if (sectionQuestions == null) continue;

            for (C_Question__c question : sectionQuestions) {
                Map<String, Object> answerData = (Map<String, Object>) responses.get(question.Id);
                String selectedValue = null;
                String textValue = null;

                if (answerData != null) {
                    selectedValue = answerData.get('value') != null ? String.valueOf(answerData.get('value')) : null;
                    textValue = answerData.get('textValue') != null ? String.valueOf(answerData.get('textValue')) : null;
                }

                Decimal earnedPoints = 0;
                Decimal questionWeight = question.C_Weight__c != null ? question.C_Weight__c : 0;
                String responseText = textValue;
                Id matchedResponseId = null;
                Boolean isLockedQuestion = false;

                List<C_Response__c> possibleResponses = responsesByQuestion.get(question.Id);
                Decimal maxPointsForQuestion = 0;

                if (possibleResponses != null) {
                    for (C_Response__c r : possibleResponses) {
                        if (r.C_Points__c != null && r.C_Points__c > maxPointsForQuestion) {
                            maxPointsForQuestion = r.C_Points__c;
                        }
                    }

                    if (selectedValue != null) {
                        Set<String> selectedIds = new Set<String>(selectedValue.split(';'));
                        List<String> matchedIds = new List<String>();
                        List<String> matchedTexts = new List<String>();
                        for (C_Response__c r : possibleResponses) {
                            if (selectedIds.contains(r.Id)) {
                                matchedIds.add(r.Id);
                                matchedTexts.add(r.C_Response_Text__c);
                                earnedPoints += (r.C_Points__c != null ? r.C_Points__c : 0);
                                if (r.C_Locks_Question__c == true) isLockedQuestion = true;
                            }
                        }
                        if (!matchedIds.isEmpty()) {
                            matchedResponseId = matchedIds[0];
                            if (responseText == null) responseText = String.join(matchedTexts, '; ');
                        }
                    }
                }

                if (isLockedQuestion) {
                    questionWeight = 0;
                }

                C_Question_Response__c qr = new C_Question_Response__c();
                qr.C_Section_Response__c = sr.Id;
                qr.C_Question__c = question.Id;
                qr.C_Response__c = matchedResponseId;
                qr.C_Question_Text__c = question.C_Question_Text__c;
                qr.C_Question_Type__c = question.C_Type__c;
                qr.C_Response_Text__c = responseText != null ? responseText : selectedValue;
                qr.C_Response_Points__c = earnedPoints;
                qr.C_Question_Weight__c = questionWeight;

                if (answerData != null) {
                    if (answerData.get('tableData') != null) {
                        qr.C_Table_Data__c = String.valueOf(answerData.get('tableData'));
                    }
                    if (selectedValue != null && (question.C_Type__c == 'Picklist' || question.C_Type__c == 'Multi-Select' || question.C_Type__c == 'Checkbox')) {
                        qr.C_Response_Details__c = selectedValue;
                    }
                }

                questionResponsesToInsert.add(qr);

                if (questionWeight > 0 && maxPointsForQuestion > 0) {
                    sr.C_Max_Points__c = (sr.C_Max_Points__c != null ? sr.C_Max_Points__c : 0) + maxPointsForQuestion;
                    sr.C_Earned_Points__c = (sr.C_Earned_Points__c != null ? sr.C_Earned_Points__c : 0) + earnedPoints;
                }
            }
        }

        if (!questionResponsesToInsert.isEmpty()) {
            insert questionResponsesToInsert;
        }

        List<C_Section_Response__c> toUpdate = new List<C_Section_Response__c>();
        for (C_Section_Response__c sr : sectionResponsesToInsert) {
            Decimal maxPts = sr.C_Max_Points__c != null ? sr.C_Max_Points__c : 0;
            Decimal earnedPts = sr.C_Earned_Points__c != null ? sr.C_Earned_Points__c : 0;
            sr.C_Score__c = maxPts > 0 ? (earnedPts / maxPts) * 100 : 0;
            toUpdate.add(sr);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
      
    @AuraEnabled(cacheable=false)
    public static List<String> getRelatedFormSubmission(String recordId) {
        try {
            List<String> result = new List<String>{'null', 'null'};
            Id recId = (Id) recordId;
  
            if (recId.getSobjectType() == Schema.C_Form_Submission__c.getSObjectType()) {
                List<C_Form_Submission__c> submissionList = [
                    SELECT Id, C_Draft_State_JSON__c 
                    FROM C_Form_Submission__c 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
  
                if (submissionList.isEmpty()) return result;
                if (submissionList[0].C_Draft_State_JSON__c == null) return result;

                result = new List<String>{submissionList[0].Id, submissionList[0].C_Draft_State_JSON__c};
                return result;
            } else {
                return result;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSubmissionWithResponses(Id submissionId) {
        try {
            C_Form_Submission__c sub = [
                SELECT Id, C_Form__c, C_Status__c, C_Final_Score__c,
                       C_Submitted_Date__c, C_Language__c, C_Draft_State_JSON__c
                FROM C_Form_Submission__c
                WHERE Id = :submissionId
                LIMIT 1
            ];

            Map<String, Object> responseMap = new Map<String, Object>();
            for (C_Question_Response__c qr : [
                SELECT Id, C_Question__c, C_Response__c, C_Response_Text__c,
                       C_Question_Type__c, C_Table_Data__c
                FROM C_Question_Response__c
                WHERE C_Section_Response__c IN (
                    SELECT Id FROM C_Section_Response__c
                    WHERE C_Form_Submission__c = :submissionId
                )
            ]) {
                Map<String, String> entry = new Map<String, String>();
                entry.put('value', qr.C_Response__c);
                entry.put('textValue', qr.C_Response_Text__c);
                entry.put('questionType', qr.C_Question_Type__c);
                if (qr.C_Table_Data__c != null) {
                    entry.put('tableData', qr.C_Table_Data__c);
                }
                responseMap.put(qr.C_Question__c, entry);
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('formId', sub.C_Form__c);
            result.put('status', sub.C_Status__c);
            result.put('finalScore', sub.C_Final_Score__c);
            result.put('submittedDate', sub.C_Submitted_Date__c);
            result.put('language', sub.C_Language__c);
            result.put('responses', responseMap);
            result.put('draftJson', sub.C_Draft_State_JSON__c);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void markFormAsTesting(String recordId) {
        try {
            C_Form_Submission__c formSubmission = [
                SELECT Id, C_Is_Testing__c 
                FROM C_Form_Submission__c 
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (formSubmission.C_Is_Testing__c == false) {
                formSubmission.C_Is_Testing__c = true;
                update formSubmission;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}

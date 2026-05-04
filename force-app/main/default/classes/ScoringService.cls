/**
 * @description       : Service class for calculating section and submission scores
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   18-03-2026   Daniel Murracas     Bulkified max-points query, added error handling
 * ------------------------------------------------------------
**/
public with sharing class ScoringService {
    
    public static void calculateSubmissionScore(Id formSubmissionId) {
        new ScoreCalculator().calculate(formSubmissionId);
    }

    private without sharing class ScoreCalculator {
        public void calculate(Id formSubmissionId) {
            calculateBulk(new Set<Id>{ formSubmissionId });
        }

        public void calculateBulk(Set<Id> formSubmissionIds) {
            List<C_Section_Response__c> allSectionResponses = [
                SELECT Id, C_Form_Submission__c, C_Section__c, C_Weight__c, C_Bonus__c, C_Excluded_From_Weight__c,
                       C_Max_Points__c, C_Earned_Points__c, C_Score__c,
                       (SELECT Id, C_Response_Points__c, C_Question_Weight__c, C_Question__c
                        FROM C_Question_Responses__r)
                FROM C_Section_Response__c
                WHERE C_Form_Submission__c IN :formSubmissionIds
            ];

            Set<Id> questionIds = new Set<Id>();
            for (C_Section_Response__c secResp : allSectionResponses) {
                for (C_Question_Response__c qr : secResp.C_Question_Responses__r) {
                    if (qr.C_Question__c != null) {
                        questionIds.add(qr.C_Question__c);
                    }
                }
            }

            Map<Id, Decimal> maxPointsByQuestion = new Map<Id, Decimal>();
            if (!questionIds.isEmpty()) {
                for (AggregateResult ar : [
                    SELECT C_Question__c qId, MAX(C_Points__c) maxPts
                    FROM C_Response__c
                    WHERE C_Question__c IN :questionIds
                    GROUP BY C_Question__c
                ]) {
                    Id qId = (Id) ar.get('qId');
                    Decimal maxPts = (Decimal) ar.get('maxPts');
                    maxPointsByQuestion.put(qId, maxPts != null ? maxPts : 0);
                }
            }

            Map<Id, List<C_Section_Response__c>> sectionResponsesBySubmission = new Map<Id, List<C_Section_Response__c>>();
            for (C_Section_Response__c secResp : allSectionResponses) {
                if (!sectionResponsesBySubmission.containsKey(secResp.C_Form_Submission__c)) {
                    sectionResponsesBySubmission.put(secResp.C_Form_Submission__c, new List<C_Section_Response__c>());
                }
                sectionResponsesBySubmission.get(secResp.C_Form_Submission__c).add(secResp);
            }

            List<C_Form_Submission__c> submissionsToUpdate = new List<C_Form_Submission__c>();

            for (Id submissionId : formSubmissionIds) {
                List<C_Section_Response__c> sectionResponses = sectionResponsesBySubmission.get(submissionId);
                if (sectionResponses == null) sectionResponses = new List<C_Section_Response__c>();

                Decimal totalWeightedScore = 0;
                Decimal totalWeight = 0;
                Decimal bonusScore = 0;

                for (C_Section_Response__c secResp : sectionResponses) {
                    Decimal sectionMaxPoints = 0;
                    Decimal sectionEarnedPoints = 0;

                    for (C_Question_Response__c qr : secResp.C_Question_Responses__r) {
                        Decimal points = qr.C_Response_Points__c != null ? qr.C_Response_Points__c : 0;
                        Decimal weight = qr.C_Question_Weight__c != null ? qr.C_Question_Weight__c : 0;
                        sectionEarnedPoints += points;
                        if (weight > 0 && qr.C_Question__c != null) {
                            Decimal maxPts = maxPointsByQuestion.get(qr.C_Question__c);
                            sectionMaxPoints += maxPts != null ? maxPts : 0;
                        }
                    }

                    secResp.C_Max_Points__c = sectionMaxPoints;
                    secResp.C_Earned_Points__c = sectionEarnedPoints;
                    secResp.C_Score__c = sectionMaxPoints > 0 ? (sectionEarnedPoints / sectionMaxPoints) * 100 : 0;

                    Decimal sectionWeight = secResp.C_Weight__c != null ? secResp.C_Weight__c : 0;

                    if (secResp.C_Bonus__c == true) {
                        if (sectionMaxPoints > 0) {
                            bonusScore += (sectionEarnedPoints / sectionMaxPoints) * sectionWeight;
                        }
                    } else if (secResp.C_Excluded_From_Weight__c != true) {
                        totalWeight += sectionWeight;
                        if (sectionMaxPoints > 0) {
                            totalWeightedScore += (sectionEarnedPoints / sectionMaxPoints) * sectionWeight;
                        }
                    }
                }

                Decimal finalScore = 0;
                if (totalWeight > 0) {
                    finalScore = (totalWeightedScore / totalWeight) * 100;
                }
                finalScore += bonusScore;
                if (finalScore > 100) finalScore = 100;

                submissionsToUpdate.add(new C_Form_Submission__c(
                    Id = submissionId,
                    C_Final_Score__c = finalScore
                ));
            }

            if (!allSectionResponses.isEmpty()) update allSectionResponses;
            if (!submissionsToUpdate.isEmpty()) update submissionsToUpdate;
        }
    } // end ScoreCalculator
    
    @InvocableMethod(label='Calculate Form Score' description='Calculates the final score for a form submission')
    public static void calculateScore(List<Id> formSubmissionIds) {
        if (formSubmissionIds == null || formSubmissionIds.isEmpty()) return;
        calculateSubmissionScoreBulk(new Set<Id>(formSubmissionIds));
    }

    public static void calculateSubmissionScoreBulk(Set<Id> submissionIds) {
        if (submissionIds == null || submissionIds.isEmpty()) return;
        new ScoreCalculator().calculateBulk(submissionIds);
    }
}

/**
 * @description       : Test class for ScoringService
 * @author            : Daniel Murracas
 * @last modified on  : 19-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   19-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
@IsTest
private class ScoringServiceTest {

    @TestSetup
    static void setupTestData() {
        FeatureUtil.testIsFormBuilderAdminOverride = null;
        C_Form__c form = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(form.Id, 1);

        C_Section__c weightedSection = TestDataFactory.createSection(page.Id, 1, 60);
        C_Question__c q1 = TestDataFactory.createQuestion(weightedSection.Id, 1, 'Picklist');
        C_Response__c r1a = TestDataFactory.createResponse(q1.Id, 1, 10);
        C_Response__c r1b = TestDataFactory.createResponse(q1.Id, 2, 5);

        C_Section__c bonusSection = TestDataFactory.createSection(page.Id, 2, 10);
        bonusSection.C_Bonus__c = true;
        update bonusSection;
        C_Question__c q2 = TestDataFactory.createQuestion(bonusSection.Id, 1, 'Picklist');
        C_Response__c r2a = TestDataFactory.createResponse(q2.Id, 1, 10);
        C_Response__c r2b = TestDataFactory.createResponse(q2.Id, 2, 0);

        C_Section__c excludedSection = TestDataFactory.createSection(page.Id, 3, 30);
        excludedSection.C_Excluded_From_Weight__c = true;
        update excludedSection;
        C_Question__c q3 = TestDataFactory.createQuestion(excludedSection.Id, 1, 'Picklist');
        C_Response__c r3a = TestDataFactory.createResponse(q3.Id, 1, 10);

        C_Form_Submission__c submission = TestDataFactory.createSubmission(form.Id);

        C_Section_Response__c secResp1 = new C_Section_Response__c(
            Name = 'Weighted Section',
            C_Form_Submission__c = submission.Id,
            C_Section__c = weightedSection.Id,
            C_Weight__c = 60,
            C_Bonus__c = false,
            C_Excluded_From_Weight__c = false,
            C_Order__c = 1
        );
        C_Section_Response__c secResp2 = new C_Section_Response__c(
            Name = 'Bonus Section',
            C_Form_Submission__c = submission.Id,
            C_Section__c = bonusSection.Id,
            C_Weight__c = 10,
            C_Bonus__c = true,
            C_Excluded_From_Weight__c = false,
            C_Order__c = 2
        );
        C_Section_Response__c secResp3 = new C_Section_Response__c(
            Name = 'Excluded Section',
            C_Form_Submission__c = submission.Id,
            C_Section__c = excludedSection.Id,
            C_Weight__c = 30,
            C_Bonus__c = false,
            C_Excluded_From_Weight__c = true,
            C_Order__c = 3
        );
        insert new List<C_Section_Response__c>{ secResp1, secResp2, secResp3 };

        insert new C_Question_Response__c(
            C_Section_Response__c = secResp1.Id,
            C_Question__c = q1.Id,
            C_Response__c = r1a.Id,
            C_Response_Points__c = 10,
            C_Question_Weight__c = 1
        );
        insert new C_Question_Response__c(
            C_Section_Response__c = secResp2.Id,
            C_Question__c = q2.Id,
            C_Response__c = r2a.Id,
            C_Response_Points__c = 10,
            C_Question_Weight__c = 1
        );
        insert new C_Question_Response__c(
            C_Section_Response__c = secResp3.Id,
            C_Question__c = q3.Id,
            C_Response__c = r3a.Id,
            C_Response_Points__c = 10,
            C_Question_Weight__c = 1
        );
    }

    @IsTest
    static void testCalculateSubmissionScoreWeightedSections() {
        C_Form_Submission__c submission = [SELECT Id FROM C_Form_Submission__c LIMIT 1];

        Test.startTest();
        ScoringService.calculateSubmissionScore(submission.Id);
        Test.stopTest();

        C_Form_Submission__c result = [SELECT C_Final_Score__c FROM C_Form_Submission__c WHERE Id = :submission.Id];
        Assert.isNotNull(result.C_Final_Score__c, 'Final score should be calculated');
        Assert.isTrue(result.C_Final_Score__c <= 100, 'Final score should not exceed 100');

        C_Section_Response__c weightedResp = [
            SELECT C_Score__c, C_Max_Points__c, C_Earned_Points__c
            FROM C_Section_Response__c
            WHERE C_Bonus__c = false AND C_Excluded_From_Weight__c = false
            LIMIT 1
        ];
        Assert.areEqual(10, weightedResp.C_Max_Points__c, 'Max points should equal highest response points');
        Assert.areEqual(10, weightedResp.C_Earned_Points__c, 'Earned points should match selected response');
        Assert.areEqual(100, weightedResp.C_Score__c, 'Section score should be 100% for perfect answer');
    }

    @IsTest
    static void testCalculateSubmissionScoreBonusSection() {
        C_Form_Submission__c submission = [SELECT Id FROM C_Form_Submission__c LIMIT 1];

        Test.startTest();
        ScoringService.calculateSubmissionScore(submission.Id);
        Test.stopTest();

        C_Section_Response__c bonusResp = [
            SELECT C_Score__c, C_Earned_Points__c
            FROM C_Section_Response__c
            WHERE C_Bonus__c = true
            LIMIT 1
        ];
        Assert.areEqual(10, bonusResp.C_Earned_Points__c, 'Bonus section should have earned points');
        Assert.areEqual(100, bonusResp.C_Score__c, 'Bonus section score should be 100%');
    }

    @IsTest
    static void testCalculateSubmissionScoreExcludedSection() {
        C_Form_Submission__c submission = [SELECT Id FROM C_Form_Submission__c LIMIT 1];

        Test.startTest();
        ScoringService.calculateSubmissionScore(submission.Id);
        Test.stopTest();

        C_Section_Response__c excludedResp = [
            SELECT C_Score__c
            FROM C_Section_Response__c
            WHERE C_Excluded_From_Weight__c = true
            LIMIT 1
        ];
        Assert.isNotNull(excludedResp.C_Score__c, 'Excluded section should still have a score calculated');
    }

    @IsTest
    static void testCalculateScoreInvocable() {
        C_Form_Submission__c submission = [SELECT Id FROM C_Form_Submission__c LIMIT 1];

        Test.startTest();
        ScoringService.calculateScore(new List<Id>{ submission.Id });
        Test.stopTest();

        C_Form_Submission__c result = [SELECT C_Final_Score__c FROM C_Form_Submission__c WHERE Id = :submission.Id];
        Assert.isNotNull(result.C_Final_Score__c, 'Invocable method should calculate score');
        Assert.isTrue(result.C_Final_Score__c <= 100, 'Final score should be capped at 100');
    }

    @IsTest
    static void testFinalScoreCappedAt100() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];

        C_Section__c highBonusSection = new C_Section__c(
            Name = 'High Bonus',
            C_Page__c = page.Id,
            C_Order__c = 10,
            C_Weight__c = 200,
            C_Bonus__c = true
        );
        insert highBonusSection;

        C_Question__c bonusQ = TestDataFactory.createQuestion(highBonusSection.Id, 1, 'Picklist');
        C_Response__c bonusR = TestDataFactory.createResponse(bonusQ.Id, 1, 10);

        C_Form_Submission__c newSubmission = TestDataFactory.createSubmission(form.Id);

        C_Section_Response__c weightedSecResp = new C_Section_Response__c(
            Name = 'Weighted',
            C_Form_Submission__c = newSubmission.Id,
            C_Section__c = [SELECT Id FROM C_Section__c WHERE C_Bonus__c = false AND C_Excluded_From_Weight__c = false LIMIT 1].Id,
            C_Weight__c = 60,
            C_Bonus__c = false,
            C_Excluded_From_Weight__c = false,
            C_Order__c = 1
        );
        C_Section_Response__c highBonusSecResp = new C_Section_Response__c(
            Name = 'High Bonus',
            C_Form_Submission__c = newSubmission.Id,
            C_Section__c = highBonusSection.Id,
            C_Weight__c = 200,
            C_Bonus__c = true,
            C_Excluded_From_Weight__c = false,
            C_Order__c = 2
        );
        insert new List<C_Section_Response__c>{ weightedSecResp, highBonusSecResp };

        C_Question__c originalQ = [
            SELECT Id FROM C_Question__c
            WHERE C_Section__c IN (SELECT Id FROM C_Section__c WHERE C_Bonus__c = false AND C_Excluded_From_Weight__c = false)
            LIMIT 1
        ];
        C_Response__c originalR = [SELECT Id FROM C_Response__c WHERE C_Question__c = :originalQ.Id AND C_Points__c = 10 LIMIT 1];

        insert new C_Question_Response__c(
            C_Section_Response__c = weightedSecResp.Id,
            C_Question__c = originalQ.Id,
            C_Response__c = originalR.Id,
            C_Response_Points__c = 10,
            C_Question_Weight__c = 1
        );
        insert new C_Question_Response__c(
            C_Section_Response__c = highBonusSecResp.Id,
            C_Question__c = bonusQ.Id,
            C_Response__c = bonusR.Id,
            C_Response_Points__c = 10,
            C_Question_Weight__c = 1
        );

        Test.startTest();
        ScoringService.calculateSubmissionScore(newSubmission.Id);
        Test.stopTest();

        C_Form_Submission__c result = [SELECT C_Final_Score__c FROM C_Form_Submission__c WHERE Id = :newSubmission.Id];
        Assert.areEqual(100, result.C_Final_Score__c, 'Final score must be capped at 100');
    }
}

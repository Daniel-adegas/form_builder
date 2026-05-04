/**
 * @description       : Test class for FormResponseService
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
private class FormResponseServiceTest {

    @TestSetup
    static void setupTestData() {
        FeatureUtil.testIsFormBuilderAdminOverride = null;
        C_Form__c form = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(form.Id, 1);
        C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
        C_Question__c question = TestDataFactory.createQuestion(section.Id, 1, 'Picklist');
        C_Response__c response = TestDataFactory.createResponse(question.Id, 1, 10);
        TestDataFactory.createSubmission(form.Id);
    }

    @IsTest
    static void testSaveFormResponsesValidJson() {
        C_Form_Submission__c submission = [SELECT Id FROM C_Form_Submission__c LIMIT 1];
        C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
        C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];

        String jsonPayload = '[{"sectionId":"' + section.Id + '","hidden":false,"questions":[' +
            '{"questionId":"' + question.Id + '","value":"' + response.Id + '","textValue":"Selected option","hidden":false}' +
            ']}]';

        FormResponseService.FormSubmissionInfo param = new FormResponseService.FormSubmissionInfo();
        param.json = jsonPayload;
        param.formSubmissionId = submission.Id;

        Test.startTest();
        FormResponseService.saveFormResponses(new List<FormResponseService.FormSubmissionInfo>{ param });
        Test.stopTest();

        List<C_Section_Response__c> sectionResponses = [
            SELECT Id, C_Section__c, C_Weight__c
            FROM C_Section_Response__c
            WHERE C_Form_Submission__c = :submission.Id
        ];
        Assert.areEqual(1, sectionResponses.size(), 'Should create one section response');
        Assert.areEqual(section.Id, sectionResponses[0].C_Section__c, 'Section response should link to correct section');

        List<C_Question_Response__c> questionResponses = [
            SELECT Id, C_Question__c, C_Response__c, C_Response_Points__c, C_Response_Details__c
            FROM C_Question_Response__c
            WHERE C_Section_Response__c = :sectionResponses[0].Id
        ];
        Assert.areEqual(1, questionResponses.size(), 'Should create one question response');
        Assert.areEqual(question.Id, questionResponses[0].C_Question__c, 'Question response should link to correct question');
        Assert.areEqual(response.Id, questionResponses[0].C_Response__c, 'Question response should link to selected response');
        Assert.areEqual(10, questionResponses[0].C_Response_Points__c, 'Points should match response points');
        Assert.areEqual('Selected option', questionResponses[0].C_Response_Details__c, 'Response details should contain text value');
    }

    @IsTest
    static void testSaveFormResponsesUpdatesSubmissionStatus() {
        C_Form_Submission__c submission = [SELECT Id FROM C_Form_Submission__c LIMIT 1];
        C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
        C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];

        String jsonPayload = '[{"sectionId":"' + section.Id + '","hidden":false,"questions":[' +
            '{"questionId":"' + question.Id + '","value":"' + response.Id + '","textValue":"Answer","hidden":false}' +
            ']}]';

        FormResponseService.FormSubmissionInfo param = new FormResponseService.FormSubmissionInfo();
        param.json = jsonPayload;
        param.formSubmissionId = submission.Id;

        Test.startTest();
        FormResponseService.saveFormResponses(new List<FormResponseService.FormSubmissionInfo>{ param });
        Test.stopTest();

        C_Form_Submission__c updated = [
            SELECT C_Status__c FROM C_Form_Submission__c WHERE Id = :submission.Id
        ];
        Assert.areEqual('Validated', updated.C_Status__c, 'Submission status should be Validated after saving responses');
    }

    @IsTest
    static void testSaveFormResponsesHiddenSectionSkipped() {
        C_Form_Submission__c submission = [SELECT Id FROM C_Form_Submission__c LIMIT 1];
        C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
        C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];

        String jsonPayload = '[{"sectionId":"' + section.Id + '","hidden":true,"questions":[' +
            '{"questionId":"' + question.Id + '","value":"' + response.Id + '","textValue":"Hidden","hidden":false}' +
            ']}]';

        FormResponseService.FormSubmissionInfo param = new FormResponseService.FormSubmissionInfo();
        param.json = jsonPayload;
        param.formSubmissionId = submission.Id;

        Test.startTest();
        FormResponseService.saveFormResponses(new List<FormResponseService.FormSubmissionInfo>{ param });
        Test.stopTest();

        List<C_Section_Response__c> sectionResponses = [
            SELECT Id FROM C_Section_Response__c WHERE C_Form_Submission__c = :submission.Id
        ];
        Assert.areEqual(0, sectionResponses.size(), 'Hidden section should not produce section responses');
    }
}

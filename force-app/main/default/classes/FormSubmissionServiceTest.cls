/**
 * @description       : Test class for FormSubmissionService
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
private class FormSubmissionServiceTest {

    @TestSetup
    static void setupTestData() {
        FeatureUtil.testIsFormBuilderAdminOverride = null;
        TestDataFactory.createForm();
    }

    @IsTest
    static void testInsertFormSubmissionWithAccount() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.startTest();
        String submissionId = FormSubmissionService.insertFormSubmission(acc.Id);
        Test.stopTest();

        C_Form_Submission__c submission = [
            SELECT C_Account__c, C_Status__c
            FROM C_Form_Submission__c
            WHERE Id = :submissionId
        ];
        Assert.areEqual(acc.Id, submission.C_Account__c, 'Account should be linked');
        Assert.areEqual('In Progress', submission.C_Status__c, 'Status should be In Progress');
    }

    @IsTest
    static void testInsertFormSubmissionWithLead() {
        Lead ld = new Lead(LastName = 'Test Lead', Company = 'Test Co');
        insert ld;

        Test.startTest();
        String submissionId = FormSubmissionService.insertFormSubmission(ld.Id);
        Test.stopTest();

        C_Form_Submission__c submission = [
            SELECT C_Lead__c FROM C_Form_Submission__c WHERE Id = :submissionId
        ];
        Assert.areEqual(ld.Id, submission.C_Lead__c, 'Lead should be linked');
    }

    @IsTest
    static void testInsertFormSubmissionWithContact() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;

        Test.startTest();
        String submissionId = FormSubmissionService.insertFormSubmission(con.Id);
        Test.stopTest();

        C_Form_Submission__c submission = [
            SELECT C_Contact__c FROM C_Form_Submission__c WHERE Id = :submissionId
        ];
        Assert.areEqual(con.Id, submission.C_Contact__c, 'Contact should be linked');
    }

    @IsTest
    static void testInsertFormSubmissionWithFormIdOnly() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        Test.startTest();
        String submissionId = FormSubmissionService.insertFormSubmission(null, form.Id);
        Test.stopTest();

        C_Form_Submission__c submission = [
            SELECT C_Form__c
            FROM C_Form_Submission__c
            WHERE Id = :submissionId
        ];
        Assert.areEqual(form.Id, submission.C_Form__c, 'Form should be set when formId is provided');
    }

    @IsTest
    static void testGetOrCreateSubmission_storesPlainIdContext() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        Account acc = new Account(Name = 'Context Account');
        insert acc;

        Test.startTest();
        Map<String, String> result = FormSubmissionService.getOrCreateSubmission(form.Id, String.valueOf(acc.Id));
        Test.stopTest();

        C_Form_Submission__c submission = [
            SELECT C_Account__c, C_Record_Id__c, C_Record_Context_JSON__c
            FROM C_Form_Submission__c
            WHERE Id = :result.get('submissionId')
        ];
        Assert.areEqual(acc.Id, submission.C_Account__c, 'Plain Id context should populate Account lookup');
        Assert.areEqual(String.valueOf(acc.Id), submission.C_Record_Id__c, 'Record Id should mirror context');
        Assert.areEqual(String.valueOf(acc.Id), submission.C_Record_Context_JSON__c, 'Raw context string should be stored');
    }

    @IsTest
    static void testGetOrCreateSubmission_singleKeyJsonContext() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        Account acc = new Account(Name = 'Json Context Account');
        insert acc;
        String ctx = '{"rec":"' + acc.Id + '"}';

        Test.startTest();
        Map<String, String> result = FormSubmissionService.getOrCreateSubmission(form.Id, ctx);
        Test.stopTest();

        C_Form_Submission__c submission = [
            SELECT C_Record_Context_JSON__c
            FROM C_Form_Submission__c
            WHERE Id = :result.get('submissionId')
        ];
        Assert.areEqual(ctx, submission.C_Record_Context_JSON__c, 'JSON context should be persisted');
    }

    @IsTest
    static void testInsertFormSubmissionWithNull() {
        Test.startTest();
        String submissionId = FormSubmissionService.insertFormSubmission(null);
        Test.stopTest();

        C_Form_Submission__c submission = [
            SELECT C_Account__c, C_Lead__c, C_Contact__c
            FROM C_Form_Submission__c
            WHERE Id = :submissionId
        ];
        Assert.areEqual(null, submission.C_Account__c, 'Account should be null');
        Assert.areEqual(null, submission.C_Lead__c, 'Lead should be null');
        Assert.areEqual(null, submission.C_Contact__c, 'Contact should be null');
    }

    @IsTest
    static void testGetOrCreateSubmissionCreatesNew() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        Test.startTest();
        Map<String, String> result = FormSubmissionService.getOrCreateSubmission(form.Id, null);
        Test.stopTest();

        Assert.isTrue(String.isNotBlank(result.get('submissionId')), 'Should return a submission ID');
        Assert.areEqual('false', result.get('isResume'), 'Should not be a resume');

        C_Form_Submission__c created = [
            SELECT C_Form__c, C_Status__c
            FROM C_Form_Submission__c
            WHERE Id = :result.get('submissionId')
        ];
        Assert.areEqual(form.Id, created.C_Form__c, 'Form should be linked');
        Assert.areEqual('Draft', created.C_Status__c, 'Status should be Draft');
    }

    @IsTest
    static void testGetOrCreateSubmissionReturnsExistingDraft() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        C_Form_Submission__c draft = new C_Form_Submission__c(
            Name = 'Existing Draft',
            C_Form__c = form.Id,
            C_Status__c = 'Draft',
            C_Draft_State_JSON__c = '{"test":"data"}'
        );
        insert draft;

        Test.startTest();
        Map<String, String> result = FormSubmissionService.getOrCreateSubmission(form.Id, null);
        Test.stopTest();

        Assert.areEqual(draft.Id, result.get('submissionId'), 'Should return existing draft ID');
        Assert.areEqual('true', result.get('isResume'), 'Should indicate resume');
        Assert.areEqual('{"test":"data"}', result.get('draftJson'), 'Should return draft JSON');
    }

    @IsTest
    static void testSaveDraftState() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Form_Submission__c submission = TestDataFactory.createSubmission(form.Id);

        String draftJson = '{"page":1,"answers":[]}';

        Test.startTest();
        FormSubmissionService.saveDraftState(submission.Id, draftJson);
        Test.stopTest();

        C_Form_Submission__c updated = [
            SELECT C_Draft_State_JSON__c, C_Status__c
            FROM C_Form_Submission__c
            WHERE Id = :submission.Id
        ];
        Assert.areEqual(draftJson, updated.C_Draft_State_JSON__c, 'Draft JSON should be saved');
        Assert.areEqual('Draft', updated.C_Status__c, 'Status should be Draft');
    }

    @IsTest
    static void testSubmitForm() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Form_Submission__c submission = TestDataFactory.createSubmission(form.Id);

        Test.startTest();
        FormSubmissionService.submitForm(submission.Id);
        Test.stopTest();

        C_Form_Submission__c updated = [
            SELECT C_Status__c, C_Submitted_Date__c
            FROM C_Form_Submission__c
            WHERE Id = :submission.Id
        ];
        Assert.areEqual('Submitted', updated.C_Status__c, 'Status should be Submitted');
        Assert.isNotNull(updated.C_Submitted_Date__c, 'Submitted date should be set');
    }

    @IsTest
    static void testSubmitFormSkipsResponseRecordsByDefault() {
        SubmissionFixture fx = buildSubmissionWithDraft();

        Test.startTest();
        FormSubmissionService.submitForm(fx.submission.Id);
        Test.stopTest();

        Integer sectionResponseCount = [
            SELECT COUNT() FROM C_Section_Response__c WHERE C_Form_Submission__c = :fx.submission.Id
        ];
        Integer questionResponseCount = [
            SELECT COUNT() FROM C_Question_Response__c
            WHERE C_Section_Response__r.C_Form_Submission__c = :fx.submission.Id
        ];
        C_Form_Submission__c reloaded = [
            SELECT C_Status__c, C_Submitted_Date__c, C_Final_Score__c
            FROM C_Form_Submission__c WHERE Id = :fx.submission.Id
        ];
        Assert.areEqual(0, sectionResponseCount,
            'No Section Responses should be created when toggle is disabled (default)');
        Assert.areEqual(0, questionResponseCount,
            'No Question Responses should be created when toggle is disabled (default)');
        Assert.areEqual('Submitted', reloaded.C_Status__c,
            'Submission should still close cleanly when pipeline is gated off');
        Assert.isNotNull(reloaded.C_Submitted_Date__c, 'Submitted date should be set');
        Assert.areEqual(null, reloaded.C_Final_Score__c,
            'Final score should remain null when scoring is gated off (was previously written as 0)');
    }

    @IsTest
    static void testSubmitFormCreatesResponseRecordsWhenEnabled() {
        insert new Form_Builder_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            C_Enable_Response_Records__c = true
        );
        SubmissionFixture fx = buildSubmissionWithDraft();

        Test.startTest();
        FormSubmissionService.submitForm(fx.submission.Id);
        Test.stopTest();

        Integer sectionResponseCount = [
            SELECT COUNT() FROM C_Section_Response__c WHERE C_Form_Submission__c = :fx.submission.Id
        ];
        Integer questionResponseCount = [
            SELECT COUNT() FROM C_Question_Response__c
            WHERE C_Section_Response__r.C_Form_Submission__c = :fx.submission.Id
        ];
        C_Form_Submission__c reloaded = [
            SELECT C_Status__c, C_Final_Score__c
            FROM C_Form_Submission__c WHERE Id = :fx.submission.Id
        ];
        Assert.isTrue(sectionResponseCount > 0,
            'Section Responses should be created when toggle is enabled at org-default level');
        Assert.isTrue(questionResponseCount > 0,
            'Question Responses should be created when toggle is enabled at org-default level');
        Assert.areEqual('Submitted', reloaded.C_Status__c,
            'Submission status should reach Submitted when toggle is enabled');
        Assert.isNotNull(reloaded.C_Final_Score__c,
            'Final score should be calculated when scoring runs (toggle enabled)');
    }

    private class SubmissionFixture {
        C_Form_Submission__c submission;
        Id questionId;
        Id responseId;
    }

    private static SubmissionFixture buildSubmissionWithDraft() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Page__c page = TestDataFactory.createPage(form.Id, 1);
        C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
        C_Question__c question = TestDataFactory.createQuestion(section.Id, 1, 'Picklist');
        C_Response__c response = TestDataFactory.createResponse(question.Id, 1, 10);

        Map<String, Object> answer = new Map<String, Object>{
            'value' => response.Id,
            'textValue' => response.C_Response_Text__c
        };
        Map<String, Object> draft = new Map<String, Object>{
            'responses' => new Map<String, Object>{ String.valueOf(question.Id) => answer }
        };

        C_Form_Submission__c submission = TestDataFactory.createSubmission(form.Id);
        submission.C_Draft_State_JSON__c = JSON.serialize(draft);
        update submission;

        SubmissionFixture fx = new SubmissionFixture();
        fx.submission = submission;
        fx.questionId = question.Id;
        fx.responseId = response.Id;
        return fx;
    }

    @IsTest
    static void testGetRelatedFormSubmission() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Form_Submission__c submission = new C_Form_Submission__c(
            Name = 'Related Sub',
            C_Form__c = form.Id,
            C_Status__c = 'Draft',
            C_Draft_State_JSON__c = '{"resumeData":"value"}'
        );
        insert submission;

        Test.startTest();
        List<String> result = FormSubmissionService.getRelatedFormSubmission(submission.Id);
        Test.stopTest();

        Assert.areEqual(submission.Id, result[0], 'Should return submission ID');
        Assert.areEqual('{"resumeData":"value"}', result[1], 'Should return draft JSON');
    }

    @IsTest
    static void testGetRelatedFormSubmissionNonSubmissionRecord() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.startTest();
        List<String> result = FormSubmissionService.getRelatedFormSubmission(acc.Id);
        Test.stopTest();

        Assert.areEqual('null', result[0], 'Should return null placeholder for non-submission record');
        Assert.areEqual('null', result[1], 'Should return null placeholder for non-submission record');
    }

    @IsTest
    static void testMarkFormAsTesting() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Form_Submission__c submission = TestDataFactory.createSubmission(form.Id);

        Test.startTest();
        FormSubmissionService.markFormAsTesting(submission.Id);
        Test.stopTest();

        C_Form_Submission__c updated = [
            SELECT C_Is_Testing__c
            FROM C_Form_Submission__c
            WHERE Id = :submission.Id
        ];
        Assert.areEqual(true, updated.C_Is_Testing__c, 'Is Testing should be true');
    }
}

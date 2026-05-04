/**
 * @description       : Test class for FieldMappingService
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
private class FieldMappingServiceTest {

    @TestSetup
    static void setupTestData() {
        C_Form__c form = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(form.Id, 1);
        C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
        C_Question__c question = TestDataFactory.createQuestion(section.Id, 1, 'Text');

        C_Form_Target__c target = TestDataFactory.createFormTarget(form.Id, 'Account', 'Running_User_Account');
        TestDataFactory.createFieldMapping(target.Id, question.Id, 'Name');
    }

    @IsTest
    static void testGetFormTargets() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        Test.startTest();
        List<C_Form_Target__c> targets = FieldMappingService.getFormTargets(form.Id);
        Test.stopTest();

        Assert.areEqual(1, targets.size(), 'Should return one active form target');
        Assert.isFalse(targets[0].C_Field_Mappings__r.isEmpty(), 'Target should include field mappings');
    }

    @IsTest
    static void testSaveFormTarget() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        C_Form_Target__c newTarget = new C_Form_Target__c(
            C_Form__c = form.Id,
            C_Target_Object__c = 'Contact',
            C_Resolution_Type__c = 'Running_User_Contact',
            C_Record_Operation__c = 'Update',
            C_Is_Active__c = true,
            C_Order__c = 2
        );

        Test.startTest();
        C_Form_Target__c saved = FieldMappingService.saveFormTarget(newTarget);
        Test.stopTest();

        Assert.isNotNull(saved.Id, 'Saved target should have an Id');
        Assert.areEqual('Contact', saved.C_Target_Object__c);
    }

    @IsTest
    static void testDeleteFormTarget() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form_Target__c target = [SELECT Id FROM C_Form_Target__c LIMIT 1];

        Test.startTest();
        FieldMappingService.deleteFormTarget(target.Id);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM C_Form_Target__c WHERE Id = :target.Id];
        Assert.areEqual(0, count, 'Form target should be deleted');
    }

    @IsTest
    static void testGetMappingsForTarget() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form_Target__c target = [SELECT Id FROM C_Form_Target__c LIMIT 1];

        Test.startTest();
        List<C_Field_Mapping__c> mappings = FieldMappingService.getMappingsForTarget(target.Id);
        Test.stopTest();

        Assert.areEqual(1, mappings.size(), 'Should return one mapping');
        Assert.areEqual('Name', mappings[0].C_Target_Field__c, 'Target field should be Name');
    }

    @IsTest
    static void testSaveFieldMapping() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form_Target__c target = [SELECT Id FROM C_Form_Target__c LIMIT 1];
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];

        C_Field_Mapping__c newMapping = new C_Field_Mapping__c(
            Name = 'New Mapping',
            C_Form_Target__c = target.Id,
            C_Question__c = question.Id,
            C_Target_Field__c = 'Description',
            C_Target_Object__c = 'Account',
            C_Mapping_Type__c = 'Field_Value',
            C_Is_Active__c = true
        );

        Test.startTest();
        C_Field_Mapping__c saved = FieldMappingService.saveFieldMapping(newMapping);
        Test.stopTest();

        Assert.isNotNull(saved.Id, 'Saved mapping should have an Id');
        Assert.areEqual('Description', saved.C_Target_Field__c);
    }

    @IsTest
    static void testDeleteFieldMapping() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Field_Mapping__c mapping = [SELECT Id FROM C_Field_Mapping__c LIMIT 1];

        Test.startTest();
        FieldMappingService.deleteFieldMapping(mapping.Id);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM C_Field_Mapping__c WHERE Id = :mapping.Id];
        Assert.areEqual(0, count, 'Field mapping should be deleted');
    }

    @IsTest
    static void testGetObjectFieldsForAccount() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        Test.startTest();
        List<Map<String, String>> fields = FieldMappingService.getObjectFields('Account');
        Test.stopTest();

        Assert.isFalse(fields.isEmpty(), 'Account should have accessible fields');
        Boolean hasName = false;
        for (Map<String, String> field : fields) {
            if (field.get('value') == 'Name') {
                hasName = true;
                break;
            }
        }
        Assert.isTrue(hasName, 'Account fields should include Name');
    }

    @IsTest
    static void testGetObjectFieldsInvalidObject() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        Test.startTest();
        List<Map<String, String>> fields = FieldMappingService.getObjectFields('NonExistent_Object__xyz');
        Test.stopTest();

        Assert.isTrue(fields.isEmpty(), 'Invalid object name should return empty list');
    }

    @IsTest
    static void testGetCreatableObjects() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        Test.startTest();
        List<Map<String, String>> objects = FieldMappingService.getCreatableObjects();
        Test.stopTest();

        Assert.isFalse(objects.isEmpty(), 'Should return at least some creatable objects');
        Boolean hasAccount = false;
        for (Map<String, String> obj : objects) {
            if (obj.get('value') == 'Account') {
                hasAccount = true;
                break;
            }
        }
        Assert.isTrue(hasAccount, 'Creatable objects should include Account');
    }

    @IsTest
    static void testGetAllFormTargets() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        Test.startTest();
        List<C_Form_Target__c> targets = FieldMappingService.getAllFormTargets(form.Id);
        Test.stopTest();

        Assert.areEqual(1, targets.size(), 'Should return one target including inactive children');
        Assert.isFalse(targets[0].C_Field_Mappings__r.isEmpty(), 'Should load child mappings');
    }

    @IsTest
    static void testGetUserLookupFields_forAccount() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        Test.startTest();
        List<Map<String, String>> fields = FieldMappingService.getUserLookupFields('Account');
        Test.stopTest();

        Assert.isFalse(fields.isEmpty(), 'User should expose at least one lookup to Account');
    }

    @IsTest
    static void testGetPrePopulationData_emptyWhenNoInboundTargets() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        Test.startTest();
        Map<String, Object> prepop = FieldMappingService.getPrePopulationData(form.Id, '{}');
        Test.stopTest();

        Assert.areEqual(true, prepop.isEmpty(), 'Outbound-only form should return empty prepop map');
    }

    @IsTest
    static void testGetPrePopulationData_inboundTextField() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
        Account acc = new Account(Name = 'Inbound PrepOp Name');
        insert acc;

        C_Form_Target__c inboundTarget = new C_Form_Target__c(
            C_Form__c = form.Id,
            C_Target_Object__c = 'Account',
            C_Resolution_Type__c = 'Record_Context',
            C_Context_Key__c = 'aid',
            C_Record_Operation__c = 'Update',
            C_Is_Active__c = true,
            C_Order__c = 2,
            C_Description__c = 'Inbound prepop',
            C_Direction__c = 'Inbound'
        );
        insert inboundTarget;

        insert new C_Field_Mapping__c(
            Name = 'Inbound Name Map',
            C_Form_Target__c = inboundTarget.Id,
            C_Question__c = question.Id,
            C_Target_Field__c = 'Name',
            C_Target_Object__c = 'Account',
            C_Mapping_Type__c = 'Field_Value',
            C_Is_Active__c = true
        );

        Test.startTest();
        Map<String, Object> prepop = FieldMappingService.getPrePopulationData(
            form.Id,
            '{"aid":"' + acc.Id + '"}'
        );
        Test.stopTest();

        Assert.isTrue(prepop.containsKey(question.Id), 'Should prepopulate mapped question');
        Map<String, String> entry = (Map<String, String>) prepop.get(question.Id);
        Assert.areEqual('Inbound PrepOp Name', entry.get('textValue'), 'Text question should receive Account Name');
    }

    @IsTest
    static void testProcessFieldMappings_updatesAccountViaRecordContext() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        Account acc = new Account(Name = 'Before Map');
        insert acc;

        C_Form__c form = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(form.Id, 1);
        C_Section__c section = TestDataFactory.createSection(page.Id, 1, 50);
        C_Question__c question = TestDataFactory.createQuestion(section.Id, 1, 'Text');

        C_Form_Target__c target = new C_Form_Target__c(
            C_Form__c = form.Id,
            C_Target_Object__c = 'Account',
            C_Resolution_Type__c = 'Record_Context',
            C_Context_Key__c = 'recId',
            C_Record_Operation__c = 'Update',
            C_Is_Active__c = true,
            C_Order__c = 1,
            C_Description__c = 'Outbound Account target',
            C_Direction__c = 'Outbound'
        );
        insert target;

        insert new C_Field_Mapping__c(
            Name = 'Account Name from Q',
            C_Form_Target__c = target.Id,
            C_Question__c = question.Id,
            C_Target_Field__c = 'Name',
            C_Target_Object__c = 'Account',
            C_Mapping_Type__c = 'Field_Value',
            C_Is_Active__c = true
        );

        C_Form_Submission__c submission = new C_Form_Submission__c(
            Name = 'Mapping Submission',
            C_Form__c = form.Id,
            C_Status__c = 'In Progress',
            C_Language__c = 'en',
            C_Is_Testing__c = true,
            C_Record_Context_JSON__c = '{"recId":"' + acc.Id + '"}'
        );
        insert submission;

        C_Section_Response__c sectionResp = new C_Section_Response__c(
            Name = 'Sec Resp',
            C_Form_Submission__c = submission.Id,
            C_Section__c = section.Id,
            C_Weight__c = 50,
            C_Bonus__c = false,
            C_Excluded_From_Weight__c = false,
            C_Order__c = 1
        );
        insert sectionResp;

        insert new C_Question_Response__c(
            C_Section_Response__c = sectionResp.Id,
            C_Question__c = question.Id,
            C_Response_Text__c = 'After Map',
            C_Question_Type__c = 'Text',
            C_Question_Weight__c = 1,
            C_Response_Points__c = 0
        );

        Test.startTest();
        FieldMappingService.processFieldMappings(submission.Id);
        Test.stopTest();

        Account updated = [SELECT Name FROM Account WHERE Id = :acc.Id];
        Assert.areEqual('After Map', updated.Name, 'Field mapping should update Account Name from response text');
    }

    @IsTest
    static void testProcessFieldMappings_createsAccountWithNewResolution() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c form = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(form.Id, 1);
        C_Section__c section = TestDataFactory.createSection(page.Id, 1, 50);
        C_Question__c question = TestDataFactory.createQuestion(section.Id, 1, 'Text');

        C_Form_Target__c target = new C_Form_Target__c(
            C_Form__c = form.Id,
            C_Target_Object__c = 'Account',
            C_Resolution_Type__c = 'New',
            C_Record_Operation__c = 'Create',
            C_Is_Active__c = true,
            C_Order__c = 1,
            C_Description__c = 'Create Account target',
            C_Direction__c = 'Outbound'
        );
        insert target;

        insert new C_Field_Mapping__c(
            Name = 'Static Phone',
            C_Form_Target__c = target.Id,
            C_Question__c = question.Id,
            C_Target_Field__c = 'Phone',
            C_Target_Object__c = 'Account',
            C_Mapping_Type__c = 'Static_Value',
            C_Static_Value__c = '555-0100',
            C_Is_Active__c = true
        );
        insert new C_Field_Mapping__c(
            Name = 'Name from response',
            C_Form_Target__c = target.Id,
            C_Question__c = question.Id,
            C_Target_Field__c = 'Name',
            C_Target_Object__c = 'Account',
            C_Mapping_Type__c = 'Field_Value',
            C_Is_Active__c = true
        );

        C_Form_Submission__c submission = new C_Form_Submission__c(
            Name = 'Create Submission',
            C_Form__c = form.Id,
            C_Status__c = 'In Progress',
            C_Language__c = 'en',
            C_Is_Testing__c = true
        );
        insert submission;

        C_Section_Response__c sectionResp = new C_Section_Response__c(
            Name = 'Sec Resp Create',
            C_Form_Submission__c = submission.Id,
            C_Section__c = section.Id,
            C_Weight__c = 50,
            C_Bonus__c = false,
            C_Excluded_From_Weight__c = false,
            C_Order__c = 1
        );
        insert sectionResp;

        insert new C_Question_Response__c(
            C_Section_Response__c = sectionResp.Id,
            C_Question__c = question.Id,
            C_Response_Text__c = 'Created From Form',
            C_Question_Type__c = 'Text',
            C_Question_Weight__c = 1,
            C_Response_Points__c = 0
        );

        Test.startTest();
        FieldMappingService.processFieldMappings(submission.Id);
        Test.stopTest();

        List<Account> created = [SELECT Name, Phone FROM Account WHERE Name = 'Created From Form' LIMIT 1];
        Assert.areEqual(1, created.size(), 'Should insert a new Account from field mappings');
        Assert.areEqual('555-0100', created[0].Phone, 'Static mapping should set Phone');
    }
}

/**
 * @description       : Test class for CloneFormAction
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
private class CloneFormActionTest {

    @TestSetup
    static void setupTestData() {
        C_Form__c form = TestDataFactory.createForm();
        C_Category__c cat1 = TestDataFactory.createCategory(form.Id, 1);
        C_Category__c cat2 = TestDataFactory.createCategory(form.Id, 2);
        C_Page__c page1 = TestDataFactory.createPage(form.Id, cat1.Id, 1);
        C_Page__c page2 = TestDataFactory.createPage(form.Id, cat2.Id, 2);

        C_Section__c section1 = TestDataFactory.createSection(page1.Id, 1, 50);
        C_Section__c section2 = TestDataFactory.createSection(page2.Id, 1, 50);

        C_Question__c q1 = TestDataFactory.createQuestion(section1.Id, 1, 'Picklist');
        C_Question__c q2 = TestDataFactory.createQuestion(section2.Id, 1, 'Picklist');

        C_Response__c r1 = TestDataFactory.createResponse(q1.Id, 1, 10);
        C_Response__c r2 = TestDataFactory.createResponse(q2.Id, 1, 5);

        TestDataFactory.createDependency(r1.Id, section2.Id, 'Show');
    }

    @IsTest
    static void testCloneFormCategories() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c originalForm = [SELECT Id FROM C_Form__c LIMIT 1];
        Integer originalCategoryCount = [SELECT COUNT() FROM C_Category__c WHERE C_Form__c = :originalForm.Id];

        CloneFormAction.FlowInputs input = new CloneFormAction.FlowInputs();
        input.formId = originalForm.Id;
        input.formName = 'Cloned Categories Test';

        Test.startTest();
        CloneFormAction.cloneForm(new List<CloneFormAction.FlowInputs>{ input });
        Test.stopTest();

        C_Form__c clonedForm = [SELECT Id FROM C_Form__c WHERE Name = 'Cloned Categories Test' LIMIT 1];
        Integer clonedCategoryCount = [SELECT COUNT() FROM C_Category__c WHERE C_Form__c = :clonedForm.Id];
        Assert.areEqual(originalCategoryCount, clonedCategoryCount, 'Cloned form should have same number of categories');

        List<C_Page__c> clonedPages = [SELECT Id, C_Category__c FROM C_Page__c WHERE C_Form__c = :clonedForm.Id];
        Set<Id> clonedCatIds = new Map<Id, C_Category__c>([SELECT Id FROM C_Category__c WHERE C_Form__c = :clonedForm.Id]).keySet();
        for (C_Page__c p : clonedPages) {
            if (p.C_Category__c != null) {
                Assert.isTrue(clonedCatIds.contains(p.C_Category__c), 'Page category should point to cloned category, not original');
            }
        }
    }

    @IsTest
    static void testCloneFormAllRecords() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c originalForm = [SELECT Id, Name FROM C_Form__c LIMIT 1];
        Integer originalPageCount = [SELECT COUNT() FROM C_Page__c WHERE C_Form__c = :originalForm.Id];
        Set<Id> origPageIds = new Map<Id, C_Page__c>([SELECT Id FROM C_Page__c WHERE C_Form__c = :originalForm.Id]).keySet();
        Integer originalSectionCount = [SELECT COUNT() FROM C_Section__c WHERE C_Page__c IN :origPageIds];
        Set<Id> origSectionIds = new Map<Id, C_Section__c>([SELECT Id FROM C_Section__c WHERE C_Page__c IN :origPageIds]).keySet();
        Integer originalQuestionCount = [SELECT COUNT() FROM C_Question__c WHERE C_Section__c IN :origSectionIds];
        Set<Id> origQuestionIds = new Map<Id, C_Question__c>([SELECT Id FROM C_Question__c WHERE C_Section__c IN :origSectionIds]).keySet();
        Integer originalResponseCount = [SELECT COUNT() FROM C_Response__c WHERE C_Question__c IN :origQuestionIds];

        CloneFormAction.FlowInputs input = new CloneFormAction.FlowInputs();
        input.formId = originalForm.Id;
        input.formName = 'Cloned Form';

        Test.startTest();
        CloneFormAction.cloneForm(new List<CloneFormAction.FlowInputs>{ input });
        Test.stopTest();

        List<C_Form__c> allForms = [SELECT Id, Name, C_Status__c FROM C_Form__c ORDER BY CreatedDate];
        Assert.areEqual(2, allForms.size(), 'Should have original and cloned form');

        C_Form__c clonedForm = [SELECT Id, Name, C_Status__c FROM C_Form__c WHERE Name = 'Cloned Form' LIMIT 1];
        Assert.areEqual('Draft', clonedForm.C_Status__c, 'Cloned form status should be Draft');

        Integer clonedPageCount = [SELECT COUNT() FROM C_Page__c WHERE C_Form__c = :clonedForm.Id];
        Assert.areEqual(originalPageCount, clonedPageCount, 'Cloned form should have same number of pages');

        Set<Id> clonedPageIds = new Map<Id, C_Page__c>([SELECT Id FROM C_Page__c WHERE C_Form__c = :clonedForm.Id]).keySet();
        Integer clonedSectionCount = [SELECT COUNT() FROM C_Section__c WHERE C_Page__c IN :clonedPageIds];
        Assert.areEqual(originalSectionCount, clonedSectionCount, 'Cloned form should have same number of sections');

        Set<Id> clonedSectionIds = new Map<Id, C_Section__c>([SELECT Id FROM C_Section__c WHERE C_Page__c IN :clonedPageIds]).keySet();
        Integer clonedQuestionCount = [SELECT COUNT() FROM C_Question__c WHERE C_Section__c IN :clonedSectionIds];
        Assert.areEqual(originalQuestionCount, clonedQuestionCount, 'Cloned form should have same number of questions');

        Set<Id> clonedQuestionIds = new Map<Id, C_Question__c>([SELECT Id FROM C_Question__c WHERE C_Section__c IN :clonedSectionIds]).keySet();
        Integer clonedResponseCount = [SELECT COUNT() FROM C_Response__c WHERE C_Question__c IN :clonedQuestionIds];
        Assert.areEqual(originalResponseCount, clonedResponseCount, 'Cloned form should have same number of responses');
    }

    @IsTest
    static void testCloneFormDependencyRemapping() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c originalForm = [SELECT Id FROM C_Form__c LIMIT 1];

        CloneFormAction.FlowInputs input = new CloneFormAction.FlowInputs();
        input.formId = originalForm.Id;
        input.formName = 'Cloned With Deps';

        Test.startTest();
        CloneFormAction.cloneForm(new List<CloneFormAction.FlowInputs>{ input });
        Test.stopTest();

        C_Form__c clonedForm = [SELECT Id FROM C_Form__c WHERE Name = 'Cloned With Deps' LIMIT 1];

        Set<Id> originalPageIds = new Map<Id, C_Page__c>([SELECT Id FROM C_Page__c WHERE C_Form__c = :originalForm.Id]).keySet();
        Set<Id> originalSectionIds = new Map<Id, C_Section__c>([SELECT Id FROM C_Section__c WHERE C_Page__c IN :originalPageIds]).keySet();
        Set<Id> originalQuestionIds = new Map<Id, C_Question__c>([SELECT Id FROM C_Question__c WHERE C_Section__c IN :originalSectionIds]).keySet();
        Set<Id> originalResponseIds = new Map<Id, C_Response__c>([SELECT Id FROM C_Response__c WHERE C_Question__c IN :originalQuestionIds]).keySet();

        Set<Id> clonedPageIds = new Map<Id, C_Page__c>([SELECT Id FROM C_Page__c WHERE C_Form__c = :clonedForm.Id]).keySet();
        Set<Id> clonedSectionIds = new Map<Id, C_Section__c>([SELECT Id FROM C_Section__c WHERE C_Page__c IN :clonedPageIds]).keySet();
        Set<Id> clonedQuestionIds = new Map<Id, C_Question__c>([SELECT Id FROM C_Question__c WHERE C_Section__c IN :clonedSectionIds]).keySet();
        Set<Id> clonedResponseIds = new Map<Id, C_Response__c>([SELECT Id FROM C_Response__c WHERE C_Question__c IN :clonedQuestionIds]).keySet();

        List<C_Dependency__c> clonedDeps = [
            SELECT C_Controlling_Response__c, C_Target_Section__c, C_Target_Page__c,
                   C_Target_Question__c, C_Action__c
            FROM C_Dependency__c
            WHERE C_Controlling_Response__c IN :clonedResponseIds
        ];

        Assert.areEqual(1, clonedDeps.size(), 'Should have one cloned dependency');

        C_Dependency__c dep = clonedDeps[0];
        Assert.isTrue(clonedResponseIds.contains(dep.C_Controlling_Response__c),
            'Controlling response should point to a cloned response');
        Assert.isTrue(dep.C_Target_Section__c == null || clonedSectionIds.contains(dep.C_Target_Section__c),
            'Target section should point to a cloned section');
        Assert.isFalse(originalResponseIds.contains(dep.C_Controlling_Response__c),
            'Controlling response should NOT point to original response');
        Assert.areEqual('Show', dep.C_Action__c, 'Action should be preserved');
    }

    @IsTest
    static void testCloneFormSearchNameUpdated() {
        FeatureUtil.testIsFormBuilderAdminOverride = true;
        C_Form__c originalForm = [SELECT Id FROM C_Form__c LIMIT 1];

        CloneFormAction.FlowInputs input = new CloneFormAction.FlowInputs();
        input.formId = originalForm.Id;
        input.formName = 'Search Name Clone';

        Test.startTest();
        CloneFormAction.cloneForm(new List<CloneFormAction.FlowInputs>{ input });
        Test.stopTest();

        C_Form__c clonedForm = [SELECT Id FROM C_Form__c WHERE Name = 'Search Name Clone' LIMIT 1];
        Set<Id> clonedPageIds = new Map<Id, C_Page__c>([SELECT Id FROM C_Page__c WHERE C_Form__c = :clonedForm.Id]).keySet();
        Set<Id> clonedSectionIds = new Map<Id, C_Section__c>([SELECT Id FROM C_Section__c WHERE C_Page__c IN :clonedPageIds]).keySet();

        List<C_Question__c> clonedQuestions = [
            SELECT C_Search_Name__c FROM C_Question__c WHERE C_Section__c IN :clonedSectionIds
        ];

        for (C_Question__c q : clonedQuestions) {
            Assert.isTrue(
                q.C_Search_Name__c != null && q.C_Search_Name__c.contains('Search Name Clone'),
                'Search name should contain the new form name: ' + q.C_Search_Name__c
            );
        }
    }
}

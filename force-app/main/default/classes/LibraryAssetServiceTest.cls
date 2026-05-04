/**
 * @description Tests for LibraryAssetService (question/section repository).
 */
@IsTest
private class LibraryAssetServiceTest {

    @TestSetup
    static void setup() {
        FeatureUtil.testIsFormBuilderAdminOverride = null;
        TestDataFactory.assignFormsAdminToRunningUser();
        insert new Form_Builder_Settings__c(
            SetupOwnerId = UserInfo.getUserId(),
            C_Enable_Scoring__c = true,
            C_Enable_Field_Mapping__c = true,
            C_Enable_Translations__c = true,
            C_Enable_Asset_Repository__c = true
        );
    }

    @IsTest
    static void testPromoteQuestionThenInjectIntoForm() {
        C_Form__c userForm = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(userForm.Id, 1);
        C_Section__c sec = TestDataFactory.createSection(page.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();
        C_Question__c q = new C_Question__c(
            Name = 'Email',
            C_Section__c = sec.Id,
            C_Order__c = 1,
            C_Type__c = 'Text',
            C_Question_Text__c = 'Your email',
            C_Is_Required__c = true,
            RecordTypeId = qFormRt
        );
        insert q;

        Test.startTest();
        Id libQId = LibraryAssetService.promoteQuestionToLibrary(q.Id);
        Test.stopTest();

        Id qLibRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Library').getRecordTypeId();
        Id secFormRt = Schema.SObjectType.C_Section__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();
        C_Question__c libQ = [
            SELECT
                Id,
                RecordTypeId,
                C_Section__c,
                C_Section__r.RecordTypeId,
                C_Cross_Field_Rules_JSON__c,
                C_Source_Question__c
            FROM C_Question__c
            WHERE Id = :libQId
        ];
        System.assertEquals(qLibRt, libQ.RecordTypeId);
        System.assertEquals(secFormRt, libQ.C_Section__r.RecordTypeId, 'Question-only library parent is Form RT shell, not a browsable Library section');
        System.assertEquals(null, libQ.C_Cross_Field_Rules_JSON__c);
        System.assertEquals(null, libQ.C_Source_Question__c);

        List<C_Section__c> sectionBrowse = LibraryAssetService.searchLibrarySections('');
        Boolean shellListed = false;
        for (C_Section__c row : sectionBrowse) {
            if (row.Id == libQ.C_Section__c) {
                shellListed = true;
                break;
            }
        }
        System.assertEquals(false, shellListed, 'searchLibrarySections must not list the question-only section shell');

        C_Form__c form2 = new C_Form__c(
            Name = 'Consumer Form',
            C_Status__c = 'Draft',
            C_Version__c = 1,
            C_Default_Language__c = 'en'
        );
        insert form2;
        C_Page__c page2 = TestDataFactory.createPage(form2.Id, 1);
        C_Section__c sec2 = TestDataFactory.createSection(page2.Id, 1, 50);

        Id injectedId = LibraryAssetService.injectLibraryQuestion(libQ.Id, sec2.Id, 0);
        C_Question__c injected = [
            SELECT Id, RecordTypeId, C_Section__c, C_Cross_Field_Rules_JSON__c, C_Source_Question__c
            FROM C_Question__c
            WHERE Id = :injectedId
        ];
        System.assertEquals(qFormRt, injected.RecordTypeId);
        System.assertEquals(sec2.Id, injected.C_Section__c);
        System.assertEquals(null, injected.C_Source_Question__c);

        Integer fmCount = [SELECT COUNT() FROM C_Field_Mapping__c WHERE C_Question__c = :injectedId];
        System.assertEquals(0, fmCount, 'Injected clone should not have field mappings');
    }

    @IsTest
    static void testPromoteSectionToLibrary() {
        C_Form__c userForm = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(userForm.Id, 1);
        C_Section__c sec = TestDataFactory.createSection(page.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();
        insert new C_Question__c(
            Name = 'Q1',
            C_Section__c = sec.Id,
            C_Order__c = 1,
            C_Type__c = 'Text',
            C_Question_Text__c = 'T',
            RecordTypeId = qFormRt
        );

        Test.startTest();
        Id libSecId = LibraryAssetService.promoteSectionToLibrary(sec.Id);
        Test.stopTest();

        Id secLibRt = Schema.SObjectType.C_Section__c.getRecordTypeInfosByDeveloperName().get('Library').getRecordTypeId();
        C_Section__c libSec = [SELECT Id, RecordTypeId FROM C_Section__c WHERE Id = :libSecId];
        System.assertEquals(secLibRt, libSec.RecordTypeId);
        Integer libQs = [SELECT COUNT() FROM C_Question__c WHERE C_Section__c = :libSecId];
        System.assertEquals(1, libQs);
        C_Question__c libQRow = [SELECT Id, RecordTypeId FROM C_Question__c WHERE C_Section__c = :libSecId LIMIT 1];
        System.assertEquals(qFormRt, libQRow.RecordTypeId, 'Section promote: questions stay Form RT; only the section is a library asset');

        List<C_Question__c> qBrowse = LibraryAssetService.searchLibraryQuestions('Q1');
        Boolean listed = false;
        for (C_Question__c row : qBrowse) {
            if (row.Id == libQRow.Id) {
                listed = true;
                break;
            }
        }
        System.assertEquals(false, listed, 'searchLibraryQuestions must list standalone library questions only, not section-owned copies');
    }

    /**
     * Mirrors list-view scenarios: several languages and fields (including question Name) on one question.
     */
    @IsTest
    static void testPromoteSectionCopiesMultiLanguageTranslations() {
        C_Form__c userForm = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(userForm.Id, 1);
        C_Section__c sec = TestDataFactory.createSection(page.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();
        C_Question__c q = new C_Question__c(
            Name = 'PickQ',
            C_Section__c = sec.Id,
            C_Order__c = 1,
            C_Type__c = 'Picklist',
            C_Question_Text__c = 'Pick text',
            C_Is_Required__c = false,
            RecordTypeId = qFormRt
        );
        insert q;

        insert new List<C_Translation__c>{
            new C_Translation__c(
                Name = 'fr-qt',
                C_Language__c = 'fr',
                C_Translated_Text__c = 'FR',
                C_Field_Name__c = 'C_Question_Text__c',
                C_Question__c = q.Id
            ),
            new C_Translation__c(
                Name = 'nl-ph',
                C_Language__c = 'nl',
                C_Translated_Text__c = 'NL',
                C_Field_Name__c = 'C_Placeholder__c',
                C_Question__c = q.Id
            ),
            new C_Translation__c(
                Name = 'nl-qt',
                C_Language__c = 'nl',
                C_Translated_Text__c = 'NL',
                C_Field_Name__c = 'C_Question_Text__c',
                C_Question__c = q.Id
            ),
            new C_Translation__c(
                Name = 'nl-help',
                C_Language__c = 'nl',
                C_Translated_Text__c = 'NL',
                C_Field_Name__c = 'C_Help_Text__c',
                C_Question__c = q.Id
            ),
            new C_Translation__c(
                Name = 'de-name',
                C_Language__c = 'de',
                C_Translated_Text__c = 'DE',
                C_Field_Name__c = 'Name',
                C_Question__c = q.Id
            ),
            new C_Translation__c(
                Name = 'pt-help',
                C_Language__c = 'pt',
                C_Translated_Text__c = 'PT',
                C_Field_Name__c = 'C_Help_Text__c',
                C_Question__c = q.Id
            ),
            new C_Translation__c(
                Name = 'pt-ph',
                C_Language__c = 'pt',
                C_Translated_Text__c = 'PT',
                C_Field_Name__c = 'C_Placeholder__c',
                C_Question__c = q.Id
            )
        };

        Test.startTest();
        Id libSecId = LibraryAssetService.promoteSectionToLibrary(sec.Id);
        Test.stopTest();

        Id libQId = [SELECT Id FROM C_Question__c WHERE C_Section__c = :libSecId LIMIT 1].Id;
        Integer total = [
            SELECT COUNT()
            FROM C_Translation__c
            WHERE C_Section__c = :libSecId OR C_Question__c = :libQId
        ];
        System.assertEquals(7, total, 'all question-anchored translations should copy to the library subtree');

        List<C_Translation__c> deNameRows = [
            SELECT C_Translated_Text__c
            FROM C_Translation__c
            WHERE C_Question__c = :libQId AND C_Language__c = 'de' AND C_Field_Name__c = 'Name'
        ];
        System.assertEquals(1, deNameRows.size());
        System.assertEquals('DE', deNameRows[0].C_Translated_Text__c);

        List<C_Translation__c> frQtAnchors = [
            SELECT C_Page__c, C_Section__c, C_Question__c
            FROM C_Translation__c
            WHERE C_Question__c = :libQId AND C_Language__c = 'fr' AND C_Field_Name__c = 'C_Question_Text__c'
        ];
        System.assertEquals(1, frQtAnchors.size());
        System.assertEquals(null, frQtAnchors[0].C_Page__c, 'promoted question translation should not duplicate page anchor');
        System.assertEquals(null, frQtAnchors[0].C_Section__c, 'promoted question translation should not duplicate section anchor');
    }

    /**
     * Legacy section-only row for a question inline field is re-attached to the sole question when promoting/injecting a one-question section.
     */
    @IsTest
    static void testInjectSectionRepairsSectionScopedQuestionFieldTranslation() {
        C_Form__c srcForm = TestDataFactory.createForm();
        C_Page__c srcPage = TestDataFactory.createPage(srcForm.Id, 1);
        C_Section__c srcSec = TestDataFactory.createSection(srcPage.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();
        C_Question__c srcQ = new C_Question__c(
            Name = 'OnlyQ',
            C_Section__c = srcSec.Id,
            C_Order__c = 1,
            C_Type__c = 'Text',
            C_Question_Text__c = 'Hello',
            C_Is_Required__c = false,
            RecordTypeId = qFormRt
        );
        insert srcQ;

        insert new C_Translation__c(
            Name = 'legacy-fr-qt',
            C_Language__c = 'fr',
            C_Translated_Text__c = 'FR section scoped',
            C_Field_Name__c = 'C_Question_Text__c',
            C_Section__c = srcSec.Id
        );

        C_Form__c dstForm = new C_Form__c(
            Name = 'Inject target form',
            C_Status__c = 'Draft',
            C_Version__c = 1,
            C_Default_Language__c = 'en'
        );
        insert dstForm;
        C_Page__c dstPage = TestDataFactory.createPage(dstForm.Id, 1);

        Test.startTest();
        Id libSecId = LibraryAssetService.promoteSectionToLibrary(srcSec.Id);
        Id injectedSecId = LibraryAssetService.injectLibrarySection(libSecId, dstPage.Id, 0);
        Test.stopTest();

        Id libQId = [SELECT Id FROM C_Question__c WHERE C_Section__c = :libSecId LIMIT 1].Id;
        List<C_Translation__c> libFr = [
            SELECT C_Page__c, C_Section__c, C_Question__c, C_Translated_Text__c
            FROM C_Translation__c
            WHERE C_Question__c = :libQId AND C_Language__c = 'fr' AND C_Field_Name__c = 'C_Question_Text__c'
        ];
        System.assertEquals(1, libFr.size(), 'heuristic should attach section-scoped question text to the single library question');
        System.assertEquals('FR section scoped', libFr[0].C_Translated_Text__c);
        System.assertEquals(null, libFr[0].C_Page__c);
        System.assertEquals(null, libFr[0].C_Section__c);

        Id injectedQId = [SELECT Id FROM C_Question__c WHERE C_Section__c = :injectedSecId LIMIT 1].Id;

        List<C_Translation__c> injFr = [
            SELECT C_Page__c, C_Section__c, C_Question__c, C_Translated_Text__c
            FROM C_Translation__c
            WHERE C_Question__c = :injectedQId AND C_Language__c = 'fr' AND C_Field_Name__c = 'C_Question_Text__c'
        ];
        System.assertEquals(1, injFr.size());
        System.assertEquals('FR section scoped', injFr[0].C_Translated_Text__c);
        System.assertEquals(null, injFr[0].C_Page__c);
        System.assertEquals(null, injFr[0].C_Section__c);
    }

    @IsTest
    static void testInjectLibraryQuestionUsesInlineTranslationAnchors() {
        C_Form__c srcForm = TestDataFactory.createForm();
        C_Page__c srcPage = TestDataFactory.createPage(srcForm.Id, 1);
        C_Section__c srcSec = TestDataFactory.createSection(srcPage.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();
        C_Question__c srcQ = new C_Question__c(
            Name = 'LibSrcQ',
            C_Section__c = srcSec.Id,
            C_Order__c = 1,
            C_Type__c = 'Text',
            C_Question_Text__c = 'Q',
            C_Is_Required__c = false,
            RecordTypeId = qFormRt
        );
        insert srcQ;
        insert new C_Translation__c(
            Name = 'pt-qt',
            C_Language__c = 'pt',
            C_Translated_Text__c = 'PT val',
            C_Field_Name__c = 'C_Question_Text__c',
            C_Question__c = srcQ.Id
        );

        C_Form__c dstForm = new C_Form__c(
            Name = 'Q inject target',
            C_Status__c = 'Draft',
            C_Version__c = 1,
            C_Default_Language__c = 'en'
        );
        insert dstForm;
        C_Page__c dstPage = TestDataFactory.createPage(dstForm.Id, 1);
        C_Section__c dstSec = TestDataFactory.createSection(dstPage.Id, 1, 50);

        Test.startTest();
        Id libQId = LibraryAssetService.promoteQuestionToLibrary(srcQ.Id);
        Id injectedQId = LibraryAssetService.injectLibraryQuestion(libQId, dstSec.Id, 0);
        Test.stopTest();

        List<C_Translation__c> inj = [
            SELECT C_Page__c, C_Section__c, C_Question__c
            FROM C_Translation__c
            WHERE C_Question__c = :injectedQId AND C_Language__c = 'pt' AND C_Field_Name__c = 'C_Question_Text__c'
        ];
        System.assertEquals(1, inj.size());
        System.assertEquals(null, inj[0].C_Page__c);
        System.assertEquals(null, inj[0].C_Section__c);
        System.assertEquals(injectedQId, inj[0].C_Question__c);
    }

    @IsTest
    static void testInjectIntoLibraryFormBlocked() {
        C_Form__c srcForm = TestDataFactory.createForm();
        C_Page__c srcPage = TestDataFactory.createPage(srcForm.Id, 1);
        C_Section__c srcSec = TestDataFactory.createSection(srcPage.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();

        C_Question__c srcQ = new C_Question__c(
            Name = 'GuardQ',
            C_Section__c = srcSec.Id,
            C_Order__c = 1,
            C_Type__c = 'Text',
            C_Question_Text__c = 'Guard text',
            RecordTypeId = qFormRt
        );
        insert srcQ;

        Id libQId = LibraryAssetService.promoteQuestionToLibrary(srcQ.Id);
        Id libFormId = LibraryAssetService.getAssetLibraryFormId();
        Id libSectionId = [
            SELECT Id
            FROM C_Section__c
            WHERE C_Page__r.C_Form__c = :libFormId
            LIMIT 1
        ].Id;

        Boolean threw = false;
        try {
            LibraryAssetService.injectLibraryQuestion(libQId, libSectionId, 0);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Expected guard to block injecting into hidden library form');
    }

    @IsTest
    static void testPermissionDeniedAcrossAuraEndpoints() {
        FeatureUtil.testIsFormBuilderAdminOverride = false;
        Integer denied = 0;
        try { LibraryAssetService.getAssetLibraryFormId(); } catch (AuraHandledException e) { denied++; }
        try { LibraryAssetService.searchLibraryQuestions('x'); } catch (AuraHandledException e) { denied++; }
        try { LibraryAssetService.searchLibrarySections('x'); } catch (AuraHandledException e) { denied++; }
        try { LibraryAssetService.promoteQuestionToLibrary(null); } catch (AuraHandledException e) { denied++; }
        try { LibraryAssetService.promoteSectionToLibrary(null); } catch (AuraHandledException e) { denied++; }
        try { LibraryAssetService.injectLibraryQuestion(null, null, 0); } catch (AuraHandledException e) { denied++; }
        try { LibraryAssetService.injectLibrarySection(null, null, 0); } catch (AuraHandledException e) { denied++; }
        FeatureUtil.testIsFormBuilderAdminOverride = null;

        System.assertEquals(7, denied, 'All endpoints should reject non-admin access');
    }

    @IsTest
    static void testBulkSectionPromoteAndInject() {
        C_Form__c srcForm = TestDataFactory.createForm();
        C_Page__c srcPage = TestDataFactory.createPage(srcForm.Id, 1);
        C_Section__c srcSec = TestDataFactory.createSection(srcPage.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();

        List<C_Question__c> questions = new List<C_Question__c>();
        for (Integer i = 1; i <= 6; i++) {
            questions.add(new C_Question__c(
                Name = 'BulkQ' + i,
                C_Section__c = srcSec.Id,
                C_Order__c = i,
                C_Type__c = 'Text',
                C_Question_Text__c = 'Question ' + i,
                RecordTypeId = qFormRt
            ));
        }
        insert questions;

        List<C_Response__c> responses = new List<C_Response__c>();
        for (C_Question__c q : questions) {
            responses.add(new C_Response__c(
                Name = q.Name + '-R1',
                C_Question__c = q.Id,
                C_Order__c = 1,
                C_Response_Text__c = 'Yes'
            ));
            responses.add(new C_Response__c(
                Name = q.Name + '-R2',
                C_Question__c = q.Id,
                C_Order__c = 2,
                C_Response_Text__c = 'No'
            ));
        }
        insert responses;

        C_Form__c dstForm = new C_Form__c(
            Name = 'Bulk Target',
            C_Status__c = 'Draft',
            C_Version__c = 1,
            C_Default_Language__c = 'en'
        );
        insert dstForm;
        C_Page__c dstPage = TestDataFactory.createPage(dstForm.Id, 1);

        Test.startTest();
        Id libSecId = LibraryAssetService.promoteSectionToLibrary(srcSec.Id);
        Id injectedSecId = LibraryAssetService.injectLibrarySection(libSecId, dstPage.Id, 0);
        Test.stopTest();

        Integer injectedQuestionCount = [SELECT COUNT() FROM C_Question__c WHERE C_Section__c = :injectedSecId];
        Integer injectedResponseCount = [
            SELECT COUNT()
            FROM C_Response__c
            WHERE C_Question__c IN (SELECT Id FROM C_Question__c WHERE C_Section__c = :injectedSecId)
        ];
        System.assertEquals(6, injectedQuestionCount);
        System.assertEquals(12, injectedResponseCount);
    }

    @IsTest
    static void testSearchLibraryQuestionsFilter() {
        C_Form__c srcForm = TestDataFactory.createForm();
        C_Page__c srcPage = TestDataFactory.createPage(srcForm.Id, 1);
        C_Section__c srcSec = TestDataFactory.createSection(srcPage.Id, 1, 50);
        Id qFormRt = Schema.SObjectType.C_Question__c.getRecordTypeInfosByDeveloperName().get('Form').getRecordTypeId();

        C_Question__c emailQ = new C_Question__c(
            Name = 'Email',
            C_Section__c = srcSec.Id,
            C_Order__c = 1,
            C_Type__c = 'Text',
            C_Question_Text__c = 'Email',
            RecordTypeId = qFormRt
        );
        C_Question__c phoneQ = new C_Question__c(
            Name = 'Phone',
            C_Section__c = srcSec.Id,
            C_Order__c = 2,
            C_Type__c = 'Text',
            C_Question_Text__c = 'Phone',
            RecordTypeId = qFormRt
        );
        insert new List<C_Question__c>{ emailQ, phoneQ };

        Id libEmailId = LibraryAssetService.promoteQuestionToLibrary(emailQ.Id);
        Id libPhoneId = LibraryAssetService.promoteQuestionToLibrary(phoneQ.Id);

        List<C_Question__c> searchResults = LibraryAssetService.searchLibraryQuestions('Email');
        System.assertEquals(1, searchResults.size(), 'Filter should return only matching rows');
        System.assertEquals(libEmailId, searchResults[0].Id);
        System.assertNotEquals(libPhoneId, searchResults[0].Id);
    }

    @IsTest
    static void testGetAssetLibraryFormId() {
        Test.startTest();
        Id libFormId = LibraryAssetService.getAssetLibraryFormId();
        Test.stopTest();

        System.assertNotEquals(null, libFormId);
        C_Form__c libForm = [
            SELECT Id, Name, C_Hide_From_Form_Builder__c
            FROM C_Form__c
            WHERE Id = :libFormId
        ];
        System.assertEquals('Form Builder — Asset Library', libForm.Name);
        System.assertEquals(true, libForm.C_Hide_From_Form_Builder__c);
    }

    @IsTest
    static void testDeleteHiddenFormBlocked() {
        C_Form__c hidden = new C_Form__c(
            Name = 'Hidden Internal Form',
            C_Status__c = 'Draft',
            C_Version__c = 1,
            C_Default_Language__c = 'en',
            C_Hide_From_Form_Builder__c = true
        );
        insert hidden;

        Boolean threw = false;
        try {
            FormBuilderService.deleteForm(hidden.Id);
        } catch (Exception e) {
            threw = true;
        }
        System.assert(threw, 'Expected delete to be blocked for hidden form');
    }
}

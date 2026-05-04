/**
 * @description       : Test class for TranslationService
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
private class TranslationServiceTest {

    @TestSetup
    static void setupTestData() {
        FeatureUtil.testIsFormBuilderAdminOverride = null;
        C_Form__c form = TestDataFactory.createForm();
        C_Page__c page = TestDataFactory.createPage(form.Id, 1);
        C_Section__c section = TestDataFactory.createSection(page.Id, 1, 50);
        C_Question__c question = TestDataFactory.createQuestion(section.Id, 1, 'Picklist');
        C_Response__c response = TestDataFactory.createResponse(question.Id, 1, 10);

        insert new C_Translation__c(
            Name = 'fr Page Translation',
            C_Language__c = 'fr',
            C_Translated_Text__c = 'Page traduite',
            C_Field_Name__c = 'Name',
            C_Page__c = page.Id
        );
        insert new C_Translation__c(
            Name = 'fr Section Translation',
            C_Language__c = 'fr',
            C_Translated_Text__c = 'Section traduite',
            C_Field_Name__c = 'Name',
            C_Section__c = section.Id
        );
        insert new C_Translation__c(
            Name = 'fr Question Translation',
            C_Language__c = 'fr',
            C_Translated_Text__c = 'Question traduite',
            C_Field_Name__c = 'C_Question_Text__c',
            C_Question__c = question.Id
        );
        insert new C_Translation__c(
            Name = 'fr Response Translation',
            C_Language__c = 'fr',
            C_Translated_Text__c = 'Réponse traduite',
            C_Field_Name__c = 'C_Response_Text__c',
            C_Response__c = response.Id
        );
    }

    @IsTest
    static void testGetTranslations() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];
        C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
        C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];

        Test.startTest();
        Map<String, String> translations = TranslationService.getTranslations(form.Id, 'fr');
        Test.stopTest();

        Assert.areEqual(4, translations.size(), 'Should return 4 translations');
        Assert.areEqual('Page traduite', translations.get('Page_' + page.Id + '_Name'));
        Assert.areEqual('Section traduite', translations.get('Section_' + section.Id + '_Name'));
        Assert.areEqual('Question traduite', translations.get('Question_' + question.Id + '_C_Question_Text__c'));
        Assert.areEqual('Réponse traduite', translations.get('Response_' + response.Id + '_C_Response_Text__c'));
    }

    /**
     * Rows created by library inject (and similar) may denormalize Page + Section + Question on one translation.
     * Keys must match formRenderer lookups (Question_id_field), not Page_id_field.
     */
    @IsTest
    static void testGetTranslations_denormalizedQuestionRowUsesQuestionKey() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];
        C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];

        insert new C_Translation__c(
            Name = 'de denorm Question',
            C_Language__c = 'de',
            C_Translated_Text__c = 'Denorm fragetext',
            C_Field_Name__c = 'C_Question_Text__c',
            C_Page__c = page.Id,
            C_Section__c = section.Id,
            C_Question__c = question.Id
        );

        Test.startTest();
        Map<String, String> translations = TranslationService.getTranslations(form.Id, 'de');
        Test.stopTest();

        Assert.areEqual(
            'Denorm fragetext',
            translations.get('Question_' + question.Id + '_C_Question_Text__c'),
            'Most specific lookup (Question) must win over Page/Section on same row'
        );
        Assert.isFalse(
            translations.containsKey('Page_' + page.Id + '_C_Question_Text__c'),
            'Should not key denormalized row as Page_'
        );
    }

    @IsTest
    static void testGetTranslationsBlankLanguageReturnsEmpty() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        Test.startTest();
        Map<String, String> translations = TranslationService.getTranslations(form.Id, '');
        Test.stopTest();

        Assert.isTrue(translations.isEmpty(), 'Blank language should return empty map');
    }

    @IsTest
    static void testSaveTranslationCreateNew() {
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];

        Test.startTest();
        TranslationService.saveTranslation('nl', 'Nederlandse vertaling', 'C_Question_Text__c', null, null, null, question.Id, null);
        Test.stopTest();

        List<C_Translation__c> created = [
            SELECT Id, C_Translated_Text__c, C_Language__c
            FROM C_Translation__c
            WHERE C_Question__c = :question.Id AND C_Language__c = 'nl'
        ];
        Assert.areEqual(1, created.size(), 'Should create one new translation');
        Assert.areEqual('Nederlandse vertaling', created[0].C_Translated_Text__c);
    }

    @IsTest
    static void testSaveTranslationUpdateExisting() {
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];

        Test.startTest();
        TranslationService.saveTranslation('fr', 'Texte mis à jour', 'Name', null, page.Id, null, null, null);
        Test.stopTest();

        C_Translation__c updated = [
            SELECT C_Translated_Text__c
            FROM C_Translation__c
            WHERE C_Page__c = :page.Id AND C_Language__c = 'fr' AND C_Field_Name__c = 'Name'
            LIMIT 1
        ];
        Assert.areEqual('Texte mis à jour', updated.C_Translated_Text__c);
    }

    @IsTest
    static void saveTranslation_withSevenParameterOverload_createsRecord() {
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];

        Test.startTest();
        TranslationService.saveTranslation('de', 'Seite', 'Name', page.Id, null, null, null);
        Test.stopTest();

        List<C_Translation__c> created = [
            SELECT C_Translated_Text__c
            FROM C_Translation__c
            WHERE C_Page__c = :page.Id AND C_Language__c = 'de' AND C_Field_Name__c = 'Name'
        ];
        Assert.areEqual(1, created.size(), 'Seven-param overload should persist like eight-param with null category');
        Assert.areEqual('Seite', created[0].C_Translated_Text__c);
    }

    @IsTest
    static void getElementTranslations_returnsFieldMap() {
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];

        Test.startTest();
        Map<String, String> result = TranslationService.getElementTranslations('page', page.Id, 'fr');
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should return one translation for the page');
        Assert.areEqual('Page traduite', result.get('Name'));
    }

    @IsTest
    static void getElementTranslations_blankInputsReturnEmpty() {
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];

        Test.startTest();
        Map<String, String> result1 = TranslationService.getElementTranslations('', null, '');
        Map<String, String> result2 = TranslationService.getElementTranslations('invalid', page.Id, 'fr');
        Map<String, String> result3 = TranslationService.getElementTranslations('page', null, 'fr');
        Test.stopTest();

        Assert.isTrue(result1.isEmpty(), 'Blank inputs should return empty map');
        Assert.isTrue(result2.isEmpty(), 'Invalid element type should return empty map');
        Assert.isTrue(result3.isEmpty(), 'Null elementId should return empty map');
    }

    @IsTest
    static void getElementTranslations_questionReturnsMultipleFields() {
        C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];

        Test.startTest();
        Map<String, String> result = TranslationService.getElementTranslations('question', question.Id, 'fr');
        Test.stopTest();

        Assert.areEqual('Question traduite', result.get('C_Question_Text__c'));
    }

    @IsTest
    static void getAllElementTranslations_returnsAllLanguages() {
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];

        insert new C_Translation__c(
            Name = 'nl Page Translation',
            C_Language__c = 'nl',
            C_Translated_Text__c = 'Pagina vertaald',
            C_Field_Name__c = 'Name',
            C_Page__c = page.Id
        );

        Test.startTest();
        List<Map<String, String>> result = TranslationService.getAllElementTranslations('page', page.Id);
        Test.stopTest();

        Assert.isTrue(result.size() >= 2, 'Should return translations for fr and nl');
        Boolean foundFr = false;
        Boolean foundNl = false;
        for (Map<String, String> row : result) {
            if (row.get('language') == 'fr') foundFr = true;
            if (row.get('language') == 'nl') foundNl = true;
            Assert.isNotNull(row.get('id'), 'Each row should have an id');
            Assert.isNotNull(row.get('fieldName'), 'Each row should have a fieldName');
        }
        Assert.isTrue(foundFr, 'Should contain French translation');
        Assert.isTrue(foundNl, 'Should contain Dutch translation');
    }

    @IsTest
    static void getAllElementTranslations_blankInputsReturnEmpty() {
        Test.startTest();
        List<Map<String, String>> result = TranslationService.getAllElementTranslations('', null);
        Test.stopTest();

        Assert.isTrue(result.isEmpty(), 'Blank inputs should return empty list');
    }

    @IsTest
    static void deleteTranslation_removesRecord() {
        C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];
        C_Translation__c t = [
            SELECT Id FROM C_Translation__c
            WHERE C_Page__c = :page.Id AND C_Language__c = 'fr' LIMIT 1
        ];

        Test.startTest();
        TranslationService.deleteTranslation(t.Id);
        Test.stopTest();

        List<C_Translation__c> remaining = [
            SELECT Id FROM C_Translation__c WHERE Id = :t.Id
        ];
        Assert.isTrue(remaining.isEmpty(), 'Translation should be deleted');
    }

    @IsTest
    static void testGetAvailableLanguages() {
        C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

        Test.startTest();
        List<String> languages = TranslationService.getAvailableLanguages(form.Id);
        Test.stopTest();

        Assert.isFalse(languages.isEmpty(), 'Should return at least one language from the picklist');
    }
}

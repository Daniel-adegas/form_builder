/**
 * @description       : Test class for FeatureSettingsService
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
private class FeatureSettingsServiceTest {

    @TestSetup
    static void clearFormBuilderAdminOverride() {
        FeatureUtil.testIsFormBuilderAdminOverride = null;
    }

    @IsTest
    static void testGetFeatureSettingsDefaults() {
        Test.startTest();
        Map<String, Boolean> settings = FeatureSettingsService.getFeatureSettings();
        Test.stopTest();

        Assert.areEqual(true, settings.get('scoring'), 'Scoring should default to true');
        Assert.areEqual(true, settings.get('fieldMapping'), 'Field mapping should default to true');
        Assert.areEqual(true, settings.get('translations'), 'Translations should default to true');
        Assert.areEqual(false, settings.get('assetRepository'), 'Asset repository should default to false');
        Assert.areEqual(false, settings.get('characterCountdown'), 'Character countdown should default to false when no hierarchy row');
        Assert.areEqual(false, settings.get('responseRecords'), 'Response records should default to false');
    }

    @IsTest
    static void testGetFeatureSettingsScoringDisabled() {
        Form_Builder_Settings__c customSettings = new Form_Builder_Settings__c(
            SetupOwnerId = UserInfo.getUserId(),
            C_Enable_Scoring__c = false,
            C_Enable_Field_Mapping__c = true,
            C_Enable_Translations__c = true
        );
        insert customSettings;

        Test.startTest();
        Map<String, Boolean> settings = FeatureSettingsService.getFeatureSettings();
        Test.stopTest();

        Assert.areEqual(false, settings.get('scoring'), 'Scoring should be disabled');
        Assert.areEqual(true, settings.get('fieldMapping'), 'Field mapping should remain enabled');
        Assert.areEqual(true, settings.get('translations'), 'Translations should remain enabled');
        Assert.areEqual(false, settings.get('characterCountdown'), 'Character countdown should be off when not enabled on row');
        Assert.areEqual(false, settings.get('responseRecords'), 'Response records should be off when not enabled on row');
    }

    @IsTest
    static void testGetFeatureSettingsCharacterCountdownEnabled() {
        Form_Builder_Settings__c customSettings = new Form_Builder_Settings__c(
            SetupOwnerId = UserInfo.getUserId(),
            C_Enable_Scoring__c = true,
            C_Enable_Field_Mapping__c = true,
            C_Enable_Translations__c = true,
            C_Enable_Character_Countdown__c = true
        );
        insert customSettings;

        Test.startTest();
        Map<String, Boolean> settings = FeatureSettingsService.getFeatureSettings();
        Test.stopTest();

        Assert.areEqual(true, settings.get('characterCountdown'), 'Character countdown should be on when enabled on row');
    }

    @IsTest
    static void testGetFeatureSettingsResponseRecordsEnabled() {
        Form_Builder_Settings__c customSettings = new Form_Builder_Settings__c(
            SetupOwnerId = UserInfo.getUserId(),
            C_Enable_Scoring__c = true,
            C_Enable_Field_Mapping__c = true,
            C_Enable_Translations__c = true,
            C_Enable_Response_Records__c = true
        );
        insert customSettings;

        Test.startTest();
        Map<String, Boolean> settings = FeatureSettingsService.getFeatureSettings();
        Test.stopTest();

        Assert.areEqual(true, settings.get('responseRecords'), 'Response records should be on when enabled on row');
    }

    @IsTest
    static void testGetFeatureSettingsResponseRecordsFromOrgDefaults() {
        Form_Builder_Settings__c orgDefaults = Form_Builder_Settings__c.getOrgDefaults();
        orgDefaults.C_Enable_Response_Records__c = true;
        upsert orgDefaults;

        Test.startTest();
        Map<String, Boolean> settings = FeatureSettingsService.getFeatureSettings();
        Test.stopTest();

        Assert.areEqual(true, settings.get('responseRecords'),
            'Response records should be on when enabled at org-default level (no user/profile row)');
    }
}
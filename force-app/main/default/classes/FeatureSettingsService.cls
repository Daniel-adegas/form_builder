/**
 * @description       : Service class for reading Form Builder feature toggle settings (Hierarchy Custom Setting)
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
public with sharing class FeatureSettingsService {

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getFeatureSettings() {
        try {
            Form_Builder_Settings__c settings = Form_Builder_Settings__c.getInstance();
            Map<String, Boolean> result = new Map<String, Boolean>();

            if (settings == null || settings.Id == null) {
                Form_Builder_Settings__c defaultSettings = Form_Builder_Settings__c.getOrgDefaults();
                if (defaultSettings == null || defaultSettings.Id == null) {
                    result.put('scoring', true);
                    result.put('fieldMapping', true);
                    result.put('translations', true);
                    result.put('assetRepository', false);
                    result.put('characterCountdown', false);
                    result.put('responseRecords', false);
                    return result;
                }
                settings = defaultSettings;
            }

            result.put('scoring', settings.C_Enable_Scoring__c == true);
            result.put('fieldMapping', settings.C_Enable_Field_Mapping__c == true);
            result.put('translations', settings.C_Enable_Translations__c == true);
            result.put('assetRepository', settings.C_Enable_Asset_Repository__c == true);
            result.put('characterCountdown', settings.C_Enable_Character_Countdown__c == true);
            result.put('responseRecords', settings.C_Enable_Response_Records__c == true);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
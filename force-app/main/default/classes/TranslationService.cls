/**
 * @description       : Service class for managing multi-language translations for form elements
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   18-03-2026   Daniel Murracas     Added error handling
 * ------------------------------------------------------------
**/
public with sharing class TranslationService {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getTranslations(Id formId, String language) {
        try {
            if (String.isBlank(language)) return new Map<String, String>();
            return new TranslationReader().loadTranslations(formId, language);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private without sharing class TranslationReader {
        public Map<String, String> loadTranslations(Id formId, String language) {
            Map<String, String> translationMap = new Map<String, String>();

            Set<Id> categoryIds = new Set<Id>();
            for (C_Category__c cat : [SELECT Id FROM C_Category__c WHERE C_Form__c = :formId]) categoryIds.add(cat.Id);
            Set<Id> pageIds = new Set<Id>();
            for (C_Page__c p : [SELECT Id FROM C_Page__c WHERE C_Form__c = :formId]) pageIds.add(p.Id);
            Set<Id> sectionIds = new Set<Id>();
            for (C_Section__c s : [SELECT Id FROM C_Section__c WHERE C_Page__c IN :pageIds]) sectionIds.add(s.Id);
            Set<Id> questionIds = new Set<Id>();
            for (C_Question__c q : [SELECT Id FROM C_Question__c WHERE C_Section__c IN :sectionIds]) questionIds.add(q.Id);
            Set<Id> responseIds = new Set<Id>();
            for (C_Response__c r : [SELECT Id FROM C_Response__c WHERE C_Question__c IN :questionIds]) responseIds.add(r.Id);

            for (C_Translation__c t : [
                SELECT Id, C_Language__c, C_Translated_Text__c, C_Field_Name__c,
                       C_Category__c, C_Page__c, C_Section__c, C_Question__c, C_Response__c
                FROM C_Translation__c
                WHERE C_Language__c = :language
                AND (C_Category__c IN :categoryIds OR C_Page__c IN :pageIds OR C_Section__c IN :sectionIds
                     OR C_Question__c IN :questionIds OR C_Response__c IN :responseIds)
            ]) {
                String key = buildKey(t);
                if (key != null) translationMap.put(key, t.C_Translated_Text__c);
            }
            return translationMap;
        }

        /**
         * Use the most specific anchor first (leaf -> root).
         * Clone/repository paths can temporarily populate multiple lookups on one row; prioritizing
         * Response/Question/Section prevents broad Page/Category keys from overriding specific translations.
         */ 
        private String buildKey(C_Translation__c t) {
            String fieldName = t.C_Field_Name__c != null ? t.C_Field_Name__c : 'Name';
            if (t.C_Response__c != null) {
                return 'Response_' + t.C_Response__c + '_' + fieldName;
            }
            if (t.C_Question__c != null) {
                return 'Question_' + t.C_Question__c + '_' + fieldName;
            }
            if (t.C_Section__c != null) {
                return 'Section_' + t.C_Section__c + '_' + fieldName;
            }
            if (t.C_Page__c != null) {
                return 'Page_' + t.C_Page__c + '_' + fieldName;
            }
            if (t.C_Category__c != null) {
                return 'Category_' + t.C_Category__c + '_' + fieldName;
            }
            return null;
        }
    }
    
    @AuraEnabled
    public static void saveTranslation(
        String language, 
        String translatedText, 
        String fieldName,
        Id categoryId,
        Id pageId, 
        Id sectionId, 
        Id questionId, 
        Id responseId
    ) {
        try {
            String soql = 'SELECT Id FROM C_Translation__c WHERE C_Language__c = :language AND C_Field_Name__c = :fieldName';
            if (categoryId != null) {
                soql += ' AND C_Category__c = :categoryId';
            } else {
                soql += ' AND C_Category__c = null';
            }
            if (pageId != null) {
                soql += ' AND C_Page__c = :pageId';
            } else {
                soql += ' AND C_Page__c = null';
            }
            if (sectionId != null) {
                soql += ' AND C_Section__c = :sectionId';
            } else {
                soql += ' AND C_Section__c = null';
            }
            if (questionId != null) {
                soql += ' AND C_Question__c = :questionId';
            } else {
                soql += ' AND C_Question__c = null';
            }
            if (responseId != null) {
                soql += ' AND C_Response__c = :responseId';
            } else {
                soql += ' AND C_Response__c = null';
            }
            soql += ' LIMIT 1';
            List<C_Translation__c> existing = Database.query(soql);
            
            C_Translation__c translation;
            if (!existing.isEmpty()) {
                translation = existing[0];
            } else {
                translation = new C_Translation__c();
                translation.Name = language + ' Translation';
                translation.C_Language__c = language;
                translation.C_Field_Name__c = fieldName;
                translation.C_Category__c = categoryId;
                translation.C_Page__c = pageId;
                translation.C_Section__c = sectionId;
                translation.C_Question__c = questionId;
                translation.C_Response__c = responseId;
            }
            
            translation.C_Translated_Text__c = translatedText;
            upsert translation;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Saves a translation using the seven-parameter API; category is null.
     */
    public static void saveTranslation(
        String language,
        String translatedText,
        String fieldName,
        Id pageId,
        Id sectionId,
        Id questionId,
        Id responseId
    ) {
        saveTranslation(
            language,
            translatedText,
            fieldName,
            null,
            pageId,
            sectionId,
            questionId,
            responseId
        );
    }
    
    private static final Set<String> VALID_ELEMENT_TYPES = new Set<String>{
        'category', 'page', 'section', 'question', 'response'
    };

    private static final Map<String, String> ELEMENT_LOOKUP_FIELD = new Map<String, String>{
        'category' => 'C_Category__c',
        'page' => 'C_Page__c',
        'section' => 'C_Section__c',
        'question' => 'C_Question__c',
        'response' => 'C_Response__c'
    };

    @AuraEnabled
    public static Map<String, String> getElementTranslations(String elementType, Id elementId, String language) {
        try {
            Map<String, String> result = new Map<String, String>();
            if (String.isBlank(elementType) || elementId == null || String.isBlank(language)) return result;
            String elType = elementType.toLowerCase();
            if (!VALID_ELEMENT_TYPES.contains(elType)) return result;

            String lookupField = ELEMENT_LOOKUP_FIELD.get(elType);
            String soql = 'SELECT C_Field_Name__c, C_Translated_Text__c FROM C_Translation__c'
                + ' WHERE C_Language__c = :language AND ' + lookupField + ' = :elementId';

            for (C_Translation__c t : Database.query(soql)) {
                String fn = t.C_Field_Name__c != null ? t.C_Field_Name__c : 'Name';
                result.put(fn, t.C_Translated_Text__c);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getAllElementTranslations(String elementType, Id elementId) {
        try {
            List<Map<String, String>> results = new List<Map<String, String>>();
            if (String.isBlank(elementType) || elementId == null) return results;
            String elType = elementType.toLowerCase();
            if (!VALID_ELEMENT_TYPES.contains(elType)) return results;

            String lookupField = ELEMENT_LOOKUP_FIELD.get(elType);
            String soql = 'SELECT Id, C_Language__c, C_Field_Name__c, C_Translated_Text__c FROM C_Translation__c'
                + ' WHERE ' + lookupField + ' = :elementId ORDER BY C_Language__c, C_Field_Name__c';

            for (C_Translation__c t : Database.query(soql)) {
                Map<String, String> row = new Map<String, String>();
                row.put('id', t.Id);
                row.put('language', t.C_Language__c);
                row.put('fieldName', t.C_Field_Name__c != null ? t.C_Field_Name__c : 'Name');
                row.put('translatedText', t.C_Translated_Text__c);
                results.add(row);
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteTranslation(Id translationId) {
        try {
            delete [SELECT Id FROM C_Translation__c WHERE Id = :translationId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getAvailableLanguages(Id formId) { // formId parameter retained for backward compatibility (unused)
        try {
            List<String> languages = new List<String>();
            Schema.DescribeFieldResult fieldResult = C_Form__c.C_Default_Language__c.getDescribe();
            for (Schema.PicklistEntry pe : fieldResult.getPicklistValues()) {
                languages.add(pe.getValue());
            }
            return languages;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
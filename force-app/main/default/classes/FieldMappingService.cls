/**
 * @description       : Service class for processing field mappings and writing form data to Salesforce records.
 *                      Supports Form Targets for scalable multi-record writeback with resolution strategies.
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   18-03-2026   Daniel Murracas     Added Form Target support, static values, error handling
 * 2.0   20-03-2026   Daniel Murracas     Dynamic record resolution: keyed context, Running_User, Related_Record
 * ------------------------------------------------------------
**/
public with sharing class FieldMappingService {
    
    @AuraEnabled(cacheable=true)
    public static List<C_Form_Target__c> getFormTargets(Id formId) {
        try {
            return [
                SELECT Id, Name, C_Target_Object__c, C_Resolution_Type__c, C_Record_Operation__c,
                       C_External_Id_Field__c, C_Is_Active__c, C_Order__c, C_Description__c, C_Direction__c,
                       C_Context_Key__c, C_User_Lookup_Field__c, C_Related_Target__c, C_Related_Field_Path__c,
                       (SELECT Id, Name, C_Question__c, C_Question__r.Name, C_Question__r.C_Question_Text__c,
                               C_Target_Field__c, C_Mapping_Type__c, C_Static_Value__c, C_Is_Active__c
                        FROM C_Field_Mappings__r
                        WHERE C_Is_Active__c = true
                        ORDER BY Name)
                FROM C_Form_Target__c
                WHERE C_Form__c = :formId
                AND C_Is_Active__c = true
                ORDER BY C_Order__c
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<C_Form_Target__c> getAllFormTargets(Id formId) {
        try {
            return [
                SELECT Id, Name, C_Target_Object__c, C_Resolution_Type__c, C_Record_Operation__c,
                       C_External_Id_Field__c, C_Is_Active__c, C_Order__c, C_Description__c, C_Direction__c,
                       C_Context_Key__c, C_User_Lookup_Field__c, C_Related_Target__c, C_Related_Field_Path__c,
                       (SELECT Id, Name, C_Question__c, C_Question__r.Name, C_Question__r.C_Question_Text__c,
                               C_Target_Field__c, C_Mapping_Type__c, C_Static_Value__c, C_Is_Active__c
                        FROM C_Field_Mappings__r
                        ORDER BY Name)
                FROM C_Form_Target__c
                WHERE C_Form__c = :formId
                ORDER BY C_Order__c
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Form_Target__c saveFormTarget(C_Form_Target__c target) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }
            upsert target;
            return target;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteFormTarget(Id targetId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }
            delete new C_Form_Target__c(Id = targetId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<C_Field_Mapping__c> getMappingsForTarget(Id formTargetId) {
        try {
            return [
                SELECT Id, Name, C_Question__c, C_Question__r.Name, C_Question__r.C_Question_Text__c,
                       C_Target_Field__c, C_Mapping_Type__c, C_Static_Value__c, C_Is_Active__c,
                       C_Target_Object__c, C_Form_Target__c
                FROM C_Field_Mapping__c
                WHERE C_Form_Target__c = :formTargetId
                ORDER BY Name
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static C_Field_Mapping__c saveFieldMapping(C_Field_Mapping__c mapping) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }
            upsert mapping;
            return mapping;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteFieldMapping(Id mappingId) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions. Forms_Admin permission set required.');
            }
            delete new C_Field_Mapping__c(Id = mappingId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getObjectFields(String objectName) {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions');
            }
            List<Map<String, String>> fields = new List<Map<String, String>>();
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
            if (targetType == null) return fields;

            Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fd = fieldMap.get(fieldName).getDescribe();
                if (fd.isUpdateable() || fd.isCreateable()) {
                    Map<String, String> fieldInfo = new Map<String, String>();
                    fieldInfo.put('value', fd.getName());
                    fieldInfo.put('label', fd.getLabel() + ' (' + fd.getName() + ')');
                    fieldInfo.put('type', String.valueOf(fd.getType()));
                    fields.add(fieldInfo);
                }
            }
            return fields;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getCreatableObjects() {
        try {
            if (!FeatureUtil.isFormBuilderAdmin()) {
                throw new AuraHandledException('Insufficient permissions');
            }
            List<String> sortedNames = new List<String>();
            Map<String, Map<String, String>> objMap = new Map<String, Map<String, String>>();
            for (Schema.SObjectType sot : Schema.getGlobalDescribe().values()) {
                Schema.DescribeSObjectResult dsr = sot.getDescribe();
                if (dsr.isCreateable() && dsr.isUpdateable() && !dsr.isCustomSetting()) {
                    Map<String, String> objInfo = new Map<String, String>();
                    objInfo.put('value', dsr.getName());
                    objInfo.put('label', dsr.getLabel() + ' (' + dsr.getName() + ')');
                    objMap.put(dsr.getLabel(), objInfo);
                    sortedNames.add(dsr.getLabel());
                }
            }
            sortedNames.sort();
            List<Map<String, String>> objects = new List<Map<String, String>>();
            for (String name : sortedNames) {
                objects.add(objMap.get(name));
            }
            return objects;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void processFieldMappings(Id formSubmissionId) {
        new ElevatedContext().doProcessFieldMappings(formSubmissionId);
    }

    @AuraEnabled
    public static Map<String, Object> getPrePopulationData(Id formId, String recordContextJson) {
        try {
            return new ElevatedContext().doGetPrePopulationData(formId, recordContextJson);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getUserLookupFields(String targetObjectName) {
        try {
            List<Map<String, String>> results = new List<Map<String, String>>();
            Map<String, Schema.SObjectField> userFields = Schema.SObjectType.User.fields.getMap();
            for (String fieldName : userFields.keySet()) {
                Schema.DescribeFieldResult fd = userFields.get(fieldName).getDescribe();
                if (fd.getType() != Schema.DisplayType.REFERENCE) continue;
                for (Schema.SObjectType ref : fd.getReferenceTo()) {
                    if (ref.getDescribe().getName() == targetObjectName) {
                        results.add(new Map<String, String>{
                            'value' => fd.getName(),
                            'label' => fd.getLabel() + ' (' + fd.getName() + ')'
                        });
                    }
                }
            }
            if (String.isNotBlank(targetObjectName) && targetObjectName == 'Account') {
                results.add(new Map<String, String>{
                    'value' => 'Contact.AccountId',
                    'label' => 'Contact → Account (Contact.AccountId)'
                });
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private without sharing class ElevatedContext {

        private Map<String, String> parseRecordContext(String recordContextJson) {
            Map<String, String> contextMap = new Map<String, String>();
            if (String.isBlank(recordContextJson)) return contextMap;
            try {
                if (recordContextJson.trim().startsWith('{')) {
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(recordContextJson);
                    for (String key : parsed.keySet()) {
                        Object val = parsed.get(key);
                        if (val != null) contextMap.put(key, String.valueOf(val));
                    }
                } else {
                    contextMap.put('_default', recordContextJson.trim());
                }
            } catch (Exception e) {
                contextMap.put('_default', recordContextJson.trim());
            }
            return contextMap;
        }

        private List<C_Form_Target__c> queryTargets(Id formId, String directionFilter) {
            String baseQuery = 'SELECT Id, C_Target_Object__c, C_Resolution_Type__c, C_Record_Operation__c, '
                + 'C_External_Id_Field__c, C_Order__c, C_Direction__c, C_Context_Key__c, '
                + 'C_User_Lookup_Field__c, C_Related_Target__c, C_Related_Field_Path__c, '
                + '(SELECT Id, C_Question__c, C_Target_Field__c, C_Mapping_Type__c, C_Static_Value__c, C_Question__r.C_Type__c '
                + 'FROM C_Field_Mappings__r WHERE C_Is_Active__c = true) '
                + 'FROM C_Form_Target__c WHERE C_Form__c = :formId AND C_Is_Active__c = true ';
            if (directionFilter == 'outbound') {
                baseQuery += 'AND (C_Direction__c = \'Outbound\' OR C_Direction__c = \'Bidirectional\' OR C_Direction__c = null) ';
            } else if (directionFilter == 'inbound') {
                baseQuery += 'AND (C_Direction__c = \'Inbound\' OR C_Direction__c = \'Bidirectional\') ';
            }
            baseQuery += 'ORDER BY C_Order__c';
            return Database.query(baseQuery);
        }

        private Map<Id, Id> resolveAllTargets(List<C_Form_Target__c> targets, Map<String, String> contextMap) {
            Map<Id, Id> resolvedMap = new Map<Id, Id>();
            Map<Id, C_Form_Target__c> targetById = new Map<Id, C_Form_Target__c>();
            for (C_Form_Target__c t : targets) targetById.put(t.Id, t);

            Set<String> userFieldPaths = new Set<String>();
            for (C_Form_Target__c target : targets) {
                String resType = target.C_Resolution_Type__c;
                if (resType == 'Running_User' || resType == 'Running_User_Account' || resType == 'Running_User_Contact') {
                    String fieldPath = target.C_User_Lookup_Field__c;
                    if (resType == 'Running_User_Account' && String.isBlank(fieldPath)) fieldPath = 'Contact.AccountId';
                    if (resType == 'Running_User_Contact' && String.isBlank(fieldPath)) fieldPath = 'ContactId';
                    if (String.isNotBlank(fieldPath) && isValidUserFieldPath(fieldPath)) {
                        userFieldPaths.add(fieldPath);
                    }
                }
            }

            SObject cachedUser = null;
            if (!userFieldPaths.isEmpty()) {
                Set<String> allFields = new Set<String>{'Id'};
                allFields.addAll(userFieldPaths);
                Id userId = UserInfo.getUserId();
                String soql = 'SELECT ' + String.join(new List<String>(allFields), ', ') + ' FROM User WHERE Id = :userId LIMIT 1';
                List<SObject> users = Database.query(soql);
                if (!users.isEmpty()) cachedUser = users[0];
            }

            for (C_Form_Target__c target : targets) {
                Id resolved = resolveRecord(target, contextMap, resolvedMap, targetById, cachedUser);
                if (resolved != null) resolvedMap.put(target.Id, resolved);
            }
            return resolvedMap;
        }

        private Id resolveRecord(C_Form_Target__c target, Map<String, String> contextMap,
                                  Map<Id, Id> resolvedMap, Map<Id, C_Form_Target__c> targetById, SObject cachedUser) {
            String resType = target.C_Resolution_Type__c;

            if (resType == 'Record_Context') {
                if (String.isNotBlank(target.C_Context_Key__c) && contextMap.containsKey(target.C_Context_Key__c))
                    return safeToId(contextMap.get(target.C_Context_Key__c));
                if (contextMap.containsKey('_default'))
                    return safeToId(contextMap.get('_default'));
                return null;
            }

            if (resType == 'Running_User' || resType == 'Running_User_Account' || resType == 'Running_User_Contact') {
                return resolveRunningUserCached(target, cachedUser);
            }

            if (resType == 'Related_Record') {
                return resolveRelatedRecord(target, resolvedMap, targetById);
            }

            return null;
        }

        private Id resolveRunningUserCached(C_Form_Target__c target, SObject cachedUser) {
            String fieldPath = target.C_User_Lookup_Field__c;

            if (target.C_Resolution_Type__c == 'Running_User_Account' && String.isBlank(fieldPath))
                fieldPath = 'Contact.AccountId';
            if (target.C_Resolution_Type__c == 'Running_User_Contact' && String.isBlank(fieldPath))
                fieldPath = 'ContactId';

            if (String.isBlank(fieldPath) || cachedUser == null) return null;
            if (!isValidUserFieldPath(fieldPath)) return null;

            return traverseFieldPath(cachedUser, fieldPath);
        }

        private Id resolveRelatedRecord(C_Form_Target__c target, Map<Id, Id> resolvedMap, Map<Id, C_Form_Target__c> targetById) {
            if (target.C_Related_Target__c == null || String.isBlank(target.C_Related_Field_Path__c)) return null;

            Id sourceRecordId = resolvedMap.get(target.C_Related_Target__c);
            if (sourceRecordId == null) return null;

            C_Form_Target__c sourceTarget = targetById.get(target.C_Related_Target__c);
            if (sourceTarget == null) return null;

            String sourceObject = sourceTarget.C_Target_Object__c;
            String fieldPath = target.C_Related_Field_Path__c;
            if (!isValidFieldPath(sourceObject, fieldPath)) return null;

            String soql = 'SELECT ' + String.escapeSingleQuotes(fieldPath)
                + ' FROM ' + String.escapeSingleQuotes(sourceObject)
                + ' WHERE Id = :sourceRecordId LIMIT 1';
            List<SObject> records = Database.query(soql);
            if (records.isEmpty()) return null;

            return traverseFieldPath(records[0], fieldPath);
        }

        private Id traverseFieldPath(SObject record, String fieldPath) {
            List<String> parts = fieldPath.split('\\.');
            SObject current = record;
            for (Integer i = 0; i < parts.size() - 1; i++) {
                current = current.getSObject(parts[i]);
                if (current == null) return null;
            }
            Object val = current.get(parts[parts.size() - 1]);
            return val != null ? (Id) String.valueOf(val) : null;
        }

        private Boolean isValidUserFieldPath(String fieldPath) {
            List<String> parts = fieldPath.split('\\.');
            Schema.SObjectType currentType = Schema.SObjectType.User.getSObjectType();
            return validateFieldPathOnType(currentType, parts);
        }

        private Boolean isValidFieldPath(String objectName, String fieldPath) {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) return false;
            List<String> parts = fieldPath.split('\\.');
            return validateFieldPathOnType(sot, parts);
        }

        private Boolean validateFieldPathOnType(Schema.SObjectType sot, List<String> parts) {
            Map<String, Schema.SObjectField> fieldMap = sot.getDescribe().fields.getMap();
            for (Integer i = 0; i < parts.size(); i++) {
                String part = parts[i];
                String fieldApiName = part.endsWith('__r') ? part.replace('__r', '__c') : part;
                if (i < parts.size() - 1 && !part.endsWith('__r') && !part.endsWith('Id')) {
                    fieldApiName = part + 'Id';
                }
                Schema.SObjectField field = fieldMap.get(fieldApiName.toLowerCase());
                if (field == null) {
                    field = fieldMap.get(part.toLowerCase());
                    if (field == null) return false;
                }
                Schema.DescribeFieldResult fd = field.getDescribe();
                if (i < parts.size() - 1) {
                    if (fd.getType() != Schema.DisplayType.REFERENCE) return false;
                    List<Schema.SObjectType> refs = fd.getReferenceTo();
                    if (refs.isEmpty()) return false;
                    fieldMap = refs[0].getDescribe().fields.getMap();
                }
            }
            return true;
        }

        private Id safeToId(String value) {
            if (String.isBlank(value)) return null;
            try { return (Id) value; } catch (Exception e) { return null; }
        }

        public void doProcessFieldMappings(Id formSubmissionId) {
            List<C_Form_Submission__c> submissions = [
                SELECT Id, C_Form__c, C_Account__c, C_Lead__c, C_Contact__c, C_Record_Id__c, C_Record_Context_JSON__c
                FROM C_Form_Submission__c WHERE Id = :formSubmissionId LIMIT 1
            ];
            if (submissions.isEmpty()) {
                throw new AuraHandledException('Form submission not found: ' + formSubmissionId);
            }
            C_Form_Submission__c submission = submissions[0];

            Map<String, String> contextMap = parseRecordContext(submission.C_Record_Context_JSON__c);
            if (contextMap.isEmpty() && String.isNotBlank(submission.C_Record_Id__c))
                contextMap.put('_default', submission.C_Record_Id__c);

            List<C_Question_Response__c> questionResponses = [
                SELECT Id, C_Question__c, C_Response_Text__c, C_Response_Details__c,
                       C_Table_Data__c, C_Question_Type__c
                FROM C_Question_Response__c
                WHERE C_Section_Response__c IN (
                    SELECT Id FROM C_Section_Response__c WHERE C_Form_Submission__c = :formSubmissionId
                )
            ];

            Map<Id, C_Question_Response__c> responseByQuestionId = new Map<Id, C_Question_Response__c>();
            for (C_Question_Response__c qr : questionResponses) {
                responseByQuestionId.put(qr.C_Question__c, qr);
            }

            List<C_Form_Target__c> targets = queryTargets(submission.C_Form__c, 'outbound');
            Map<Id, Id> resolvedMap = resolveAllTargets(targets, contextMap);

            List<SObject> toUpdate = new List<SObject>();
            List<SObject> toInsert = new List<SObject>();

            for (C_Form_Target__c target : targets) {
                SObject resolved = buildTargetRecord(target, responseByQuestionId, resolvedMap.get(target.Id));
                if (resolved == null) continue;

                String operation = target.C_Record_Operation__c != null ? target.C_Record_Operation__c : 'Update';
                if (operation == 'Update' && resolved.Id != null) {
                    toUpdate.add(resolved);
                } else if (operation == 'Create') {
                    toInsert.add(resolved);
                } else if (operation == 'Upsert') {
                    if (resolved.Id != null) { toUpdate.add(resolved); }
                    else { toInsert.add(resolved); }
                }
            }

            if (!toUpdate.isEmpty()) update toUpdate;
            if (!toInsert.isEmpty()) insert toInsert;
        }

        public Map<String, Object> doGetPrePopulationData(Id formId, String recordContextJson) {
            Map<String, Object> result = new Map<String, Object>();
            Map<String, String> contextMap = parseRecordContext(recordContextJson);

            List<C_Form_Target__c> targets = queryTargets(formId, 'inbound');
            if (targets.isEmpty()) return result;

            Map<Id, Id> resolvedMap = resolveAllTargets(targets, contextMap);

            Set<Id> allQuestionIds = new Set<Id>();
            for (C_Form_Target__c t : targets)
                for (C_Field_Mapping__c m : t.C_Field_Mappings__r)
                    if (m.C_Question__c != null) allQuestionIds.add(m.C_Question__c);

            Map<Id, List<C_Response__c>> responsesByQuestion = new Map<Id, List<C_Response__c>>();
            if (!allQuestionIds.isEmpty()) {
                for (C_Response__c r : [
                    SELECT Id, C_Response_Text__c, C_Question__c
                    FROM C_Response__c WHERE C_Question__c IN :allQuestionIds ORDER BY C_Order__c
                ]) {
                    if (!responsesByQuestion.containsKey(r.C_Question__c))
                        responsesByQuestion.put(r.C_Question__c, new List<C_Response__c>());
                    responsesByQuestion.get(r.C_Question__c).add(r);
                }
            }

            Map<String, Set<String>> fieldsByObject = new Map<String, Set<String>>();
            Map<String, Set<Id>> resolvedIdsByObject = new Map<String, Set<Id>>();
            for (C_Form_Target__c target : targets) {
                Id resolvedId = resolvedMap.get(target.Id);
                if (resolvedId == null) continue;
                String objName = target.C_Target_Object__c;

                Schema.SObjectType sot = Schema.getGlobalDescribe().get(objName);
                if (sot == null) continue;
                Map<String, Schema.SObjectField> fieldMap = sot.getDescribe().fields.getMap();

                if (!fieldsByObject.containsKey(objName)) {
                    fieldsByObject.put(objName, new Set<String>{'Id'});
                    resolvedIdsByObject.put(objName, new Set<Id>());
                }
                resolvedIdsByObject.get(objName).add(resolvedId);

                for (C_Field_Mapping__c m : target.C_Field_Mappings__r) {
                    if (String.isNotBlank(m.C_Target_Field__c) && m.C_Mapping_Type__c != 'Static_Value') {
                        if (fieldMap.containsKey(m.C_Target_Field__c.toLowerCase())) {
                            fieldsByObject.get(objName).add(m.C_Target_Field__c);
                        }
                    }
                }
            }

            Map<String, Map<Id, SObject>> recordsByObject = new Map<String, Map<Id, SObject>>();
            for (String objName : fieldsByObject.keySet()) {
                Set<Id> objIds = resolvedIdsByObject.get(objName);
                String soql = 'SELECT ' + String.join(new List<String>(fieldsByObject.get(objName)), ', ')
                    + ' FROM ' + String.escapeSingleQuotes(objName) + ' WHERE Id IN :objIds';
                Map<Id, SObject> recordMap = new Map<Id, SObject>();
                for (SObject rec : Database.query(soql)) {
                    recordMap.put(rec.Id, rec);
                }
                recordsByObject.put(objName, recordMap);
            }

            for (C_Form_Target__c target : targets) {
                Id resolvedId = resolvedMap.get(target.Id);
                if (resolvedId == null) continue;

                Map<Id, SObject> objectRecords = recordsByObject.get(target.C_Target_Object__c);
                if (objectRecords == null) continue;
                SObject sourceRecord = objectRecords.get(resolvedId);
                if (sourceRecord == null) continue;

                for (C_Field_Mapping__c mapping : target.C_Field_Mappings__r) {
                    if (mapping.C_Question__c == null || String.isBlank(mapping.C_Target_Field__c)) continue;
                    if (mapping.C_Mapping_Type__c == 'Static_Value') continue;

                    Object fieldValue = sourceRecord.get(mapping.C_Target_Field__c);
                    if (fieldValue == null) continue;

                    String questionType = mapping.C_Question__r != null ? mapping.C_Question__r.C_Type__c : null;
                    Map<String, String> prepopEntry = new Map<String, String>();

                    if (questionType == 'Picklist' || questionType == 'Multi-Select' || questionType == 'Checkbox') {
                        List<C_Response__c> responses = responsesByQuestion.get(mapping.C_Question__c);
                        if (responses != null) {
                            String strVal = String.valueOf(fieldValue);
                            List<String> vals = strVal.split(';');
                            List<String> matchedIds = new List<String>();
                            List<String> matchedTexts = new List<String>();
                            for (String v : vals) {
                                for (C_Response__c r : responses) {
                                    if (r.C_Response_Text__c != null && r.C_Response_Text__c.trim() == v.trim()) {
                                        matchedIds.add(r.Id);
                                        matchedTexts.add(r.C_Response_Text__c);
                                        break;
                                    }
                                }
                            }
                            if (!matchedIds.isEmpty()) {
                                prepopEntry.put('value', String.join(matchedIds, ';'));
                                prepopEntry.put('textValue', String.join(matchedTexts, '; '));
                            }
                        }
                    } else {
                        prepopEntry.put('value', null);
                        prepopEntry.put('textValue', String.valueOf(fieldValue));
                    }

                    if (!prepopEntry.isEmpty()) {
                        result.put(mapping.C_Question__c, prepopEntry);
                    }
                }
            }

            return result;
        }

        private SObject buildTargetRecord(C_Form_Target__c target, Map<Id, C_Question_Response__c> responseByQuestionId, Id resolvedId) {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(target.C_Target_Object__c);
            if (sObjectType == null) return null;

            SObject targetRecord;
            if (resolvedId != null) {
                targetRecord = sObjectType.newSObject(resolvedId);
            } else if (target.C_Resolution_Type__c == 'New') {
                targetRecord = sObjectType.newSObject();
            } else {
                return null;
            }

            Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
            Boolean hasFieldValues = false;

            for (C_Field_Mapping__c mapping : target.C_Field_Mappings__r) {
                String fieldName = mapping.C_Target_Field__c;
                if (String.isBlank(fieldName) || !fieldMap.containsKey(fieldName.toLowerCase())) continue;

                Schema.DescribeFieldResult fd = fieldMap.get(fieldName.toLowerCase()).getDescribe();
                Object typedValue = null;
                String mappingType = mapping.C_Mapping_Type__c != null ? mapping.C_Mapping_Type__c : 'Field_Value';

                if (mappingType == 'Static_Value') {
                    typedValue = convertValue(mapping.C_Static_Value__c, fd.getType());
                } else if (mappingType == 'Table_JSON') {
                    C_Question_Response__c qr = responseByQuestionId.get(mapping.C_Question__c);
                    if (qr != null && qr.C_Table_Data__c != null) typedValue = qr.C_Table_Data__c;
                } else {
                    C_Question_Response__c qr = responseByQuestionId.get(mapping.C_Question__c);
                    if (qr != null) {
                        String rv = qr.C_Response_Details__c != null ? qr.C_Response_Details__c : qr.C_Response_Text__c;
                        if (rv != null) typedValue = convertValue(rv, fd.getType());
                    }
                }

                if (typedValue != null) { targetRecord.put(fieldName, typedValue); hasFieldValues = true; }
            }

            return hasFieldValues ? targetRecord : null;
        }

        private Object convertValue(String value, Schema.DisplayType fieldType) {
            if (String.isBlank(value)) return null;
            try {
                switch on fieldType {
                    when STRING, TEXTAREA, PICKLIST, MULTIPICKLIST, URL, EMAIL, PHONE { return value; }
                    when INTEGER { return Integer.valueOf(value); }
                    when DOUBLE, CURRENCY, PERCENT { return Decimal.valueOf(value); }
                    when BOOLEAN { return Boolean.valueOf(value); }
                    when DATE { return Date.valueOf(value); }
                    when DATETIME { return Datetime.valueOf(value); }
                    when else { return value; }
                }
            } catch (Exception e) { return null; }
        }
    }
}

/**
 * @description       : Reusable test data factory for Form Builder test classes
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
public class TestDataFactory {

    private static Id cachedSectionFormRt;

    /**
     * @description Assigns Forms_Admin to the running user so admin-gated Form Builder code can run in tests
     */
    public static void assignFormsAdminToRunningUser() {
        PermissionSet adminPs = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Forms_Admin'
            LIMIT 1
        ];
        List<PermissionSetAssignment> existing = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSetId = :adminPs.Id
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return;
        }
        insert new PermissionSetAssignment(
            AssigneeId = UserInfo.getUserId(),
            PermissionSetId = adminPs.Id
        );
    }

    public static C_Form__c createForm() {
        C_Form__c form = new C_Form__c(
            Name = 'Test Form',
            C_Description__c = 'Test form description',
            C_Status__c = 'Draft',
            C_Version__c = 1,
            C_Default_Language__c = 'en'
        );
        insert form;
        return form;
    }

    public static C_Category__c createCategory(Id formId, Integer orderVal) {
        C_Category__c category = new C_Category__c(
            Name = 'Category ' + orderVal,
            C_Form__c = formId,
            C_Order__c = orderVal,
            C_Is_Active__c = true,
            C_Description__c = 'Category description ' + orderVal
        );
        insert category;
        return category;
    }

    public static C_Page__c createPage(Id formId, Integer orderVal) {
        return createPage(formId, null, orderVal);
    }

    public static C_Page__c createPage(Id formId, Id categoryId, Integer orderVal) {
        C_Page__c page = new C_Page__c(
            Name = 'Page ' + orderVal,
            C_Description__c = 'Page description ' + orderVal,
            C_Order__c = orderVal,
            C_Form__c = formId,
            C_Category__c = categoryId
        );
        insert page;
        return page;
    }

    public static C_Section__c createSection(Id pageId, Integer orderVal, Decimal weight) {
        if (cachedSectionFormRt == null) {
            Schema.RecordTypeInfo rtInfo =
                Schema.SObjectType.C_Section__c.getRecordTypeInfosByDeveloperName().get('Form');
            if (rtInfo == null) {
                throw new IllegalArgumentException('Missing RecordType: C_Section__c.Form');
            }
            cachedSectionFormRt = rtInfo.getRecordTypeId();
        }
        C_Section__c section = new C_Section__c(
            Name = 'Section ' + orderVal,
            C_Page__c = pageId,
            C_Order__c = orderVal,
            C_Weight__c = weight,
            C_Bonus__c = false,
            C_Excluded_From_Weight__c = false,
            RecordTypeId = cachedSectionFormRt
        );
        insert section;
        return section;
    }

    public static C_Question__c createQuestion(Id sectionId, Integer orderVal, String questionType) {
        C_Question__c question = new C_Question__c(
            Name = 'Q' + orderVal,
            C_Section__c = sectionId,
            C_Order__c = orderVal,
            C_Type__c = questionType,
            C_Question_Text__c = 'Question text ' + orderVal,
            C_Help_Text__c = 'Help text ' + orderVal,
            C_Is_Required__c = true,
            C_Weight__c = 1
        );
        insert question;
        return question;
    }

    public static C_Response__c createResponse(Id questionId, Integer orderVal, Decimal points) {
        C_Response__c response = new C_Response__c(
            Name = 'Response ' + orderVal,
            C_Question__c = questionId,
            C_Order__c = orderVal,
            C_Response_Text__c = 'Response text ' + orderVal,
            C_Points__c = points,
            C_Requires_Details__c = false,
            C_Locks_Question__c = false
        );
        insert response;
        return response;
    }

    public static C_Dependency__c createDependency(Id responseId, Id targetSectionId, String action) {
        C_Dependency__c dep = new C_Dependency__c(
            C_Controlling_Response__c = responseId,
            C_Target_Type__c = 'Section',
            C_Target_Section__c = targetSectionId,
            C_Action__c = action,
            C_Logic_Group__c = 'Group1',
            C_Logic_Operator__c = 'AND'
        );
        insert dep;
        return dep;
    }

    public static C_Form_Submission__c createSubmission(Id formId) {
        C_Form_Submission__c submission = new C_Form_Submission__c(
            C_Form__c = formId,
            C_Status__c = 'In Progress',
            C_Language__c = 'en',
            C_Is_Testing__c = true
        );
        insert submission;
        return submission;
    }

    public static C_Form_Target__c createFormTarget(Id formId, String objectName, String resolutionType) {
        C_Form_Target__c target = new C_Form_Target__c(
            C_Form__c = formId,
            C_Target_Object__c = objectName,
            C_Resolution_Type__c = resolutionType,
            C_Record_Operation__c = 'Update',
            C_Is_Active__c = true,
            C_Order__c = 1,
            C_Description__c = 'Target for ' + objectName
        );
        insert target;
        return target;
    }

    public static C_Field_Mapping__c createFieldMapping(Id formTargetId, Id questionId, String targetField) {
        C_Field_Mapping__c mapping = new C_Field_Mapping__c(
            Name = 'Mapping-' + targetField,
            C_Form_Target__c = formTargetId,
            C_Question__c = questionId,
            C_Target_Object__c = 'Account',
            C_Target_Field__c = targetField,
            C_Is_Active__c = true,
            C_Mapping_Type__c = 'Field_Value'
        );
        insert mapping;
        return mapping;
    }

    /**
     * Creates a complete form hierarchy:
     *   Form
     *   ├── Page 1
     *   │   ├── Section 1 (weight 50)
     *   │   │   ├── Question 1 (Text) → Response 1 (5pts), Response 2 (10pts)
     *   │   │   └── Question 2 (Picklist) → Response 3 (3pts), Response 4 (7pts)
     *   │   └── Section 2 (weight 50)
     *   │       ├── Question 3 (Number) → Response 5 (2pts), Response 6 (8pts)
     *   │       └── Question 4 (Checkbox) → Response 7 (4pts), Response 8 (6pts)
     *   └── Page 2
     *       ├── Section 3 (weight 40)
     *       │   ├── Question 5 (Date) → Response 9 (1pt), Response 10 (9pts)
     *       │   └── Question 6 (Long Text) → Response 11 (5pts), Response 12 (5pts)
     *       └── Section 4 (weight 60)
     *           ├── Question 7 (File) → Response 13 (3pts), Response 14 (7pts)
     *           └── Question 8 (Table) → Response 15 (6pts), Response 16 (4pts)
     * @return Id of the created form
     */
    public static Id createFullFormStructure() {
        C_Form__c form = new C_Form__c(
            Name = 'Full Test Form',
            C_Description__c = 'Complete form structure for testing',
            C_Status__c = 'Published',
            C_Version__c = 1,
            C_Default_Language__c = 'en'
        );
        insert form;

        List<C_Category__c> categories = new List<C_Category__c>();
        categories.add(new C_Category__c(Name = 'Category 1', C_Form__c = form.Id, C_Order__c = 1, C_Is_Active__c = true));
        categories.add(new C_Category__c(Name = 'Category 2', C_Form__c = form.Id, C_Order__c = 2, C_Is_Active__c = true));
        insert categories;

        List<C_Page__c> pages = new List<C_Page__c>();
        pages.add(new C_Page__c(Name = 'Page 1', C_Description__c = 'First page', C_Order__c = 1, C_Form__c = form.Id, C_Category__c = categories[0].Id));
        pages.add(new C_Page__c(Name = 'Page 2', C_Description__c = 'Second page', C_Order__c = 2, C_Form__c = form.Id, C_Category__c = categories[1].Id));
        insert pages;

        String[] sectionTypes = new String[]{ 'Text', 'Picklist', 'Number', 'Checkbox', 'Date', 'Long Text', 'File', 'Table' };
        Decimal[] sectionWeights = new Decimal[]{ 50, 50, 40, 60 };

        List<C_Section__c> sections = new List<C_Section__c>();
        Integer sIdx = 1;
        for (Integer p = 0; p < 2; p++) {
            for (Integer s = 0; s < 2; s++) {
                sections.add(new C_Section__c(
                    Name = 'Section ' + sIdx,
                    C_Page__c = pages[p].Id,
                    C_Order__c = s + 1,
                    C_Weight__c = sectionWeights[sIdx - 1],
                    C_Bonus__c = false,
                    C_Excluded_From_Weight__c = false
                ));
                sIdx++;
            }
        }
        insert sections;

        List<C_Question__c> questions = new List<C_Question__c>();
        Integer qIdx = 1;
        for (Integer s = 0; s < 4; s++) {
            for (Integer q = 0; q < 2; q++) {
                C_Question__c question = new C_Question__c(
                    Name = 'Q' + qIdx,
                    C_Section__c = sections[s].Id,
                    C_Order__c = q + 1,
                    C_Type__c = sectionTypes[qIdx - 1],
                    C_Question_Text__c = 'Question text ' + qIdx,
                    C_Help_Text__c = 'Help ' + qIdx,
                    C_Is_Required__c = true,
                    C_Weight__c = 1
                );
                if (sectionTypes[qIdx - 1] == 'Table') {
                    question.C_Table_Columns__c = '[{"label":"Col1","type":"text"}]';
                    question.C_Table_Min_Rows__c = 1;
                    question.C_Table_Max_Rows__c = 5;
                }
                if (sectionTypes[qIdx - 1] == 'File') {
                    question.C_Accepted_File_Types__c = '.pdf,.docx';
                    question.C_Max_Files__c = 3;
                    question.C_Max_File_Size_MB__c = 10;
                }
                questions.add(question);
                qIdx++;
            }
        }
        insert questions;

        List<C_Response__c> responses = new List<C_Response__c>();
        Decimal[][] pointSets = new Decimal[][]{
            new Decimal[]{5, 10}, new Decimal[]{3, 7}, new Decimal[]{2, 8}, new Decimal[]{4, 6},
            new Decimal[]{1, 9}, new Decimal[]{5, 5}, new Decimal[]{3, 7}, new Decimal[]{6, 4}
        };
        for (Integer qi = 0; qi < 8; qi++) {
            for (Integer ri = 0; ri < 2; ri++) {
                responses.add(new C_Response__c(
                    Name = 'R' + ((qi * 2) + ri + 1),
                    C_Question__c = questions[qi].Id,
                    C_Order__c = ri + 1,
                    C_Response_Text__c = 'Response ' + ((qi * 2) + ri + 1),
                    C_Points__c = pointSets[qi][ri],
                    C_Requires_Details__c = false,
                    C_Locks_Question__c = false
                ));
            }
        }
        insert responses;

        return form.Id;
    }
}
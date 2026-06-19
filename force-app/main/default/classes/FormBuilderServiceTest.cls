/**
 * @description       : Test class for FormBuilderService - full CRUD, reorder, and move operations
 * @author            : Daniel Murracas
 * @last modified on  : 19-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   19-03-2026   Daniel Murracas     Initial Version
 * 1.1   01-04-2026   Tom De Backer       Cross-field rule cleanup on question delete tests
 * ------------------------------------------------------------
 **/
@IsTest
private class FormBuilderServiceTest {
  @TestSetup
  static void setupData() {
    TestDataFactory.createFullFormStructure();
  }

  // ─── Form CRUD ──────────────────────────────────────────────

  @IsTest
  static void testGetForms() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    Test.startTest();
    List<C_Form__c> forms = FormBuilderService.getForms();
    Test.stopTest();

    System.assert(forms.size() >= 1, 'Should return at least one form');
    System.assertNotEquals(
      null,
      forms[0].Name,
      'Form name should be populated'
    );
  }

  @IsTest
  static void testSaveForm_Insert() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c newForm = new C_Form__c(
      Name = 'New Form',
      C_Description__c = 'Brand new form',
      C_Status__c = 'Draft',
      C_Version__c = 1,
      C_Default_Language__c = 'fr',
      C_Layout_Mode__c = 'classic'
    );

    Test.startTest();
    C_Form__c result = FormBuilderService.saveForm(newForm);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Saved form should have an Id');
    System.assertEquals('New Form', result.Name, 'Form name should match');
  }

  @IsTest
  static void testSaveForm_Update() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id, Name FROM C_Form__c LIMIT 1];
    form.Name = 'Updated Form Name';

    Test.startTest();
    C_Form__c result = FormBuilderService.saveForm(form);
    Test.stopTest();

    C_Form__c reloaded = [SELECT Name FROM C_Form__c WHERE Id = :form.Id];
    System.assertEquals(
      'Updated Form Name',
      reloaded.Name,
      'Form name should be updated'
    );
  }

  @IsTest
  static void testSaveForm_RejectsNonAdmin() {
    User restrictedUser = createRestrictedTestUser();
    C_Form__c newForm = new C_Form__c(
      Name = 'Should Not Save',
      C_Status__c = 'Draft',
      C_Version__c = 1,
      C_Default_Language__c = 'en',
      C_Layout_Mode__c = 'classic'
    );

    FeatureUtil.testIsFormBuilderAdminOverride = false;
    Test.startTest();
    Boolean caughtException = false;
    try {
      System.runAs(restrictedUser) {
        FormBuilderService.saveForm(newForm);
      }
    } catch (AuraHandledException e) {
      caughtException = true;
      Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
    } finally {
      FeatureUtil.testIsFormBuilderAdminOverride = null;
    }
    Test.stopTest();

    Assert.isTrue(
      caughtException,
      'Expected AuraHandledException when non-admin calls saveForm'
    );
    Assert.isNull(
      newForm.Id,
      'Form should not have been inserted by a non-admin'
    );
  }

  @IsTest
  static void testDeleteForm() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    TestDataFactory.createPage(form.Id, 1);
    Id formId = form.Id;

    Test.startTest();
    FormBuilderService.deleteForm(formId);
    Test.stopTest();

    List<C_Form__c> remaining = [SELECT Id FROM C_Form__c WHERE Id = :formId];
    System.assertEquals(0, remaining.size(), 'Form should be deleted');
    List<C_Page__c> orphanPages = [
      SELECT Id
      FROM C_Page__c
      WHERE C_Form__c = :formId
    ];
    System.assertEquals(0, orphanPages.size(), 'Child pages should be deleted');
  }

  // ─── Category CRUD ──────────────────────────────────────────

  @IsTest
  static void testGetCategories() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

    Test.startTest();
    List<C_Category__c> categories = FormBuilderService.getCategories(form.Id);
    Test.stopTest();

    System.assertEquals(2, categories.size(), 'Should return 2 categories');
    System.assert(
      categories[0].C_Order__c <= categories[1].C_Order__c,
      'Categories should be ordered'
    );
  }

  @IsTest
  static void testSaveCategory_Insert() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    C_Category__c newCat = new C_Category__c(
      Name = 'Category 3',
      C_Form__c = form.Id,
      C_Order__c = 3,
      C_Is_Active__c = true
    );

    Test.startTest();
    C_Category__c result = FormBuilderService.saveCategory(newCat);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Saved category should have an Id');
    System.assertEquals(
      'Category 3',
      result.Name,
      'Category name should match'
    );
  }

  @IsTest
  static void testSaveCategory_Update() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Category__c cat = [SELECT Id, Name FROM C_Category__c LIMIT 1];
    cat.Name = 'Updated Category';

    Test.startTest();
    FormBuilderService.saveCategory(cat);
    Test.stopTest();

    C_Category__c reloaded = [
      SELECT Name
      FROM C_Category__c
      WHERE Id = :cat.Id
    ];
    System.assertEquals(
      'Updated Category',
      reloaded.Name,
      'Category name should be updated'
    );
  }

  @IsTest
  static void testDeleteCategory() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Category__c cat = TestDataFactory.createCategory(form.Id, 1);
    C_Page__c page = TestDataFactory.createPage(form.Id, cat.Id, 1);
    Id catId = cat.Id;

    Test.startTest();
    FormBuilderService.deleteCategory(catId);
    Test.stopTest();

    List<C_Category__c> remaining = [
      SELECT Id
      FROM C_Category__c
      WHERE Id = :catId
    ];
    System.assertEquals(0, remaining.size(), 'Category should be deleted');
    List<C_Page__c> orphanPages = [
      SELECT Id
      FROM C_Page__c
      WHERE C_Category__c = :catId
    ];
    System.assertEquals(0, orphanPages.size(), 'Child pages should be deleted');
  }

  @IsTest
  static void testGetFullFormStructureWithCategories() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

    Test.startTest();
    Map<String, Object> structure = FormBuilderService.getFullFormStructure(
      form.Id
    );
    Test.stopTest();

    System.assert(
      structure.containsKey('categories'),
      'Result should have categories key'
    );
    System.assert(
      structure.containsKey('pagesByCategory'),
      'Result should have pagesByCategory key'
    );
    System.assert(
      structure.containsKey('pages'),
      'Result should still have pages key for compat'
    );
    List<C_Category__c> categories = (List<C_Category__c>) structure.get(
      'categories'
    );
    System.assertEquals(2, categories.size(), 'Should have 2 categories');
  }

  @IsTest
  static void testGetFullFormStructureUncategorizedPages() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    TestDataFactory.createPage(form.Id, 1);

    Test.startTest();
    Map<String, Object> structure = FormBuilderService.getFullFormStructure(
      form.Id
    );
    Test.stopTest();

    System.assert(
      structure.containsKey('uncategorizedPages'),
      'Result should include uncategorizedPages'
    );
    List<C_Page__c> unc = (List<C_Page__c>) structure.get('uncategorizedPages');
    System.assertEquals(1, unc.size(), 'One page without category');
    System.assertEquals(
      null,
      unc[0].C_Category__c,
      'Uncategorized page has null C_Category__c'
    );
  }

  @IsTest
  static void testReorderCategories() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    List<C_Category__c> categories = [
      SELECT Id, C_Order__c
      FROM C_Category__c
      WHERE C_Form__c = :form.Id
      ORDER BY C_Order__c
    ];

    List<Map<String, Object>> reordered = new List<Map<String, Object>>{
      new Map<String, Object>{ 'id' => categories[0].Id, 'order' => 2 },
      new Map<String, Object>{ 'id' => categories[1].Id, 'order' => 1 }
    };

    Test.startTest();
    FormBuilderService.reorderItems('Category', reordered);
    Test.stopTest();

    C_Category__c cat1 = [
      SELECT C_Order__c
      FROM C_Category__c
      WHERE Id = :categories[0].Id
    ];
    C_Category__c cat2 = [
      SELECT C_Order__c
      FROM C_Category__c
      WHERE Id = :categories[1].Id
    ];
    System.assertEquals(2, cat1.C_Order__c, 'Category 1 should now be order 2');
    System.assertEquals(1, cat2.C_Order__c, 'Category 2 should now be order 1');
  }

  @IsTest
  static void testMovePageBetweenCategories() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    List<C_Category__c> categories = [
      SELECT Id
      FROM C_Category__c
      WHERE C_Form__c = :form.Id
      ORDER BY C_Order__c
    ];
    C_Page__c page = [
      SELECT Id, C_Category__c
      FROM C_Page__c
      WHERE C_Category__c = :categories[0].Id
      ORDER BY C_Order__c
      LIMIT 1
    ];

    Test.startTest();
    FormBuilderService.moveItem('Page', page.Id, categories[1].Id, 1);
    Test.stopTest();

    C_Page__c moved = [SELECT C_Category__c FROM C_Page__c WHERE Id = :page.Id];
    System.assertEquals(
      categories[1].Id,
      moved.C_Category__c,
      'Page should be moved to category 2'
    );
  }

  // ─── Page CRUD ──────────────────────────────────────────────

  @IsTest
  static void testGetPages() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

    Test.startTest();
    List<C_Page__c> pages = FormBuilderService.getPages(form.Id);
    Test.stopTest();

    System.assertEquals(2, pages.size(), 'Should return 2 pages');
    System.assert(
      pages[0].C_Order__c <= pages[1].C_Order__c,
      'Pages should be ordered'
    );
  }

  @IsTest
  static void testSavePage_Insert() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    C_Page__c newPage = new C_Page__c(
      Name = 'Page 3',
      C_Description__c = 'Third page',
      C_Order__c = 3,
      C_Form__c = form.Id
    );

    Test.startTest();
    C_Page__c result = FormBuilderService.savePage(newPage);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Saved page should have an Id');
  }

  @IsTest
  static void testSavePage_Update() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Page__c page = [SELECT Id, Name FROM C_Page__c LIMIT 1];
    page.Name = 'Updated Page';

    Test.startTest();
    FormBuilderService.savePage(page);
    Test.stopTest();

    C_Page__c reloaded = [SELECT Name FROM C_Page__c WHERE Id = :page.Id];
    System.assertEquals(
      'Updated Page',
      reloaded.Name,
      'Page name should be updated'
    );
  }

  @IsTest
  static void testDeletePage() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Page__c page = TestDataFactory.createPage(form.Id, 1);
    Id pageId = page.Id;

    Test.startTest();
    FormBuilderService.deletePage(pageId);
    Test.stopTest();

    List<C_Page__c> remaining = [SELECT Id FROM C_Page__c WHERE Id = :pageId];
    System.assertEquals(0, remaining.size(), 'Page should be deleted');
  }

  // ─── Section CRUD ───────────────────────────────────────────

  @IsTest
  static void testGetSections() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Page__c page = [SELECT Id FROM C_Page__c WHERE C_Order__c = 1 LIMIT 1];

    Test.startTest();
    List<C_Section__c> sections = FormBuilderService.getSections(page.Id);
    Test.stopTest();

    System.assertEquals(2, sections.size(), 'Page 1 should have 2 sections');
  }

  @IsTest
  static void testSaveSection_Insert() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Page__c page = [SELECT Id FROM C_Page__c LIMIT 1];
    C_Section__c newSection = new C_Section__c(
      Name = 'New Section',
      C_Page__c = page.Id,
      C_Order__c = 10,
      C_Weight__c = 25,
      C_Bonus__c = true,
      C_Excluded_From_Weight__c = false
    );

    Test.startTest();
    C_Section__c result = FormBuilderService.saveSection(newSection);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Saved section should have an Id');
    System.assertEquals(true, result.C_Bonus__c, 'Bonus flag should persist');
  }

  @IsTest
  static void testDeleteSection() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Page__c page = TestDataFactory.createPage(form.Id, 1);
    C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
    Id sectionId = section.Id;

    Test.startTest();
    FormBuilderService.deleteSection(sectionId);
    Test.stopTest();

    List<C_Section__c> remaining = [
      SELECT Id
      FROM C_Section__c
      WHERE Id = :sectionId
    ];
    System.assertEquals(0, remaining.size(), 'Section should be deleted');
  }

  // ─── Question CRUD ──────────────────────────────────────────

  @IsTest
  static void testGetQuestions() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];

    Test.startTest();
    List<C_Question__c> questions = FormBuilderService.getQuestions(section.Id);
    Test.stopTest();

    System.assertEquals(
      2,
      questions.size(),
      'Each section should have 2 questions'
    );
  }

  @IsTest
  static void testSaveQuestion_Insert() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
    C_Question__c q = new C_Question__c(
      Name = 'New Q',
      C_Section__c = section.Id,
      C_Order__c = 99,
      C_Type__c = 'Text',
      C_Question_Text__c = 'New question?',
      C_Is_Required__c = false,
      C_Weight__c = 2,
      C_Placeholder__c = 'Enter here',
      C_Max_Length__c = 500
    );

    Test.startTest();
    C_Question__c result = FormBuilderService.saveQuestion(q);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Question should be saved');
    System.assertEquals('Text', result.C_Type__c, 'Type should persist');
  }

  @IsTest
  static void testDeleteQuestion() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Page__c page = TestDataFactory.createPage(form.Id, 1);
    C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
    C_Question__c q = TestDataFactory.createQuestion(section.Id, 1, 'Text');
    Id qId = q.Id;

    Test.startTest();
    FormBuilderService.deleteQuestion(qId);
    Test.stopTest();

    List<C_Question__c> remaining = [
      SELECT Id
      FROM C_Question__c
      WHERE Id = :qId
    ];
    System.assertEquals(0, remaining.size(), 'Question should be deleted');
  }

  /**
   * When the last question in a category is deleted, category-target dependencies controlled
   * from another category must still be removed (they are not covered by the per-question dependency delete).
   */
  @IsTest
  static void testDeleteQuestion_PruneStaleCategoryTargetDependency() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Category__c catTarget = TestDataFactory.createCategory(form.Id, 1);
    C_Category__c catOther = TestDataFactory.createCategory(form.Id, 2);
    C_Page__c pageTarget = TestDataFactory.createPage(form.Id, catTarget.Id, 1);
    C_Page__c pageOther = TestDataFactory.createPage(form.Id, catOther.Id, 1);
    C_Section__c secTarget = TestDataFactory.createSection(
      pageTarget.Id,
      1,
      100
    );
    C_Section__c secOther = TestDataFactory.createSection(pageOther.Id, 1, 100);
    C_Question__c qLastInTargetCat = TestDataFactory.createQuestion(
      secTarget.Id,
      1,
      'Text'
    );
    C_Question__c qController = TestDataFactory.createQuestion(
      secOther.Id,
      1,
      'Text'
    );
    C_Response__c rController = TestDataFactory.createResponse(
      qController.Id,
      1,
      1
    );

    C_Dependency__c dep = new C_Dependency__c(
      C_Controlling_Response__c = rController.Id,
      C_Target_Type__c = 'Category',
      C_Target_Category__c = catTarget.Id,
      C_Action__c = 'Show',
      C_Logic_Group__c = 'G1',
      C_Logic_Operator__c = 'AND'
    );
    insert dep;

    Test.startTest();
    FormBuilderService.deleteQuestion(qLastInTargetCat.Id);
    Test.stopTest();

    Integer remaining = [
      SELECT COUNT()
      FROM C_Dependency__c
      WHERE Id = :dep.Id
    ];
    System.assertEquals(
      0,
      remaining,
      'Stale category-target dependency should be pruned'
    );
  }

  @IsTest
  static void testDeleteQuestion_KeepsCategoryDependencyWhenSiblingQuestionRemains() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Category__c catA = TestDataFactory.createCategory(form.Id, 1);
    C_Category__c catB = TestDataFactory.createCategory(form.Id, 2);
    C_Page__c pageA1 = TestDataFactory.createPage(form.Id, catA.Id, 1);
    C_Page__c pageA2 = TestDataFactory.createPage(form.Id, catA.Id, 2);
    C_Page__c pageB = TestDataFactory.createPage(form.Id, catB.Id, 1);
    C_Section__c secDel = TestDataFactory.createSection(pageA1.Id, 1, 100);
    C_Section__c secKeep = TestDataFactory.createSection(pageA2.Id, 1, 100);
    C_Section__c secB = TestDataFactory.createSection(pageB.Id, 1, 100);
    C_Question__c qDel = TestDataFactory.createQuestion(secDel.Id, 1, 'Text');
    TestDataFactory.createQuestion(secKeep.Id, 1, 'Text');
    C_Question__c qController = TestDataFactory.createQuestion(
      secB.Id,
      1,
      'Text'
    );
    C_Response__c rController = TestDataFactory.createResponse(
      qController.Id,
      1,
      1
    );

    C_Dependency__c dep = new C_Dependency__c(
      C_Controlling_Response__c = rController.Id,
      C_Target_Type__c = 'Category',
      C_Target_Category__c = catA.Id,
      C_Action__c = 'Show',
      C_Logic_Group__c = 'G1',
      C_Logic_Operator__c = 'AND'
    );
    insert dep;

    Test.startTest();
    FormBuilderService.deleteQuestion(qDel.Id);
    Test.stopTest();

    Integer remaining = [
      SELECT COUNT()
      FROM C_Dependency__c
      WHERE Id = :dep.Id
    ];
    System.assertEquals(
      1,
      remaining,
      'Category still has a question; dependency should remain'
    );
  }

  @IsTest
  static void testDeleteQuestion_ClearsCrossFieldRuleReferencingDeletedQuestion() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Page__c page = TestDataFactory.createPage(form.Id, 1);
    C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
    C_Question__c qDependent = TestDataFactory.createQuestion(
      section.Id,
      1,
      'Date'
    );
    C_Question__c qRef = TestDataFactory.createQuestion(section.Id, 2, 'Date');
    String rulesJson =
      '[{"id":"r1","type":"dateAfter","refQuestionId":"' +
      qRef.Id +
      '","message":"End must be after start"}]';
    qDependent.C_Cross_Field_Rules_JSON__c = rulesJson;
    update qDependent;

    Test.startTest();
    FormBuilderService.deleteQuestion(qRef.Id);
    Test.stopTest();

    C_Question__c reloaded = [
      SELECT C_Cross_Field_Rules_JSON__c
      FROM C_Question__c
      WHERE Id = :qDependent.Id
    ];
    System.assertEquals(
      null,
      reloaded.C_Cross_Field_Rules_JSON__c,
      'Rule pointing at deleted question should be cleared'
    );
  }

  @IsTest
  static void testDeleteQuestion_KeepsCrossFieldRulesForOtherReferences() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Page__c page = TestDataFactory.createPage(form.Id, 1);
    C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
    C_Question__c qDependent = TestDataFactory.createQuestion(
      section.Id,
      1,
      'Number'
    );
    C_Question__c qRemove = TestDataFactory.createQuestion(
      section.Id,
      2,
      'Number'
    );
    C_Question__c qKeep = TestDataFactory.createQuestion(
      section.Id,
      3,
      'Number'
    );
    String rulesJson =
      '[{"id":"a","type":"greaterThan","refQuestionId":"' +
      qRemove.Id +
      '","message":"m1"},{"id":"b","type":"lessThan","refQuestionId":"' +
      qKeep.Id +
      '","message":"m2"}]';
    qDependent.C_Cross_Field_Rules_JSON__c = rulesJson;
    update qDependent;

    Test.startTest();
    FormBuilderService.deleteQuestion(qRemove.Id);
    Test.stopTest();

    C_Question__c reloaded = [
      SELECT C_Cross_Field_Rules_JSON__c
      FROM C_Question__c
      WHERE Id = :qDependent.Id
    ];
    System.assertNotEquals(
      null,
      reloaded.C_Cross_Field_Rules_JSON__c,
      'Remaining rule should persist'
    );
    List<Object> parsed = (List<Object>) JSON.deserializeUntyped(
      reloaded.C_Cross_Field_Rules_JSON__c
    );
    System.assertEquals(
      1,
      parsed.size(),
      'Only the rule referencing the deleted question should be removed'
    );
    Map<String, Object> rule = (Map<String, Object>) parsed[0];
    System.assertEquals(
      String.valueOf(qKeep.Id),
      String.valueOf(rule.get('refQuestionId')),
      'Kept rule should still reference the surviving question'
    );
  }

  // ─── Response CRUD ──────────────────────────────────────────

  @IsTest
  static void testGetResponses() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];

    Test.startTest();
    List<C_Response__c> responses = FormBuilderService.getResponses(
      question.Id
    );
    Test.stopTest();

    System.assertEquals(
      2,
      responses.size(),
      'Each question should have 2 responses'
    );
  }

  @IsTest
  static void testSaveResponse_Insert() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
    C_Response__c r = new C_Response__c(
      Name = 'New Resp',
      C_Question__c = question.Id,
      C_Order__c = 99,
      C_Response_Text__c = 'New option',
      C_Points__c = 15,
      C_Requires_Details__c = true,
      C_Locks_Question__c = false
    );

    Test.startTest();
    C_Response__c result = FormBuilderService.saveResponse(r);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Response should be saved');
    System.assertEquals(15, result.C_Points__c, 'Points should persist');
  }

  @IsTest
  static void testDeleteResponse() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = TestDataFactory.createForm();
    C_Page__c page = TestDataFactory.createPage(form.Id, 1);
    C_Section__c section = TestDataFactory.createSection(page.Id, 1, 100);
    C_Question__c q = TestDataFactory.createQuestion(section.Id, 1, 'Picklist');
    C_Response__c r = TestDataFactory.createResponse(q.Id, 1, 5);
    Id rId = r.Id;

    Test.startTest();
    FormBuilderService.deleteResponse(rId);
    Test.stopTest();

    List<C_Response__c> remaining = [
      SELECT Id
      FROM C_Response__c
      WHERE Id = :rId
    ];
    System.assertEquals(0, remaining.size(), 'Response should be deleted');
  }

  // ─── Dependency CRUD ────────────────────────────────────────

  @IsTest
  static void testGetDependencies() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];
    C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
    TestDataFactory.createDependency(response.Id, section.Id, 'Show');

    Test.startTest();
    List<C_Dependency__c> deps = FormBuilderService.getDependencies(form.Id);
    Test.stopTest();

    System.assert(deps.size() >= 1, 'Should return at least one dependency');
  }

  @IsTest
  static void testSaveDependency_Insert() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];
    C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
    C_Dependency__c dep = new C_Dependency__c(
      C_Controlling_Response__c = response.Id,
      C_Target_Type__c = 'Section',
      C_Target_Section__c = section.Id,
      C_Action__c = 'Hide',
      C_Logic_Group__c = 'G1',
      C_Logic_Operator__c = 'OR'
    );

    Test.startTest();
    C_Dependency__c result = FormBuilderService.saveDependency(dep);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Dependency should be saved');
    System.assertEquals('Hide', result.C_Action__c, 'Action should persist');
  }

  @IsTest
  static void testDeleteDependency() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];
    C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
    C_Dependency__c dep = TestDataFactory.createDependency(
      response.Id,
      section.Id,
      'Require'
    );
    Id depId = dep.Id;

    Test.startTest();
    FormBuilderService.deleteDependency(depId);
    Test.stopTest();

    List<C_Dependency__c> remaining = [
      SELECT Id
      FROM C_Dependency__c
      WHERE Id = :depId
    ];
    System.assertEquals(0, remaining.size(), 'Dependency should be deleted');
  }

  // ─── Full Form Structure ────────────────────────────────────

  @IsTest
  static void testGetFullFormStructure() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

    Test.startTest();
    Map<String, Object> result = FormBuilderService.getFullFormStructure(
      form.Id
    );
    Test.stopTest();

    System.assert(result.containsKey('form'), 'Result should contain form');
    System.assert(result.containsKey('pages'), 'Result should contain pages');
    System.assert(
      result.containsKey('sectionsByPage'),
      'Result should contain sectionsByPage'
    );
    System.assert(
      result.containsKey('questionsBySection'),
      'Result should contain questionsBySection'
    );
    System.assert(
      result.containsKey('responsesByQuestion'),
      'Result should contain responsesByQuestion'
    );
    System.assert(
      result.containsKey('dependencies'),
      'Result should contain dependencies'
    );

    List<C_Page__c> pages = (List<C_Page__c>) result.get('pages');
    System.assertEquals(2, pages.size(), 'Should have 2 pages');

    Map<Id, List<C_Section__c>> sectionsByPage = (Map<Id, List<C_Section__c>>) result.get(
      'sectionsByPage'
    );
    System.assertEquals(
      2,
      sectionsByPage.size(),
      'Should have sections for 2 pages'
    );

    Map<Id, List<C_Question__c>> questionsBySection = (Map<Id, List<C_Question__c>>) result.get(
      'questionsBySection'
    );
    System.assertEquals(
      4,
      questionsBySection.size(),
      'Should have questions for 4 sections'
    );

    Map<Id, List<C_Response__c>> responsesByQuestion = (Map<Id, List<C_Response__c>>) result.get(
      'responsesByQuestion'
    );
    System.assertEquals(
      8,
      responsesByQuestion.size(),
      'Should have responses for 8 questions'
    );
  }

  // ─── Reorder Items ──────────────────────────────────────────

  @IsTest
  static void testReorderItems_Pages() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    List<C_Page__c> pages = [
      SELECT Id, C_Order__c
      FROM C_Page__c
      ORDER BY C_Order__c
    ];
    List<Map<String, Object>> items = new List<Map<String, Object>>();
    items.add(new Map<String, Object>{ 'id' => pages[0].Id, 'order' => 2 });
    items.add(new Map<String, Object>{ 'id' => pages[1].Id, 'order' => 1 });

    Test.startTest();
    FormBuilderService.reorderItems('Page', items);
    Test.stopTest();

    C_Page__c reloaded0 = [
      SELECT C_Order__c
      FROM C_Page__c
      WHERE Id = :pages[0].Id
    ];
    C_Page__c reloaded1 = [
      SELECT C_Order__c
      FROM C_Page__c
      WHERE Id = :pages[1].Id
    ];
    System.assertEquals(
      2,
      reloaded0.C_Order__c,
      'First page should now be order 2'
    );
    System.assertEquals(
      1,
      reloaded1.C_Order__c,
      'Second page should now be order 1'
    );
  }

  @IsTest
  static void testReorderItems_Sections() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Page__c page = [SELECT Id FROM C_Page__c WHERE C_Order__c = 1 LIMIT 1];
    List<C_Section__c> sections = [
      SELECT Id, C_Order__c
      FROM C_Section__c
      WHERE C_Page__c = :page.Id
      ORDER BY C_Order__c
    ];
    List<Map<String, Object>> items = new List<Map<String, Object>>();
    items.add(new Map<String, Object>{ 'id' => sections[0].Id, 'order' => 2 });
    items.add(new Map<String, Object>{ 'id' => sections[1].Id, 'order' => 1 });

    Test.startTest();
    FormBuilderService.reorderItems('Section', items);
    Test.stopTest();

    C_Section__c reloaded0 = [
      SELECT C_Order__c
      FROM C_Section__c
      WHERE Id = :sections[0].Id
    ];
    System.assertEquals(
      2,
      reloaded0.C_Order__c,
      'Section order should be swapped'
    );
  }

  @IsTest
  static void testReorderItems_Questions() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
    List<C_Question__c> questions = [
      SELECT Id, C_Order__c
      FROM C_Question__c
      WHERE C_Section__c = :section.Id
      ORDER BY C_Order__c
    ];
    List<Map<String, Object>> items = new List<Map<String, Object>>();
    items.add(new Map<String, Object>{ 'id' => questions[0].Id, 'order' => 2 });
    items.add(new Map<String, Object>{ 'id' => questions[1].Id, 'order' => 1 });

    Test.startTest();
    FormBuilderService.reorderItems('Question', items);
    Test.stopTest();

    C_Question__c reloaded = [
      SELECT C_Order__c
      FROM C_Question__c
      WHERE Id = :questions[0].Id
    ];
    System.assertEquals(
      2,
      reloaded.C_Order__c,
      'Question order should be swapped'
    );
  }

  @IsTest
  static void testReorderItems_Responses() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
    List<C_Response__c> responses = [
      SELECT Id, C_Order__c
      FROM C_Response__c
      WHERE C_Question__c = :question.Id
      ORDER BY C_Order__c
    ];
    List<Map<String, Object>> items = new List<Map<String, Object>>();
    items.add(new Map<String, Object>{ 'id' => responses[0].Id, 'order' => 2 });
    items.add(new Map<String, Object>{ 'id' => responses[1].Id, 'order' => 1 });

    Test.startTest();
    FormBuilderService.reorderItems('Response', items);
    Test.stopTest();

    C_Response__c reloaded = [
      SELECT C_Order__c
      FROM C_Response__c
      WHERE Id = :responses[0].Id
    ];
    System.assertEquals(
      2,
      reloaded.C_Order__c,
      'Response order should be swapped'
    );
  }

  // ─── Move Item - Section ────────────────────────────────────

  @IsTest
  static void testMoveItem_Section_SameParent() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Page__c page = [SELECT Id FROM C_Page__c WHERE C_Order__c = 1 LIMIT 1];
    List<C_Section__c> sections = [
      SELECT Id, C_Order__c
      FROM C_Section__c
      WHERE C_Page__c = :page.Id
      ORDER BY C_Order__c
    ];
    Id sectionId = sections[0].Id;

    Test.startTest();
    FormBuilderService.moveItem('Section', sectionId, page.Id, 2);
    Test.stopTest();

    C_Section__c moved = [
      SELECT C_Page__c, C_Order__c
      FROM C_Section__c
      WHERE Id = :sectionId
    ];
    System.assertEquals(page.Id, moved.C_Page__c, 'Should remain on same page');
    System.assertEquals(2, moved.C_Order__c, 'Order should be updated to 2');
  }

  @IsTest
  static void testMoveItem_Section_CrossParent() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    List<C_Page__c> pages = [SELECT Id FROM C_Page__c ORDER BY C_Order__c];
    C_Section__c section = [
      SELECT Id
      FROM C_Section__c
      WHERE C_Page__c = :pages[0].Id
      ORDER BY C_Order__c
      LIMIT 1
    ];

    Test.startTest();
    FormBuilderService.moveItem('Section', section.Id, pages[1].Id, 1);
    Test.stopTest();

    C_Section__c moved = [
      SELECT C_Page__c, C_Order__c
      FROM C_Section__c
      WHERE Id = :section.Id
    ];
    System.assertEquals(
      pages[1].Id,
      moved.C_Page__c,
      'Section should be moved to page 2'
    );
    System.assertEquals(1, moved.C_Order__c, 'Order should be 1');
  }

  // ─── Move Item - Question ───────────────────────────────────

  @IsTest
  static void testMoveItem_Question_SameParent() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Section__c section = [SELECT Id FROM C_Section__c LIMIT 1];
    List<C_Question__c> questions = [
      SELECT Id
      FROM C_Question__c
      WHERE C_Section__c = :section.Id
      ORDER BY C_Order__c
    ];

    Test.startTest();
    FormBuilderService.moveItem('Question', questions[0].Id, section.Id, 2);
    Test.stopTest();

    C_Question__c moved = [
      SELECT C_Section__c, C_Order__c
      FROM C_Question__c
      WHERE Id = :questions[0].Id
    ];
    System.assertEquals(
      section.Id,
      moved.C_Section__c,
      'Should remain in same section'
    );
    System.assertEquals(2, moved.C_Order__c, 'Order should be 2');
  }

  @IsTest
  static void testMoveItem_Question_CrossParent() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    List<C_Section__c> sections = [
      SELECT Id
      FROM C_Section__c
      ORDER BY C_Order__c
      LIMIT 2
    ];
    C_Question__c question = [
      SELECT Id
      FROM C_Question__c
      WHERE C_Section__c = :sections[0].Id
      ORDER BY C_Order__c
      LIMIT 1
    ];

    Test.startTest();
    FormBuilderService.moveItem('Question', question.Id, sections[1].Id, 1);
    Test.stopTest();

    C_Question__c moved = [
      SELECT C_Section__c, C_Order__c
      FROM C_Question__c
      WHERE Id = :question.Id
    ];
    System.assertEquals(
      sections[1].Id,
      moved.C_Section__c,
      'Question should be moved to section 2'
    );
  }

  // ─── Move Item - Response ───────────────────────────────────

  @IsTest
  static void testMoveItem_Response_SameParent() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    C_Question__c question = [SELECT Id FROM C_Question__c LIMIT 1];
    List<C_Response__c> responses = [
      SELECT Id
      FROM C_Response__c
      WHERE C_Question__c = :question.Id
      ORDER BY C_Order__c
    ];

    Test.startTest();
    FormBuilderService.moveItem('Response', responses[0].Id, question.Id, 2);
    Test.stopTest();

    C_Response__c moved = [
      SELECT C_Question__c, C_Order__c
      FROM C_Response__c
      WHERE Id = :responses[0].Id
    ];
    System.assertEquals(
      question.Id,
      moved.C_Question__c,
      'Should remain under same question'
    );
    System.assertEquals(2, moved.C_Order__c, 'Order should be 2');
  }

  @IsTest
  static void testMoveItem_Response_CrossParent() {
    FeatureUtil.testIsFormBuilderAdminOverride = true;
    List<C_Question__c> questions = [
      SELECT Id
      FROM C_Question__c
      ORDER BY C_Order__c
      LIMIT 2
    ];
    C_Response__c response = [
      SELECT Id, Name
      FROM C_Response__c
      WHERE C_Question__c = :questions[0].Id
      ORDER BY C_Order__c
      LIMIT 1
    ];
    String originalName = response.Name;
    Id originalId = response.Id;

    Integer beforeCount = [
      SELECT COUNT()
      FROM C_Response__c
      WHERE C_Question__c = :questions[1].Id
    ];

    Test.startTest();
    FormBuilderService.moveItem('Response', response.Id, questions[1].Id, 1);
    Test.stopTest();

    List<C_Response__c> oldParentResponses = [
      SELECT Id
      FROM C_Response__c
      WHERE Id = :originalId
    ];
    System.assertEquals(
      0,
      oldParentResponses.size(),
      'Original response should be deleted after cross-parent move'
    );

    Integer afterCount = [
      SELECT COUNT()
      FROM C_Response__c
      WHERE C_Question__c = :questions[1].Id
    ];
    System.assertEquals(
      beforeCount + 1,
      afterCount,
      'New parent should have one more response'
    );

    C_Response__c cloned = [
      SELECT Name, C_Question__c
      FROM C_Response__c
      WHERE C_Question__c = :questions[1].Id AND Name = :originalName
      LIMIT 1
    ];
    System.assertEquals(
      questions[1].Id,
      cloned.C_Question__c,
      'Cloned response should belong to new parent'
    );
  }

  private static User createRestrictedTestUser() {
    Profile stdProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String unique = String.valueOf(System.currentTimeMillis());
    User u = new User(
      Alias = 'rstrctd',
      Email = 'restricted' + unique + '@formbuilder.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RestrictedUser',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = stdProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'restricted' + unique + '@formbuilder.test'
    );
    insert u;
    return u;
  }
}

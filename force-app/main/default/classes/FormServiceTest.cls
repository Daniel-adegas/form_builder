/**
 * @description       : Test class for FormService - form structure retrieval and draft save
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
private class FormServiceTest {
  @TestSetup
  static void setupData() {
    FeatureUtil.testIsFormBuilderAdminOverride = null;
    TestDataFactory.createFullFormStructure();
  }

  @IsTest
  static void testGetFormStructure_Published() {
    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructure();
    Test.stopTest();

    Assert.isNotNull(pages, 'Pages list should not be null');
    Assert.areEqual(2, pages.size(), 'Should return 2 pages');

    FormService.Page_Wrapper firstPage = pages[0];
    Assert.areEqual(
      'Page 1',
      firstPage.pageName,
      'First page name should match'
    );
    Assert.isNotNull(firstPage.sections, 'Sections should not be null');
    Assert.areEqual(
      2,
      firstPage.sections.size(),
      'Page 1 should have 2 sections'
    );

    FormService.Section_Wrapper firstSection = firstPage.sections[0];
    Assert.isNotNull(firstSection.questions, 'Questions should not be null');
    Assert.areEqual(
      2,
      firstSection.questions.size(),
      'Section 1 should have 2 questions'
    );

    FormService.Question_Wrapper firstQuestion = firstSection.questions[0];
    Assert.isNotNull(firstQuestion.responses, 'Responses should not be null');
    Assert.areEqual(
      2,
      firstQuestion.responses.size(),
      'Each question should have 2 responses'
    );
  }

  @IsTest
  static void testGetFormStructureById_FullHierarchy() {
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];

    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructureById(
      form.Id
    );
    Test.stopTest();

    Assert.areEqual(2, pages.size(), 'Should return 2 pages');

    Integer totalSections = 0;
    Integer totalQuestions = 0;
    Integer totalResponses = 0;
    for (FormService.Page_Wrapper pw : pages) {
      totalSections += pw.sections.size();
      for (FormService.Section_Wrapper sw : pw.sections) {
        totalQuestions += sw.questions.size();
        for (FormService.Question_Wrapper qw : sw.questions) {
          totalResponses += qw.responses.size();
        }
      }
      Assert.isNotNull(
        pw.dependencies,
        'Dependencies list should be initialised'
      );
    }
    Assert.areEqual(4, totalSections, 'Total sections across pages');
    Assert.areEqual(8, totalQuestions, 'Total questions across sections');
    Assert.areEqual(16, totalResponses, 'Total responses across questions');
  }

  @IsTest
  static void testGetFormStructureById_Dependencies() {
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    List<C_Response__c> responses = [SELECT Id FROM C_Response__c LIMIT 1];
    List<C_Section__c> sections = [SELECT Id FROM C_Section__c LIMIT 2];

    C_Dependency__c dep = new C_Dependency__c(
      C_Controlling_Response__c = responses[0].Id,
      C_Target_Type__c = 'Section',
      C_Target_Section__c = sections[1].Id,
      C_Action__c = 'Show',
      C_Logic_Group__c = 'G1',
      C_Logic_Operator__c = 'AND'
    );
    insert dep;

    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructureById(
      form.Id
    );
    Test.stopTest();

    Boolean foundDep = false;
    for (FormService.Page_Wrapper pw : pages) {
      for (FormService.Dependency_Wrapper dw : pw.dependencies) {
        if (dw.controllingResponse == responses[0].Id) {
          foundDep = true;
          Assert.areEqual(
            'Show',
            dw.action,
            'Dependency action should be Show'
          );
          Assert.areEqual(
            'Section',
            dw.targetType,
            'Target type should be Section'
          );
          Assert.areEqual(
            sections[1].Id,
            dw.targetSection,
            'Target section should match'
          );
        }
      }
    }
    Assert.isTrue(
      foundDep,
      'Should find the inserted dependency in page wrappers'
    );
  }

  @IsTest
  static void testGetFormStructureWithMeta() {
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];

    Test.startTest();
    FormService.FormStructure_Wrapper wrapper = FormService.getFormStructureWithMeta(
      form.Id
    );
    Test.stopTest();

    Assert.isNotNull(wrapper, 'Wrapper should not be null');
    Assert.areEqual(
      'Full Test Form',
      wrapper.formName,
      'Form name should match'
    );
    Assert.areEqual(form.Id, wrapper.formId, 'Form Id should match');
    Assert.areEqual(
      'Complete form structure for testing',
      wrapper.description,
      'Form description should be returned on the wrapper'
    );
    Assert.areEqual(
      'en',
      wrapper.defaultLanguage,
      'Default language should be en'
    );
    Assert.isNotNull(wrapper.pages, 'Pages should not be null');
    Assert.areEqual(
      'classic',
      wrapper.layoutMode,
      'Renderer layout should be classic'
    );
    Assert.areEqual(2, wrapper.pages.size(), 'Should return 2 pages');
  }

  @IsTest
  static void testGetFormStructureWithMeta_Categories() {
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];

    Test.startTest();
    FormService.FormStructure_Wrapper wrapper = FormService.getFormStructureWithMeta(
      form.Id
    );
    Test.stopTest();

    Assert.isNotNull(wrapper.categories, 'Categories should not be null');
    Assert.areEqual(2, wrapper.categories.size(), 'Should return 2 categories');

    FormService.Category_Wrapper firstCat = wrapper.categories[0];
    Assert.areEqual(
      'Category 1',
      firstCat.categoryName,
      'First category name should match'
    );
    Assert.isNotNull(firstCat.pages, 'Category pages should not be null');
    Assert.areEqual(1, firstCat.pages.size(), 'Category 1 should have 1 page');
  }

  @IsTest
  static void testGetFormStructureWithMeta_BackwardCompatibility_NoCategories() {
    C_Form__c form = TestDataFactory.createForm();
    form.C_Status__c = 'Published';
    update form;
    TestDataFactory.createPage(form.Id, null, 1);

    Test.startTest();
    FormService.FormStructure_Wrapper wrapper = FormService.getFormStructureWithMeta(
      form.Id
    );
    Test.stopTest();

    Assert.isNotNull(
      wrapper.categories,
      'Categories should not be null even with no categories'
    );
    Assert.areEqual(
      1,
      wrapper.categories.size(),
      'Uncategorized pages go into synthetic General category'
    );
    Assert.areEqual(
      'General',
      wrapper.categories[0].categoryName,
      'Synthetic category should be named General'
    );
    Assert.areEqual(
      1,
      wrapper.categories[0].pages.size(),
      'General category should contain the uncategorized page'
    );
  }

  // ── Issue 1: single loadStructure call ─────────────────────────────────────

  @IsTest
  static void testGetFormStructureWithMeta_PagesAndCategoriesConsistent() {
    // If loadStructure were still called twice, wrapper.pages and the pages
    // bucketed inside wrapper.categories would be different object instances
    // built from separate SOQL runs. Verifying they represent the same IDs
    // proves a single shared load was used.
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];

    Test.startTest();
    FormService.FormStructure_Wrapper wrapper = FormService.getFormStructureWithMeta(
      form.Id
    );
    Test.stopTest();

    Set<Id> pageIdsFromCategories = new Set<Id>();
    Integer totalPagesInCategories = 0;
    for (FormService.Category_Wrapper cw : wrapper.categories) {
      for (FormService.Page_Wrapper pw : cw.pages) {
        pageIdsFromCategories.add(pw.pageId);
        totalPagesInCategories++;
      }
    }

    Assert.areEqual(
      wrapper.pages.size(),
      totalPagesInCategories,
      'Total pages across all categories must equal wrapper.pages.size()'
    );
    for (FormService.Page_Wrapper pw : wrapper.pages) {
      Assert.isTrue(
        pageIdsFromCategories.contains(pw.pageId),
        'Every page in wrapper.pages must appear in exactly one category bucket'
      );
    }
  }

  @IsTest
  static void testGetFormStructureWithMeta_SOQLWithinBounds() {
    // Query budget for getFormStructureWithMeta (single loadStructureInternal pass):
    //   1 C_Form + 4 structure (pages/sections/questions/responses)
    //   + up to 5 DependencyQueryUtil branches + 1 C_Category = 11 with full fixture.
    // A duplicate loadStructure call would roughly double the structure queries (~20+).
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];

    Test.startTest();
    FormService.getFormStructureWithMeta(form.Id);
    Integer queriesUsed = Limits.getQueries();
    Test.stopTest();

    Assert.isTrue(
      queriesUsed <= 11,
      'getFormStructureWithMeta should use at most 11 SOQL queries; used: ' +
      queriesUsed
    );
  }

  // ── Issue 2: category dependencies at runtime ───────────────────────────────

  @IsTest
  static void testGetFormStructureById_PageCategoryIdPopulated() {
    // categoryId on Page_Wrapper is required so the LWC renderer can build
    // its categoryPageMap without a second round-trip to the server.
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];
    C_Category__c cat1 = [
      SELECT Id
      FROM C_Category__c
      WHERE Name = 'Category 1'
      LIMIT 1
    ];
    C_Category__c cat2 = [
      SELECT Id
      FROM C_Category__c
      WHERE Name = 'Category 2'
      LIMIT 1
    ];

    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructureById(
      form.Id
    );
    Test.stopTest();

    // createFullFormStructure assigns Page 1 → Category 1, Page 2 → Category 2
    Assert.areEqual(
      cat1.Id,
      pages[0].categoryId,
      'Page 1 categoryId should match Category 1'
    );
    Assert.areEqual(
      cat2.Id,
      pages[1].categoryId,
      'Page 2 categoryId should match Category 2'
    );
  }

  @IsTest
  static void testGetFormStructureById_CategoryDependency() {
    // A dependency targeting a category must reach the LWC via targetCategory.
    // Before fix the field was absent from the SOQL SELECT and the wrapper,
    // so the renderer would silently skip category-level show/hide rules.
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];
    C_Response__c resp = [SELECT Id FROM C_Response__c LIMIT 1];
    C_Category__c cat = [
      SELECT Id
      FROM C_Category__c
      WHERE Name = 'Category 2'
      LIMIT 1
    ];

    C_Dependency__c dep = new C_Dependency__c(
      C_Controlling_Response__c = resp.Id,
      C_Target_Type__c = 'Category',
      C_Target_Category__c = cat.Id,
      C_Action__c = 'Hide'
    );
    insert dep;

    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructureById(
      form.Id
    );
    Test.stopTest();

    Boolean foundCategoryDep = false;
    for (FormService.Page_Wrapper pw : pages) {
      for (FormService.Dependency_Wrapper dw : pw.dependencies) {
        if (dw.controllingResponse == resp.Id && dw.targetType == 'Category') {
          foundCategoryDep = true;
          Assert.areEqual(
            cat.Id,
            dw.targetCategory,
            'targetCategory must be populated on the wrapper'
          );
          Assert.areEqual('Hide', dw.action, 'action should be Hide');
          Assert.areEqual(
            null,
            dw.targetPage,
            'targetPage must be null for a category dependency'
          );
          Assert.areEqual(
            null,
            dw.targetSection,
            'targetSection must be null for a category dependency'
          );
          Assert.areEqual(
            null,
            dw.targetQuestion,
            'targetQuestion must be null for a category dependency'
          );
        }
      }
    }
    Assert.isTrue(
      foundCategoryDep,
      'Category dependency must appear in the page wrappers returned by getFormStructureById'
    );
  }

  @IsTest
  static void testGetFormStructureWithMeta_FormLevelDependencies() {
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];
    C_Response__c resp = [SELECT Id FROM C_Response__c LIMIT 1];
    List<C_Section__c> sections = [SELECT Id FROM C_Section__c LIMIT 2];

    C_Dependency__c dep = new C_Dependency__c(
      C_Controlling_Response__c = resp.Id,
      C_Target_Type__c = 'Section',
      C_Target_Section__c = sections[1].Id,
      C_Action__c = 'Show'
    );
    insert dep;

    Test.startTest();
    FormService.FormStructure_Wrapper wrapper = FormService.getFormStructureWithMeta(
      form.Id
    );
    Test.stopTest();

    Assert.isNotNull(
      wrapper.dependencies,
      'Form-level dependencies should be initialised'
    );
    Assert.areEqual(
      1,
      wrapper.dependencies.size(),
      'Form-level dependencies should include the inserted rule'
    );
    Assert.areEqual(
      resp.Id,
      wrapper.dependencies[0].controllingResponse,
      'Controlling response should match'
    );
    Assert.areEqual(
      2,
      wrapper.pages.size(),
      'Multi-page fixture should return 2 pages'
    );
    Assert.areEqual(
      0,
      wrapper.pages[0].dependencies.size(),
      'Page wrappers should not duplicate form-wide dependencies'
    );
    Assert.areEqual(
      0,
      wrapper.pages[1].dependencies.size(),
      'Page 2+ should not carry form-wide dependencies'
    );
  }

  @IsTest
  static void testGetFormStructureById_DependenciesOnFirstPageOnly() {
    C_Form__c form = [
      SELECT Id
      FROM C_Form__c
      WHERE C_Status__c = 'Published'
      LIMIT 1
    ];
    C_Response__c resp = [SELECT Id FROM C_Response__c LIMIT 1];
    List<C_Section__c> sections = [SELECT Id FROM C_Section__c LIMIT 2];

    C_Dependency__c dep = new C_Dependency__c(
      C_Controlling_Response__c = resp.Id,
      C_Target_Type__c = 'Section',
      C_Target_Section__c = sections[1].Id,
      C_Action__c = 'Hide'
    );
    insert dep;

    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructureById(
      form.Id
    );
    Test.stopTest();

    Assert.areEqual(2, pages.size(), 'Should return 2 pages');
    Assert.areEqual(
      1,
      pages[0].dependencies.size(),
      'Page 1 carries form-wide deps for legacy getFormStructureById callers'
    );
    Assert.areEqual(
      0,
      pages[1].dependencies.size(),
      'Page 2 should not carry duplicated dependencies'
    );
    Assert.areEqual(
      'Hide',
      pages[0].dependencies[0].action,
      'Dependency action should be Hide'
    );
  }

  // ── Existing tests ──────────────────────────────────────────────────────────

  @IsTest
  static void testSaveFormSubmission_DraftJSON() {
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    C_Form_Submission__c submission = TestDataFactory.createSubmission(form.Id);
    String draftJson = '{"page":1,"answers":{"q1":"test"}}';

    Test.startTest();
    FormService.saveFormSubmission(submission.Id, draftJson);
    Test.stopTest();

    C_Form_Submission__c updated = [
      SELECT C_Draft_State_JSON__c
      FROM C_Form_Submission__c
      WHERE Id = :submission.Id
    ];
    Assert.areEqual(
      draftJson,
      updated.C_Draft_State_JSON__c,
      'Draft JSON should be persisted'
    );
  }

  @IsTest
  static void testSaveFormSubmission_RejectsNonOwnerNonAdmin() {
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];
    User otherOwner = createOtherFormServiceTestUser();
    C_Form_Submission__c submission;
    System.runAs(otherOwner) {
      submission = TestDataFactory.createSubmission(form.Id);
    }

    FeatureUtil.testIsFormBuilderAdminOverride = false;
    String draftJson = '{"page":1,"answers":{"q1":"blocked"}}';

    C_Form_Submission__c visibleSubmission = [
      SELECT OwnerId
      FROM C_Form_Submission__c
      WHERE Id = :submission.Id
    ];
    Assert.areEqual(
      otherOwner.Id,
      visibleSubmission.OwnerId,
      'Submission should be owned by the other user'
    );
    Assert.areNotEqual(
      UserInfo.getUserId(),
      visibleSubmission.OwnerId,
      'Running user should not own the submission under test'
    );

    Test.startTest();
    Boolean caughtException = false;
    try {
      FormService.saveFormSubmission(submission.Id, draftJson);
    } catch (AuraHandledException e) {
      caughtException = true;
      Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
    } finally {
      FeatureUtil.testIsFormBuilderAdminOverride = null;
    }
    Test.stopTest();

    Assert.isTrue(
      caughtException,
      'Expected AuraHandledException for non-owner non-admin save'
    );

    C_Form_Submission__c unchanged = [
      SELECT C_Draft_State_JSON__c
      FROM C_Form_Submission__c
      WHERE Id = :submission.Id
    ];
    Assert.isNull(
      unchanged.C_Draft_State_JSON__c,
      'Draft JSON should not be persisted when save is rejected'
    );
  }

  private static User createOtherFormServiceTestUser() {
    Profile stdProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String unique = String.valueOf(System.currentTimeMillis());
    User u = new User(
      Alias = 'othownr',
      Email = 'othownr' + unique + '@formbuilder.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'OtherOwner',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = stdProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'othownr' + unique + '@formbuilder.test'
    );
    insert u;

    PermissionSet userPs = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Forms_User'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = u.Id,
      PermissionSetId = userPs.Id
    );

    return u;
  }

  @IsTest
  static void testGetFormStructure_NoPublishedForm() {
    delete [SELECT Id FROM C_Form__c];

    Test.startTest();
    Boolean caughtException = false;
    try {
      FormService.getFormStructure();
    } catch (AuraHandledException e) {
      caughtException = true;
      Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
    }
    Test.stopTest();

    Assert.isTrue(
      caughtException,
      'Should throw AuraHandledException when no published form exists'
    );
  }

  @IsTest
  static void testQuestionWrapper_TypeSpecificFields() {
    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructureById(
      form.Id
    );
    Test.stopTest();

    Boolean foundTable = false;
    Boolean foundFile = false;
    for (FormService.Page_Wrapper pw : pages) {
      for (FormService.Section_Wrapper sw : pw.sections) {
        for (FormService.Question_Wrapper qw : sw.questions) {
          if (qw.questionType == 'Table') {
            foundTable = true;
            Assert.isNotNull(qw.tableColumns, 'Table columns should be set');
          }
          if (qw.questionType == 'File') {
            foundFile = true;
            Assert.isNotNull(
              qw.acceptedFileTypes,
              'Accepted file types should be set'
            );
          }
        }
      }
    }
    Assert.isTrue(foundTable, 'Should find a Table-type question');
    Assert.isTrue(foundFile, 'Should find a File-type question');
  }

  @IsTest
  static void testQuestionWrapper_MaxWordCount() {
    C_Question__c q = [
      SELECT Id
      FROM C_Question__c
      WHERE C_Type__c = 'Long Text'
      LIMIT 1
    ];
    q.C_Max_Word_Count__c = 100;
    update q;

    C_Form__c form = [SELECT Id FROM C_Form__c LIMIT 1];

    Test.startTest();
    List<FormService.Page_Wrapper> pages = FormService.getFormStructureById(
      form.Id
    );
    Test.stopTest();

    Boolean found = false;
    for (FormService.Page_Wrapper pw : pages) {
      for (FormService.Section_Wrapper sw : pw.sections) {
        for (FormService.Question_Wrapper qw : sw.questions) {
          if (qw.questionId == q.Id) {
            Assert.areEqual(
              100,
              qw.maxWordCount,
              'maxWordCount should map from C_Max_Word_Count__c'
            );
            found = true;
          }
        }
      }
    }
    Assert.isTrue(found, 'Should find the Long Text question in structure');
  }
}

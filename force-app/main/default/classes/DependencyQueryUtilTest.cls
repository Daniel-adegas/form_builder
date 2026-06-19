/**
 * @description Tests selective C_Dependency__c query and delete helpers.
 */
@IsTest
private class DependencyQueryUtilTest {
  @TestSetup
  static void setupData() {
    TestDataFactory.createFullFormStructure();
  }

  @IsTest
  static void queryByFormScope_findsDependenciesByControllingResponseAndTargetType() {
    C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];
    C_Section__c section = [SELECT Id, C_Page__c FROM C_Section__c LIMIT 1];
    C_Page__c page = [
      SELECT Id, C_Category__c
      FROM C_Page__c
      WHERE Id = :section.C_Page__c
      LIMIT 1
    ];
    C_Question__c question = [
      SELECT Id
      FROM C_Question__c
      WHERE C_Section__c = :section.Id
      LIMIT 1
    ];

    C_Dependency__c sectionDep = TestDataFactory.createDependency(
      response.Id,
      section.Id,
      'Show'
    );
    C_Dependency__c questionDep = new C_Dependency__c(
      C_Controlling_Response__c = response.Id,
      C_Target_Type__c = 'Question',
      C_Target_Question__c = question.Id,
      C_Action__c = 'Hide',
      C_Logic_Group__c = 'G1',
      C_Logic_Operator__c = 'AND'
    );
    insert questionDep;

    C_Dependency__c pageDep = new C_Dependency__c(
      C_Controlling_Response__c = response.Id,
      C_Target_Type__c = 'Page',
      C_Target_Page__c = page.Id,
      C_Action__c = 'Require',
      C_Logic_Group__c = 'G2',
      C_Logic_Operator__c = 'OR'
    );
    insert pageDep;

    C_Dependency__c categoryDep;
    if (page.C_Category__c != null) {
      categoryDep = new C_Dependency__c(
        C_Controlling_Response__c = response.Id,
        C_Target_Type__c = 'Category',
        C_Target_Category__c = page.C_Category__c,
        C_Action__c = 'Show',
        C_Logic_Group__c = 'G3',
        C_Logic_Operator__c = 'AND'
      );
      insert categoryDep;
    }

    Set<Id> responseIds = new Set<Id>{ response.Id };
    Set<Id> sectionIds = new Set<Id>{ section.Id };
    Set<Id> questionIds = new Set<Id>{ question.Id };
    Set<Id> pageIds = new Set<Id>{ page.Id };
    Set<Id> categoryIds = page.C_Category__c != null
      ? new Set<Id>{ page.C_Category__c }
      : new Set<Id>();

    Test.startTest();
    List<C_Dependency__c> deps = DependencyQueryUtil.queryByFormScope(
      responseIds,
      categoryIds,
      pageIds,
      sectionIds,
      questionIds
    );
    Test.stopTest();

    Set<Id> depIds = new Set<Id>();
    for (C_Dependency__c dep : deps) {
      depIds.add(dep.Id);
    }

    System.assert(
      depIds.contains(sectionDep.Id),
      'Section-target dependency should be returned'
    );
    System.assert(
      depIds.contains(questionDep.Id),
      'Question-target dependency should be returned'
    );
    System.assert(
      depIds.contains(pageDep.Id),
      'Page-target dependency should be returned'
    );
    if (page.C_Category__c != null) {
      System.assert(
        depIds.contains(categoryDep.Id),
        'Category-target dependency should be returned'
      );
    }
  }

  @IsTest
  static void deleteByFormScope_removesMatchingDependenciesOnly() {
    C_Response__c response = [SELECT Id FROM C_Response__c LIMIT 1];
    List<C_Section__c> sections = [SELECT Id FROM C_Section__c LIMIT 2];
    C_Dependency__c toDelete = TestDataFactory.createDependency(
      response.Id,
      sections[0].Id,
      'Show'
    );
    C_Dependency__c toKeep = TestDataFactory.createDependency(
      response.Id,
      sections[1].Id,
      'Hide'
    );

    Test.startTest();
    DependencyQueryUtil.deleteByFormScope(
      new Set<Id>(),
      new Set<Id>(),
      new Set<Id>(),
      new Set<Id>{ sections[0].Id },
      new Set<Id>()
    );
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM C_Dependency__c WHERE Id = :toDelete.Id],
      'Matching section-target dependency should be deleted'
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM C_Dependency__c WHERE Id = :toKeep.Id],
      'Non-matching dependency should remain'
    );
  }
}

/**
 * @description Selective C_Dependency__c queries split by target type to avoid 5-way OR table scans.
 */
public with sharing class DependencyQueryUtil {
  private static final String TARGET_TYPE_CATEGORY = 'Category';
  private static final String TARGET_TYPE_PAGE = 'Page';
  private static final String TARGET_TYPE_SECTION = 'Section';
  private static final String TARGET_TYPE_QUESTION = 'Question';

  private static final String DEPENDENCY_FIELDS =
    'Id, Name, C_Controlling_Response__c, C_Target_Type__c, C_Action__c, ' +
    'C_Target_Category__c, C_Target_Page__c, C_Target_Section__c, C_Target_Question__c, ' +
    'C_Logic_Group__c, C_Logic_Operator__c';

  private static List<C_Dependency__c> selectByControllingResponse(
    Set<Id> responseIds
  ) {
    return Database.query(
      'SELECT ' +
        DEPENDENCY_FIELDS +
        ' FROM C_Dependency__c WHERE C_Controlling_Response__c IN :responseIds'
    );
  }

  private static List<C_Dependency__c> selectByTargetCategory(
    Set<Id> categoryIds
  ) {
    return Database.query(
      'SELECT ' +
        DEPENDENCY_FIELDS +
        ' FROM C_Dependency__c WHERE C_Target_Type__c = :TARGET_TYPE_CATEGORY AND C_Target_Category__c IN :categoryIds'
    );
  }

  private static List<C_Dependency__c> selectByTargetPage(Set<Id> pageIds) {
    return Database.query(
      'SELECT ' +
        DEPENDENCY_FIELDS +
        ' FROM C_Dependency__c WHERE C_Target_Type__c = :TARGET_TYPE_PAGE AND C_Target_Page__c IN :pageIds'
    );
  }

  private static List<C_Dependency__c> selectByTargetSection(
    Set<Id> sectionIds
  ) {
    return Database.query(
      'SELECT ' +
        DEPENDENCY_FIELDS +
        ' FROM C_Dependency__c WHERE C_Target_Type__c = :TARGET_TYPE_SECTION AND C_Target_Section__c IN :sectionIds'
    );
  }

  private static List<C_Dependency__c> selectByTargetQuestion(
    Set<Id> questionIds
  ) {
    return Database.query(
      'SELECT ' +
        DEPENDENCY_FIELDS +
        ' FROM C_Dependency__c WHERE C_Target_Type__c = :TARGET_TYPE_QUESTION AND C_Target_Question__c IN :questionIds'
    );
  }

  /**
   * Loads dependencies scoped to a form's responses and target element ids.
   * Each branch uses a single indexed lookup field instead of a multi-branch OR.
   */
  public static List<C_Dependency__c> queryByFormScope(
    Set<Id> responseIds,
    Set<Id> categoryIds,
    Set<Id> pageIds,
    Set<Id> sectionIds,
    Set<Id> questionIds
  ) {
    Map<Id, C_Dependency__c> byId = new Map<Id, C_Dependency__c>();

    if (!responseIds.isEmpty()) {
      for (C_Dependency__c dep : selectByControllingResponse(responseIds)) {
        byId.put(dep.Id, dep);
      }
    }
    if (!categoryIds.isEmpty()) {
      for (C_Dependency__c dep : selectByTargetCategory(categoryIds)) {
        byId.put(dep.Id, dep);
      }
    }
    if (!pageIds.isEmpty()) {
      for (C_Dependency__c dep : selectByTargetPage(pageIds)) {
        byId.put(dep.Id, dep);
      }
    }
    if (!sectionIds.isEmpty()) {
      for (C_Dependency__c dep : selectByTargetSection(sectionIds)) {
        byId.put(dep.Id, dep);
      }
    }
    if (!questionIds.isEmpty()) {
      for (C_Dependency__c dep : selectByTargetQuestion(questionIds)) {
        byId.put(dep.Id, dep);
      }
    }

    return byId.values();
  }

  /**
   * Deletes dependencies scoped to a form's responses and target element ids.
   * Pass empty sets for branches that do not apply to the delete context.
   */
  public static void deleteByFormScope(
    Set<Id> responseIds,
    Set<Id> categoryIds,
    Set<Id> pageIds,
    Set<Id> sectionIds,
    Set<Id> questionIds
  ) {
    if (!responseIds.isEmpty()) {
      delete [
        SELECT Id
        FROM C_Dependency__c
        WHERE C_Controlling_Response__c IN :responseIds
      ];
    }
    if (!categoryIds.isEmpty()) {
      delete [
        SELECT Id
        FROM C_Dependency__c
        WHERE
          C_Target_Type__c = :TARGET_TYPE_CATEGORY
          AND C_Target_Category__c IN :categoryIds
      ];
    }
    if (!pageIds.isEmpty()) {
      delete [
        SELECT Id
        FROM C_Dependency__c
        WHERE
          C_Target_Type__c = :TARGET_TYPE_PAGE
          AND C_Target_Page__c IN :pageIds
      ];
    }
    if (!sectionIds.isEmpty()) {
      delete [
        SELECT Id
        FROM C_Dependency__c
        WHERE
          C_Target_Type__c = :TARGET_TYPE_SECTION
          AND C_Target_Section__c IN :sectionIds
      ];
    }
    if (!questionIds.isEmpty()) {
      delete [
        SELECT Id
        FROM C_Dependency__c
        WHERE
          C_Target_Type__c = :TARGET_TYPE_QUESTION
          AND C_Target_Question__c IN :questionIds
      ];
    }
  }
}

/**
 * @description       : Service class for loading form structure and saving draft state
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
 **/
public with sharing class FormService {
  @AuraEnabled(cacheable=false)
  public static List<Page_Wrapper> getFormStructure() {
    try {
      // Returns the most recently modified Published form (non-deterministic without ORDER BY)
      C_Form__c form = [
        SELECT Id, Name, C_Description__c
        FROM C_Form__c
        WHERE C_Status__c = 'Published'
        ORDER BY LastModifiedDate DESC
        LIMIT 1
      ];
      return getFormStructureById(form.Id);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=false)
  public static FormStructure_Wrapper getFormStructureWithMeta(Id formId) {
    try {
      C_Form__c form = [
        SELECT
          Id,
          Name,
          C_Description__c,
          C_Default_Language__c,
          C_Layout_Mode__c
        FROM C_Form__c
        WHERE Id = :formId
        LIMIT 1
      ];
      FormStructure_Wrapper wrapper = new FormStructure_Wrapper();
      wrapper.formName = form.Name;
      wrapper.formId = form.Id;
      wrapper.description = form.C_Description__c;
      wrapper.defaultLanguage = form.C_Default_Language__c;
      wrapper.layoutMode = String.isBlank(form.C_Layout_Mode__c)
        ? 'classic'
        : form.C_Layout_Mode__c;
      FormMetadataReader reader = new FormMetadataReader();
      StructureLoadResult structure = reader.loadStructureInternal(formId);
      wrapper.pages = structure.pages;
      wrapper.dependencies = structure.dependencies;
      wrapper.categories = reader.loadCategoryStructure(
        formId,
        structure.pages
      );
      return wrapper;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=false)
  public static List<Page_Wrapper> getFormStructureById(Id formId) {
    try {
      return new FormMetadataReader().loadStructure(formId);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  private class StructureLoadResult {
    List<Page_Wrapper> pages;
    List<Dependency_Wrapper> dependencies;

    StructureLoadResult(
      List<Page_Wrapper> pages,
      List<Dependency_Wrapper> dependencies
    ) {
      this.pages = pages;
      this.dependencies = dependencies;
    }
  }

  private without sharing class FormMetadataReader {
    public List<Category_Wrapper> loadCategoryStructure(
      Id formId,
      List<Page_Wrapper> allPageWrappers
    ) {
      List<Category_Wrapper> categoryWrappers = new List<Category_Wrapper>();

      List<C_Category__c> categories = [
        SELECT Id, Name, C_Order__c, C_Description__c, C_Icon__c, C_Is_Active__c
        FROM C_Category__c
        WHERE C_Form__c = :formId
        ORDER BY C_Order__c
      ];

      Map<Id, List<Page_Wrapper>> pagesByCategory = new Map<Id, List<Page_Wrapper>>();
      List<Page_Wrapper> uncategorized = new List<Page_Wrapper>();

      for (Page_Wrapper pw : allPageWrappers) {
        Id catId = pw.categoryId;
        if (catId != null) {
          if (!pagesByCategory.containsKey(catId)) {
            pagesByCategory.put(catId, new List<Page_Wrapper>());
          }
          pagesByCategory.get(catId).add(pw);
        } else {
          uncategorized.add(pw);
        }
      }

      Integer catOrder = 1;
      for (C_Category__c cat : categories) {
        Category_Wrapper cw = new Category_Wrapper();
        cw.categoryId = cat.Id;
        cw.categoryName = cat.Name;
        cw.description = cat.C_Description__c;
        cw.icon = cat.C_Icon__c;
        cw.isActive = cat.C_Is_Active__c;
        cw.order = catOrder++;
        cw.pages = pagesByCategory.containsKey(cat.Id)
          ? pagesByCategory.get(cat.Id)
          : new List<Page_Wrapper>();
        categoryWrappers.add(cw);
      }

      if (!uncategorized.isEmpty()) {
        Category_Wrapper general = new Category_Wrapper();
        general.categoryId = null;
        general.categoryName = 'General';
        general.description = null;
        general.icon = null;
        general.isActive = true;
        general.order = catOrder;
        general.pages = uncategorized;
        categoryWrappers.add(general);
      }

      return categoryWrappers;
    }

    public List<Page_Wrapper> loadStructure(Id formId) {
      StructureLoadResult result = loadStructureInternal(formId);
      attachDependenciesForLegacyPageApi(result);
      return result.pages;
    }

    /**
     * Loads form pages and form-wide dependencies separately.
     * Dependencies are not scoped to individual pages; consumers should read
     * FormStructure_Wrapper.dependencies or pages[0].dependencies (legacy).
     */
    public StructureLoadResult loadStructureInternal(Id formId) {
      List<Page_Wrapper> pageWrappers = new List<Page_Wrapper>();

      List<C_Page__c> pages = [
        SELECT Id, Name, C_Description__c, C_Order__c, C_Category__c
        FROM C_Page__c
        WHERE C_Form__c = :formId
        ORDER BY C_Order__c
      ];

      Map<Id, List<C_Section__c>> sectionsByPage = new Map<Id, List<C_Section__c>>();
      for (C_Section__c section : [
        SELECT Id, Name, C_Page__c, C_Order__c, C_Weight__c, C_Bonus__c
        FROM C_Section__c
        WHERE C_Page__c IN :pages
        ORDER BY C_Order__c
      ]) {
        if (!sectionsByPage.containsKey(section.C_Page__c))
          sectionsByPage.put(section.C_Page__c, new List<C_Section__c>());
        sectionsByPage.get(section.C_Page__c).add(section);
      }

      Set<Id> sectionIds = new Set<Id>();
      for (List<C_Section__c> sections : sectionsByPage.values())
        for (C_Section__c s : sections)
          sectionIds.add(s.Id);

      Map<Id, List<C_Question__c>> questionsBySection = new Map<Id, List<C_Question__c>>();
      for (C_Question__c q : [
        SELECT
          Id,
          Name,
          C_Question_Text__c,
          C_Help_Text__c,
          C_Section__c,
          C_Order__c,
          C_Type__c,
          C_Accepted_File_Types__c,
          C_Table_Columns__c,
          C_Is_Required__c,
          C_Is_Disabled__c,
          C_Validation_Message__c,
          C_Validation_Pattern__c,
          C_Placeholder__c,
          C_Max_Length__c,
          C_Max_Word_Count__c,
          C_Min_Value__c,
          C_Max_Value__c,
          C_Table_Min_Rows__c,
          C_Table_Max_Rows__c,
          C_Max_Files__c,
          C_Max_File_Size_MB__c,
          C_Weight__c,
          C_Number_Decimal_Places__c,
          C_Layout_Span__c,
          C_Cross_Field_Rules_JSON__c
        FROM C_Question__c
        WHERE C_Section__c IN :sectionIds
        ORDER BY C_Order__c
      ]) {
        if (!questionsBySection.containsKey(q.C_Section__c))
          questionsBySection.put(q.C_Section__c, new List<C_Question__c>());
        questionsBySection.get(q.C_Section__c).add(q);
      }

      Set<Id> questionIds = new Set<Id>();
      for (List<C_Question__c> qs : questionsBySection.values())
        for (C_Question__c q : qs)
          questionIds.add(q.Id);

      Map<Id, List<C_Response__c>> responsesByQuestion = new Map<Id, List<C_Response__c>>();
      Set<Id> responseIds = new Set<Id>();
      for (C_Response__c r : [
        SELECT
          Id,
          Name,
          C_Response_Text__c,
          C_Question__c,
          C_Order__c,
          C_Points__c,
          C_Requires_Details__c
        FROM C_Response__c
        WHERE C_Question__c IN :questionIds
        ORDER BY C_Order__c
      ]) {
        responseIds.add(r.Id);
        if (!responsesByQuestion.containsKey(r.C_Question__c))
          responsesByQuestion.put(r.C_Question__c, new List<C_Response__c>());
        responsesByQuestion.get(r.C_Question__c).add(r);
      }

      Set<Id> pageIds = new Set<Id>();
      Set<Id> categoryIds = new Set<Id>();
      for (C_Page__c p : pages) {
        pageIds.add(p.Id);
        if (p.C_Category__c != null)
          categoryIds.add(p.C_Category__c);
      }

      List<C_Dependency__c> dependencies = DependencyQueryUtil.queryByFormScope(
        responseIds,
        categoryIds,
        pageIds,
        sectionIds,
        questionIds
      );

      List<Dependency_Wrapper> allDeps = new List<Dependency_Wrapper>();
      for (C_Dependency__c dep : dependencies) {
        Dependency_Wrapper dw = new Dependency_Wrapper();
        dw.controllingResponse = dep.C_Controlling_Response__c;
        dw.targetType = dep.C_Target_Type__c;
        dw.targetCategory = dep.C_Target_Category__c;
        dw.targetPage = dep.C_Target_Page__c;
        dw.targetSection = dep.C_Target_Section__c;
        dw.targetQuestion = dep.C_Target_Question__c;
        dw.action = dep.C_Action__c;
        dw.logicGroup = dep.C_Logic_Group__c;
        dw.logicOperator = dep.C_Logic_Operator__c;
        allDeps.add(dw);
      }

      Integer pageOrder = 1;
      for (C_Page__c page : pages) {
        Page_Wrapper pw = new Page_Wrapper();
        pw.pageName = page.Name;
        pw.pageId = page.Id;
        pw.categoryId = page.C_Category__c;
        pw.description = page.C_Description__c;
        pw.order = pageOrder++;
        pw.sections = new List<Section_Wrapper>();
        pw.dependencies = new List<Dependency_Wrapper>();

        if (sectionsByPage.containsKey(page.Id)) {
          for (C_Section__c section : sectionsByPage.get(page.Id)) {
            Section_Wrapper sw = new Section_Wrapper();
            sw.sectionId = section.Id;
            sw.sectionName = section.Name;
            sw.weight = section.C_Weight__c;
            sw.bonus = section.C_Bonus__c;
            sw.hidden = false;
            sw.questions = new List<Question_Wrapper>();

            if (questionsBySection.containsKey(section.Id)) {
              for (
                C_Question__c question : questionsBySection.get(section.Id)
              ) {
                Question_Wrapper qw = new Question_Wrapper();
                qw.questionId = question.Id;
                qw.questionName = question.Name;
                qw.questionText = question.C_Question_Text__c;
                qw.helpText = question.C_Help_Text__c;
                qw.questionType = question.C_Type__c;
                qw.acceptedFileTypes = question.C_Accepted_File_Types__c;
                qw.tableColumns = question.C_Table_Columns__c;
                qw.isRequired = question.C_Is_Required__c;
                qw.isDisabled = question.C_Is_Disabled__c;
                qw.placeholder = question.C_Placeholder__c;
                qw.maxLength = question.C_Max_Length__c;
                qw.maxWordCount = question.C_Max_Word_Count__c;
                qw.minValue = question.C_Min_Value__c;
                qw.maxValue = question.C_Max_Value__c;
                qw.validationPattern = question.C_Validation_Pattern__c;
                qw.validationMessage = question.C_Validation_Message__c;
                qw.crossFieldRules = question.C_Cross_Field_Rules_JSON__c;
                qw.maxFiles = question.C_Max_Files__c;
                qw.maxFileSizeMB = question.C_Max_File_Size_MB__c;
                qw.tableMinRows = question.C_Table_Min_Rows__c;
                qw.tableMaxRows = question.C_Table_Max_Rows__c;
                qw.weight = question.C_Weight__c;
                qw.numberDecimalPlaces = question.C_Number_Decimal_Places__c;
                qw.layoutSpan = question.C_Layout_Span__c;
                qw.hidden = false;
                qw.responses = new List<Response_Wrapper>();

                if (responsesByQuestion.containsKey(question.Id)) {
                  for (
                    C_Response__c resp : responsesByQuestion.get(question.Id)
                  ) {
                    Response_Wrapper rw = new Response_Wrapper();
                    rw.responseId = resp.Id;
                    rw.responseName = resp.Name;
                    rw.responseText = resp.C_Response_Text__c;
                    rw.points = resp.C_Points__c;
                    rw.requiresDetails = resp.C_Requires_Details__c;
                    qw.responses.add(rw);
                  }
                }
                sw.questions.add(qw);
              }
            }
            pw.sections.add(sw);
          }
        }
        pageWrappers.add(pw);
      }
      return new StructureLoadResult(pageWrappers, allDeps);
    }

    /**
     * getFormStructureById returns pages only; attach form-wide deps to page 1
     * for callers that predate FormStructure_Wrapper.dependencies.
     */
    private void attachDependenciesForLegacyPageApi(
      StructureLoadResult result
    ) {
      if (!result.pages.isEmpty()) {
        result.pages[0].dependencies = result.dependencies;
      }
    }
  }

  @AuraEnabled
  public static void saveFormSubmission(Id formSubmissionId, String json) {
    try {
      List<C_Form_Submission__c> existing = [
        SELECT Id, OwnerId
        FROM C_Form_Submission__c
        WHERE Id = :formSubmissionId
        LIMIT 1
      ];
      if (existing.isEmpty()) {
        throw new AuraHandledException('Form submission not found.');
      }
      if (
        existing[0].OwnerId != UserInfo.getUserId() &&
        !FeatureUtil.isFormBuilderAdmin()
      ) {
        throw new AuraHandledException(
          'You do not have permission to update this submission.'
        );
      }
      C_Form_Submission__c submission = new C_Form_Submission__c(
        Id = formSubmissionId,
        C_Draft_State_JSON__c = json
      );
      update submission;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  public class Page_Wrapper {
    @AuraEnabled
    public String pageName { get; set; }
    @AuraEnabled
    public Id pageId { get; set; }
    @AuraEnabled
    public Id categoryId { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public Integer order { get; set; }
    @AuraEnabled
    public List<Section_Wrapper> sections { get; set; }
    @AuraEnabled
    public List<Dependency_Wrapper> dependencies { get; set; }
  }

  public class Section_Wrapper {
    @AuraEnabled
    public Id sectionId { get; set; }
    @AuraEnabled
    public String sectionName { get; set; }
    @AuraEnabled
    public Decimal weight { get; set; }
    @AuraEnabled
    public Boolean bonus { get; set; }
    @AuraEnabled
    public Boolean hidden { get; set; }
    @AuraEnabled
    public List<Question_Wrapper> questions { get; set; }
  }

  public class Question_Wrapper {
    @AuraEnabled
    public Id questionId { get; set; }
    @AuraEnabled
    public String questionName { get; set; }
    @AuraEnabled
    public String questionText { get; set; }
    @AuraEnabled
    public String helpText { get; set; }
    @AuraEnabled
    public String questionType { get; set; }
    @AuraEnabled
    public String acceptedFileTypes { get; set; }
    @AuraEnabled
    public String tableColumns { get; set; }
    @AuraEnabled
    public Boolean isRequired { get; set; }
    @AuraEnabled
    public Boolean isDisabled { get; set; }
    @AuraEnabled
    public Boolean hidden { get; set; }
    @AuraEnabled
    public String placeholder { get; set; }
    @AuraEnabled
    public Decimal maxLength { get; set; }
    @AuraEnabled
    public Decimal maxWordCount { get; set; }
    @AuraEnabled
    public Decimal minValue { get; set; }
    @AuraEnabled
    public Decimal maxValue { get; set; }
    @AuraEnabled
    public String validationPattern { get; set; }
    @AuraEnabled
    public String validationMessage { get; set; }
    @AuraEnabled
    public String crossFieldRules { get; set; }
    @AuraEnabled
    public Decimal maxFiles { get; set; }
    @AuraEnabled
    public Decimal maxFileSizeMB { get; set; }
    @AuraEnabled
    public Decimal tableMinRows { get; set; }
    @AuraEnabled
    public Decimal tableMaxRows { get; set; }
    @AuraEnabled
    public Decimal weight { get; set; }
    @AuraEnabled
    public Decimal numberDecimalPlaces { get; set; }
    @AuraEnabled
    public String layoutSpan { get; set; }
    @AuraEnabled
    public List<Response_Wrapper> responses { get; set; }
  }

  public class Response_Wrapper {
    @AuraEnabled
    public Id responseId { get; set; }
    @AuraEnabled
    public String responseName { get; set; }
    @AuraEnabled
    public String responseText { get; set; }
    @AuraEnabled
    public Decimal points { get; set; }
    @AuraEnabled
    public Boolean requiresDetails { get; set; }
  }

  public class Dependency_Wrapper {
    @AuraEnabled
    public Id controllingResponse { get; set; }
    @AuraEnabled
    public String targetType { get; set; }
    @AuraEnabled
    public Id targetCategory { get; set; }
    @AuraEnabled
    public Id targetPage { get; set; }
    @AuraEnabled
    public Id targetSection { get; set; }
    @AuraEnabled
    public Id targetQuestion { get; set; }
    @AuraEnabled
    public String action { get; set; }
    @AuraEnabled
    public String logicGroup { get; set; }
    @AuraEnabled
    public String logicOperator { get; set; }
  }

  public class Category_Wrapper {
    @AuraEnabled
    public Id categoryId { get; set; }
    @AuraEnabled
    public String categoryName { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public String icon { get; set; }
    @AuraEnabled
    public Boolean isActive { get; set; }
    @AuraEnabled
    public Integer order { get; set; }
    @AuraEnabled
    public List<Page_Wrapper> pages { get; set; }
  }

  public class FormStructure_Wrapper {
    @AuraEnabled
    public String formName { get; set; }
    @AuraEnabled
    public Id formId { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public String defaultLanguage { get; set; }
    @AuraEnabled
    public List<Page_Wrapper> pages { get; set; }
    @AuraEnabled
    public String layoutMode { get; set; }
    @AuraEnabled
    public List<Category_Wrapper> categories { get; set; }
    /** Form-wide show/hide/require rules; not duplicated on individual pages. */
    @AuraEnabled
    public List<Dependency_Wrapper> dependencies { get; set; }
  }
}

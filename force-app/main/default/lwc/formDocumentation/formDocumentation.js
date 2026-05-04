/**
 * @description       : In-app documentation page with data model reference, feature guides, and development history
 * @author            : Daniel Murracas
 * @last modified on  : 20-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * 1.1   19-03-2026   Daniel Murracas     Updated docs for all new features
 * 1.2   17-03-2026   Daniel Murracas     Updated clone, logic groups, testing steps
 * 2.0   20-03-2026   Daniel Murracas     Updated for Dynamic Record Resolution, Direction, Permission Sets, Pre-population
 * 3.0   20-03-2026   Daniel Murracas     Comprehensive documentation refresh - all objects, features, architecture decisions, known limitations
 * 3.1   25-03-2026   Tom De Backer       Cross-field validation: builder vs client runtime integration notes
 * 3.2   25-03-2026   Tom De Backer       Visual ERD & hierarchy: Category, Page→Category; 14-object count; dependency targets
 * ------------------------------------------------------------
**/
import { LightningElement } from 'lwc';

export default class FormDocumentation extends LightningElement {
    
    activeSections = ['overview'];

    get dataModelObjects() {
        return [
            {
                name: 'Form (C_Form__c)',
                icon: 'standard:document',
                description: 'The top-level container. A Form represents a complete questionnaire or assessment. It holds the status (Draft, Published, Archived), default language, and version number.',
                keyFields: 'Name, C_Description__c, C_Status__c (Draft/Published/Archived), C_Version__c, C_Default_Language__c',
                example: 'Example: "Annual Supplier Assessment 2026"'
            },
            {
                name: 'Category (C_Category__c)',
                icon: 'standard:hierarchy',
                description: 'Optional grouping for Pages within a Form (for example wizard steps or tabs). Master-Detail to Form. Dependencies may target a Category (Show/Hide/Require an entire tab group).',
                keyFields: 'Name, C_Form__c (MD), C_Order__c, C_Description__c, C_Is_Active__c, C_Icon__c',
                example: 'Example: "Onboarding — Basics" grouping several pages before "Advanced" category'
            },
            {
                name: 'Page (C_Page__c)',
                icon: 'standard:webpage',
                description: 'Forms are divided into Pages. Each Page represents one screen/step in the multi-page form wizard. Pages are Master-Detail to Form and may optionally be assigned to a Category (Lookup) for multi-tab / wizard grouping in the Visual Builder.',
                keyFields: 'Name, C_Form__c (MD), C_Category__c (Lookup to Category, optional), C_Description__c, C_Order__c',
                example: 'Example: "Page 1 - General Information", "Page 2 - Financial Details"'
            },
            {
                name: 'Section (C_Section__c)',
                icon: 'standard:record_layout',
                description: 'Each Page contains one or more Sections. Sections group related questions together and carry scoring weight. A Section can be marked as Bonus (adds extra points but does not reduce the max score) or Excluded From Weight (not counted in weighted score calculation).',
                keyFields: 'Name, C_Page__c (MD), C_Order__c, C_Weight__c, C_Bonus__c, C_Excluded_From_Weight__c',
                example: 'Example: "Environmental Compliance" with 25% weight'
            },
            {
                name: 'Question (C_Question__c)',
                icon: 'standard:question_feed',
                description: 'The core element. Each Question belongs to a Section and has a Type (Text, Long Text, Number, Date, Picklist, Multi-Select, Checkbox, File, Table). Supports placeholder text, min/max values, validation patterns, max length constraints, table column configuration, file upload limits, cloning source tracking, and cross-field validation rules (JSON on C_Cross_Field_Rules_JSON__c) authored in the Visual Builder for Date and Number questions.',
                keyFields: 'Name, C_Section__c (MD), C_Type__c (Text/Long Text/Number/Date/Picklist/Multi-Select/Checkbox/File/Table), C_Question_Text__c, C_Help_Text__c, C_Is_Required__c, C_Order__c, C_Weight__c, C_Placeholder__c, C_Max_Length__c, C_Min_Value__c, C_Max_Value__c, C_Validation_Pattern__c, C_Validation_Message__c, C_Cross_Field_Rules_JSON__c (JSON array: compare this question to another by Id), C_Table_Columns__c, C_Table_Min_Rows__c, C_Table_Max_Rows__c, C_Max_Files__c, C_Max_File_Size_MB__c, C_Accepted_File_Types__c, C_Source_Question__c, C_Search_Name__c',
                example: 'Example: "What certifications does your company hold?" (Type: Multi-Select)'
            },
            {
                name: 'Response (C_Response__c)',
                icon: 'standard:choice',
                description: 'Predefined answer options for Picklist, Multi-Select, and Checkbox questions. Each Response has a point value for scoring, belongs to exactly one Question (Master-Detail), and can optionally require free-text details or lock the parent question when selected.',
                keyFields: 'Name, C_Question__c (MD), C_Response_Text__c, C_Points__c, C_Order__c, C_Requires_Details__c, C_Locks_Question__c, C_Source_Response__c, C_Search_Name__c',
                example: 'Example: "ISO 9001" worth 10 points, "ISO 14001" worth 8 points'
            },
            {
                name: 'Dependency (C_Dependency__c)',
                icon: 'standard:flow',
                description: 'Defines conditional logic: when a specific Response is selected, Show, Hide, or Require a target Category, Page, Section, or Question. Supports logic groups and operators for complex multi-condition rules.',
                keyFields: 'Name, C_Controlling_Response__c (Lookup to Response), C_Target_Type__c (Category/Page/Section/Question), C_Action__c (Show/Hide/Require), C_Target_Category__c, C_Target_Page__c, C_Target_Section__c, C_Target_Question__c, C_Logic_Group__c, C_Logic_Operator__c',
                example: 'Example: When "Yes" is selected for "Do you export?", Show the "Export Details" section'
            },
            {
                name: 'Form Target (C_Form_Target__c)',
                icon: 'standard:targets',
                description: 'Defines a target Salesforce record for field mapping. Each Form Target specifies the object, how to resolve the record, the DML operation, and the data flow direction. Resolution types: Record_Context (caller passes ID via context key), Running_User (auto-resolve from User object field path), Related_Record (chain from another target via related field path), or New (create a new record). Direction controls whether the target is Outbound (form -> record), Inbound (record -> form pre-population), or Bidirectional (both).',
                keyFields: 'Name, C_Form__c (MD), C_Target_Object__c, C_Resolution_Type__c (Record_Context/Running_User/Related_Record/New), C_Record_Operation__c (Create/Update/Upsert), C_Direction__c (Inbound/Outbound/Bidirectional), C_Context_Key__c, C_User_Lookup_Field__c, C_Related_Target__c (Lookup to self), C_Related_Field_Path__c, C_External_Id_Field__c, C_Is_Active__c, C_Order__c, C_Description__c',
                example: 'Example: Target "Account" with Resolution "Record_Context" [key: account], Direction "Bidirectional", Operation "Update"'
            },
            {
                name: 'Field Mapping (C_Field_Mapping__c)',
                icon: 'standard:data_mapping',
                description: 'Maps a Question\'s answer to a specific field on a Form Target\'s object. Supports multiple mapping types: Field_Value (from question response), Static_Value (hardcoded constant), Table_JSON (serialized table data), and File_Attachment (file reference). Linked to a Form Target for organized writeback.',
                keyFields: 'Name, C_Form_Target__c (Lookup), C_Question__c (Lookup), C_Target_Object__c, C_Target_Field__c, C_Mapping_Type__c (Field_Value/Static_Value/Table_JSON/File_Attachment), C_Static_Value__c, C_Record_Operation__c, C_Record_Source__c, C_Is_Active__c, C_External_Id_Field__c',
                example: 'Example: Map "Company Revenue" question to Account.AnnualRevenue with type "Field_Value"'
            },
            {
                name: 'Translation (C_Translation__c)',
                icon: 'standard:translation',
                description: 'Stores translated text for any form element (Page name, Section name, Question text, Response text) in any supported language. The Translation Service loads the appropriate translations when a user fills out the form in a non-default language.',
                keyFields: 'Name, C_Language__c, C_Translated_Text__c, C_Field_Name__c, C_Page__c, C_Section__c, C_Question__c, C_Response__c',
                example: 'Example: Portuguese translation for "Company Name" = "Nome da Empresa"'
            },
            {
                name: 'Form Submission (C_Form_Submission__c)',
                icon: 'standard:task',
                description: 'Created when a user starts filling out a form. Tracks the submission status, the final calculated score, and links to Account/Contact/Lead. Stores the Record Context JSON (the keyed record context map passed at launch) for consistent outbound field mapping at submit time. Supports auto-save with Draft State JSON and draft resume.',
                keyFields: 'Name, C_Form__c (Lookup), C_Status__c, C_Language__c, C_Final_Score__c, C_Submitted_Date__c, C_Form_Version__c, C_Draft_State_JSON__c, C_Record_Context_JSON__c, C_Account__c, C_Contact__c, C_Lead__c, C_Record_Id__c, C_Is_Testing__c',
                example: 'Example: Submission by "Acme Corp" with status "Submitted" and score 87%'
            },
            {
                name: 'Section Response (C_Section_Response__c)',
                icon: 'standard:record',
                description: 'Created when a form is submitted. Captures the scored results for each Section: the weight, bonus flag, max possible points, earned points, and calculated percentage score. Belongs to a Form Submission (Master-Detail).',
                keyFields: 'C_Form_Submission__c (MD), C_Section__c, C_Section_Name__c, C_Weight__c, C_Bonus__c, C_Excluded_From_Weight__c, C_Order__c, C_Max_Points__c, C_Earned_Points__c, C_Score__c',
                example: 'Example: "Environmental Compliance" section scored 8/10 = 80%'
            },
            {
                name: 'Question Response (C_Question_Response__c)',
                icon: 'standard:answer_best',
                description: 'The individual answer record. Stores which Response was selected, the response text, details text, points earned, question weight, and table data for Table-type questions. Belongs to a Section Response (Master-Detail).',
                keyFields: 'C_Section_Response__c (MD), C_Question__c, C_Response__c, C_Question_Text__c, C_Question_Type__c, C_Response_Text__c, C_Response_Details__c, C_Response_Points__c, C_Question_Weight__c, C_Table_Data__c',
                example: 'Example: Selected "ISO 9001" earning 10 points'
            },
            {
                name: 'Form Builder Settings (Form_Builder_Settings__c)',
                icon: 'standard:settings',
                description: 'Hierarchy Custom Setting that controls feature toggles at Org, Profile, or User level. Allows admins to disable Scoring, Field Mapping, or Translations when not needed. When a feature is disabled, its UI elements are hidden from the builders and renderer. All features default to ENABLED when no custom setting record exists.',
                keyFields: 'C_Enable_Scoring__c, C_Enable_Field_Mapping__c, C_Enable_Translations__c',
                example: 'Example: Disable Scoring for a client who only uses forms for data collection, not assessment.'
            }
        ];
    }

    get featuresList() {
        return [
            { title: 'Form Builder (Visual)', description: 'Drag-and-drop, canvas-based visual form building with collapsible elements, cross-container moves, and live preview. Includes collapsible property sections (Basic, Help & Validation, Cross-field Validation for Date/Number, Scoring, File Options, Table Options, Dependencies, Field Mapping).' },
            { title: 'Cross-field validation (authoring)', description: 'Admins configure rules on the dependent question (the field that should show the error): rule type, compare-to question (same type, another question Id), and message. Rules persist as JSON in C_Cross_Field_Rules_JSON__c and are returned on the form definition as Question_Wrapper.crossFieldRules (string) from FormService. The client-side form renderer (formRenderer) must still implement evaluation, merge with native field validity, re-validate peer questions when a referenced answer changes, and block submit when invalid — see Known Limitations.' },
            { title: 'Question Types (9)', description: 'Text, Long Text, Number, Date, Picklist, Multi-Select, Checkbox, File, and Table. Each type supports relevant validation constraints (placeholder, max length, min/max value, regex pattern, table columns/rows, file limits).' },
            { title: 'Dependencies / Branching', description: 'Show, Hide, or Require actions targeting Pages, Sections, or Questions based on response selection. Supports logic groups with AND/OR operators for multi-condition rules. Inline dependency management with click-to-edit support.' },
            { title: 'Scoring', description: 'Weighted sections and questions with bonus support and Excluded From Weight flag. Per-response point values with automatic score calculation on submission. Section Response records capture earned/max points and percentage.' },
            { title: 'Translations', description: 'Multi-language support with language switcher in form renderer. Translation records for Page, Section, Question, and Response text. TranslationService loads translations at render time.' },
            { title: 'Field Mapping with Form Targets', description: 'Scalable multi-record data writeback with 4 resolution types (Record_Context, Running_User, Related_Record, New), 3 directions (Inbound, Outbound, Bidirectional), and 4 mapping types (Field_Value, Static_Value, Table_JSON, File_Attachment). Multiple target objects per form with ordered execution.' },
            { title: 'Inbound Pre-population', description: 'Read field values from resolved target records and pre-fill form fields before user interaction. Inbound and Bidirectional Form Targets automatically query mapped fields and populate corresponding questions on form load.' },
            { title: 'Dynamic Record Resolution', description: 'Keyed record context (JSON map) for Record_Context targets, user field path traversal for Running_User targets, and related record chaining via Related_Record targets with configurable Related Target and Related Field Path.' },
            { title: 'Draft / Resume', description: 'Auto-save form progress with JSON-based draft state stored in C_Draft_State_JSON__c on C_Form_Submission__c. Users can close and resume incomplete forms with all answers preserved.' },
            { title: 'Clone Form', description: 'Deep clone entire form with all structure (pages, sections, questions, responses), dependencies, translations, form targets, and field mappings. Full ID remapping to the new form.' },
            { title: 'Feature Toggles', description: 'Hierarchy Custom Setting (Form_Builder_Settings__c) to enable/disable scoring, field mapping, and translations per org/profile/user. All features default to ENABLED when no custom setting record exists — create a record and uncheck fields to disable specific features.' },
            { title: 'Permission Sets', description: 'Forms_Admin grants full CRUD + View/Modify All on all objects. Forms_User grants read-only access to form structure and create/edit own submissions with Private OWD. Designed for Experience Cloud respondents.' },
            { title: 'Experience Cloud & Flow Support', description: 'Form renderer deployable in Experience Cloud sites and Screen Flows with recordContext JSON parameter. Configure via @api properties: formId, language, hideHeader, readOnly, contextRecordId, recordContext (JSON). Backward compatible with single contextRecordId.' }
        ];
    }

    get developmentHistory() {
        return [
            {
                version: 'v1.0',
                date: '18-03-2026',
                author: 'Daniel Murracas',
                changes: 'Initial form builder with basic question types, pages, sections. Full data model with custom objects and core Apex services (FormService, FormSubmissionService, FormResponseService, CloneFormAction, ResponseWrapper). LWC form renderer with multi-page navigation and dependency engine. All 9 question types supported.'
            },
            {
                version: 'v2.0',
                date: '19-03-2026',
                author: 'Daniel Murracas',
                changes: 'Added scoring, translations, field mapping, dependency engine, drag-and-drop visual builder. Created ScoringService, TranslationService, FieldMappingService, FeatureSettingsService. Built Functional and Visual Form Builder LWCs with unified Lightning App. Created C_Form_Target__c for scalable field mapping. Added Form_Builder_Settings__c hierarchy custom setting for feature toggles. Implemented draft/resume/submit flow with auto-save. Logic group evaluation with AND/OR operators. Clone enhancement for Form Targets, Field Mappings, and Translations. Experience Cloud & read-only integration. Collapsible property panels, question-level field mapping badges, click-to-edit dependencies.'
            },
            {
                version: 'v3.0',
                date: '20-03-2026',
                author: 'Daniel Murracas',
                changes: 'Dynamic Record Resolution with keyed context, Running_User lookup, Related_Record chaining, Direction support (Inbound/Outbound/Bidirectional), Forms_User permission set. New resolution types: Record_Context with Context Key, Running_User with configurable User Lookup Field, Related_Record for target chaining via Related Target and Related Field Path. Inbound pre-population from target records. recordContext JSON API for multi-record resolution. C_Record_Context_JSON__c on Form Submission. Forms_User Permission Set for Experience Cloud respondents (read-only form structure, create/edit own submissions with Private OWD).'
            },
            {
                version: 'v4.0',
                date: '20-03-2026',
                author: 'Daniel Murracas',
                changes: 'Production hardening — 77 bug fixes across CRITICAL/HIGH/MEDIUM/LOW severity. FLS gaps in permission sets patched. Runtime crash fixes for null references and missing data. Governor limit optimization (bulkified SOQL/DML, eliminated N+1 queries). Admin permission checks on all mutating @AuraEnabled methods via FeatureUtil.isFormBuilderAdmin(). Cascade delete support. Bulkification of all Apex services. Accessibility improvements (ARIA attributes, keyboard navigation). Validation enhancements across builders and renderer.'
            },
            {
                version: 'v5.0',
                date: '20-03-2026',
                author: 'Daniel Murracas',
                changes: 'Documentation deep refresh — corrected feature toggle defaults (all features now default to ENABLED). Restructured deployment guide into 5 clear options: Experience Cloud LWC, Lightning App Page LWC, Screen Flow, Record Page Quick Action, and Invocable Clone. Added Running_User limitation note for internal users. Updated testing steps with Record Context JSON textarea instructions. Added form search/filter and LastModifiedDate to Visual Builder form list. Regression fixes: response drop zones limited to Picklist/Multi-Select/Checkbox types, feature settings defaults changed from false to true.'
            },
            {
                version: 'v5.1',
                date: '25-03-2026',
                author: 'Documentation',
                changes: 'Documented cross-field validation: Visual Builder + C_Cross_Field_Rules_JSON__c + FormService.crossFieldRules delivery. Explicit note that the client-side formRenderer must still implement rule evaluation and submit enforcement; linked to Known Limitations and Architecture (builder vs runtime puzzle pieces).'
            }
        ];
    }

    get knownLimitations() {
        return [
            { title: 'Cross-field validation — runtime not connected', description: 'The Visual Builder and metadata pipeline are complete: rules are saved on C_Question__c.C_Cross_Field_Rules_JSON__c and exposed to LWC as crossFieldRules on each question in the structure from FormService.getFormStructureWithMeta. The in-app formRenderer does not yet parse those rules, run a cross-field validation engine on answer changes, merge results with per-field validation, or enforce them on submit. A separate or future client-side runtime (or an upgraded formRenderer) must implement that behavior and stay aligned with the JSON contract (rule types, refQuestionId = Salesforce question Id). Server-side validation on submit is recommended so API tampering cannot bypass rules.' },
            { title: 'File Upload (Filename Only)', description: 'File upload captures filenames only. No actual file storage via ContentVersion is implemented — file references are stored as text, not as Salesforce file records.' },
            { title: 'Running_User Resolution for Internal Users', description: 'The Running_User resolution type resolves records via a field path on the User object (e.g. ContactId). Internal admin users typically do not have a ContactId set, so Running_User targets will not resolve for them. This works as expected for Experience Cloud users with linked Contact records.' },
            { title: 'Cascade Delete DML Limits', description: 'Large forms with hundreds of questions may approach DML row limits during cascade delete operations. Deleting a Form cascades through Pages, Sections, Questions, Responses, Dependencies, Translations, Form Targets, and Field Mappings.' }
        ];
    }

    get architectureDecisions() {
        return [
            { title: 'Controlled Elevation Pattern', description: 'Outer classes use "with sharing", inner classes use "without sharing" only for specific operations (form metadata reading, scoring calculation, field mapping writeback, translation reading). This ensures guest/community users can load and submit forms without direct object access while maintaining sharing rules for all other operations.' },
            { title: 'Permission Set Strategy', description: 'FLS/CRUD enforcement is handled via Permission Sets (Forms_Admin, Forms_User) rather than code-level Security.stripInaccessible() or WITH SECURITY_ENFORCED. All mutating @AuraEnabled methods check FeatureUtil.isFormBuilderAdmin() before executing. This provides declarative, admin-configurable access control.' },
            { title: 'Draft/Resume Lifecycle', description: 'Form progress is auto-saved as JSON in C_Draft_State_JSON__c on C_Form_Submission__c. On resume, the JSON is parsed and form state is restored client-side. On submit, response records (Section Response, Question Response) are created from the draft JSON. The draft record persists until submission or explicit deletion.' },
            { title: 'Self-Resolving Targets', description: 'Each C_Form_Target__c record defines its own resolution strategy. The system resolves records in C_Order__c sequence, allowing chained resolution (e.g., Account → Contact via Related_Record). Each target is independent and self-contained, making the architecture extensible without code changes.' },
            { title: 'Feature Defaults', description: 'All features (scoring, field mapping, translations) default to ENABLED when no Custom Setting record exists. To disable a feature, create a Form_Builder_Settings__c record at the Org, Profile, or User level and uncheck the corresponding field. This ensures all capabilities are available out-of-the-box.' },
            { title: 'Cross-field validation: builder supplies data, renderer supplies behavior', description: 'Cross-field rules are declarative metadata only until the runtime implements them. FormService loads C_Cross_Field_Rules_JSON__c into Question_Wrapper.crossFieldRules as a JSON string; the renderer (or a dedicated shell/store module) should JSON.parse per question, evaluate after each answer change, patch validity on dependent and referenced fields, and extend submit validation. Keeping rule type strings in sync between any Apex mirror and LWC avoids drift.' }
        ];
    }

    get deploymentOptions() {
        return [
            {
                title: 'Option 1: LWC on Experience Cloud',
                recommended: true,
                whenToUse: 'Best for external-facing forms (customers, partners, vendors). Supports inbound pre-population and outbound field mapping.',
                steps: '1. Open Experience Builder for your site. 2. Navigate to the page where the form should appear. 3. Drag the "formRenderer" component from the component palette onto the page. 4. In the property panel, set: Form ID (to lock to one form, or leave blank for form selector), Language, Hide Header, Read Only. 5. For inbound pre-population, set Record Context (JSON) — e.g. {"account":"001XXXX"}. 6. Publish the site.',
                properties: 'formId, language, hideHeader, readOnly, recordContext (JSON), contextRecordId'
            },
            {
                title: 'Option 2: LWC on Lightning App Page',
                recommended: false,
                whenToUse: 'For internal users who need to fill forms inside a Lightning App. Already used in the Form Builder app\'s "Form Renderer" tab.',
                steps: '1. Go to Setup → Lightning App Builder → New App Page. 2. Drag the "formRenderer" component onto the page. 3. Configure properties as needed. 4. Activate the page and add it to a Lightning App.',
                properties: 'formId, language, hideHeader, readOnly, recordContext (JSON), contextRecordId'
            },
            {
                title: 'Option 3: Screen Flow',
                recommended: false,
                whenToUse: 'When the form must be part of a larger multi-step Flow process (e.g. after user verification, approval, or data collection steps).',
                steps: '1. In Flow Builder, add a Screen element. 2. Drag the "formRenderer" component onto the screen. 3. Set input-only properties: formId (use a text variable or hardcode), language, recordContext (JSON string variable). 4. Save and activate the Flow.',
                properties: 'formId (input-only), language (input-only), hideHeader (input-only), readOnly (input-only), recordContext (input-only), contextRecordId (input-only)'
            },
            {
                title: 'Option 4: Record Page (Read-Only View)',
                recommended: false,
                whenToUse: 'To view a submitted form on a C_Form_Submission__c record page. Shows all answers in read-only mode with score and status.',
                steps: '1. The "Form Submission Record Page" Lightning Record Page is already configured. 2. It uses the formRendererAction Quick Action. 3. Click "View Form" on any Form Submission record to see the completed form.',
                properties: 'recordId (auto-set), readOnly = true'
            },
            {
                title: 'Option 5: Invocable Clone (Apex / Flow)',
                recommended: false,
                whenToUse: 'To clone an entire form programmatically from Apex code or a Flow. Deep-copies all structure, dependencies, translations, targets, and mappings.',
                steps: '1. In a Flow: use an Apex Action step with the CloneFormAction class. 2. Pass formId and newFormName as inputs. 3. The action returns the new cloned Form ID. 4. In Apex: CloneFormAction.cloneForm(formId, newFormName).',
                properties: 'formId (required), newFormName (required)'
            }
        ];
    }

    get testingSteps() {
        return [
            { number: '1', title: 'Test All 9 Question Types', description: 'Create or open a form with all question types: Text, Long Text, Number, Date, Picklist, Multi-Select, Checkbox, File, and Table. Fill out each type in the renderer and verify input behavior, placeholder text, and validation constraints.' },
            { number: '2', title: 'Test Dependencies (Show/Hide/Require)', description: 'Verify Show, Hide, and Require dependencies work with all target types (Page, Section, Question). Select controlling responses and observe targets appearing, disappearing, or becoming required. Test logic groups with AND/OR operators.' },
            { number: '3', title: 'Test Draft Auto-Save and Resume', description: 'Start a form, fill some answers, and close it. Reopen the same form — it should resume from where you left off with all answers preserved from the C_Draft_State_JSON__c field.' },
            { number: '4', title: 'Test Scoring Calculation', description: 'Open a form with weighted sections and point-valued responses. Submit and verify the Final Score is calculated correctly. Check Section Response records for earned/max points and percentage scores.' },
            { number: '5', title: 'Test Field Mapping (All Resolution Types)', description: 'Create Form Targets for each resolution type: Record_Context (with context key), Running_User (with user lookup field), Related_Record (chained from another target), and New. Verify Field Mapping records correctly write question answers to target fields on submit.' },
            { number: '6', title: 'Test Field Mapping (All Directions)', description: 'Test Outbound (form -> record on submit), Inbound (record -> form on load), and Bidirectional (pre-populate on load, write back on submit) directions. Verify data flows correctly in each direction.' },
            { number: '7', title: 'Test Inbound Pre-population', description: 'Create Inbound or Bidirectional Form Targets with Record_Context resolution. Pass a recordContext JSON map when launching the form. Verify form fields are pre-populated with existing record values before user interaction.' },
            { number: '8', title: 'Test Multi-Record Context with JSON', description: 'Create multiple Form Targets for different objects (e.g., Account and Contact) with different context keys. In the Form Renderer tab, use the "Record Context (JSON)" textarea to paste your context map (e.g. {"account":"001xxxx","contact":"003xxxx"}). Verify each target resolves to the correct record and pre-populates the form independently.' },
            { number: '9', title: 'Test Translations with Language Switcher', description: 'Create Translation records for multiple languages. Switch language in the renderer and confirm all page names, section names, question text, and response text translate correctly.' },
            { number: '10', title: 'Test Permission Sets (Admin vs User)', description: 'Assign Forms_User to a test user. Verify they can fill and submit forms but cannot edit form structure. Verify they can only see their own submissions (Private OWD). Assign Forms_Admin and verify full CRUD + View/Modify All access.' },
            { number: '11', title: 'Test Clone Form Functionality', description: 'Clone a form that has translations, dependencies, form targets, and field mappings configured. Verify all records are deep-copied with correct ID remapping: pages, sections, questions, responses, dependencies, translations, form targets, and field mappings.' }
        ];
    }

    get workflowSteps() {
        return [
            { number: '1', title: 'Create Form', description: 'Create a new Form record with name, description, status (Draft), version, and default language.' },
            { number: '2', title: 'Add Pages', description: 'Create Pages to organize the form into logical steps. Set the order for multi-page navigation.' },
            { number: '3', title: 'Add Sections', description: 'Create Sections within each Page with order. Optionally set weight and bonus for scoring.' },
            { number: '4', title: 'Add Questions', description: 'Choose from 9 question types (Text, Long Text, Number, Date, Picklist, Multi-Select, Checkbox, File, Table). Set constraints (required, placeholder, max length, min/max value, validation pattern, table columns, file limits) and weight for scoring.' },
            { number: '5', title: 'Add Responses', description: 'For Picklist, Multi-Select, and Checkbox questions, add Response options with order and optional points for scoring.' },
            { number: '6', title: 'Set Up Dependencies', description: 'Choose a controlling response, select the target type (Page/Section/Question), and set the action (Show/Hide/Require). Use logic groups for multi-condition rules.' },
            { number: '7', title: 'Set Up Translations', description: 'For each supported language, create Translation records for page names, section names, question text, and response text.' },
            { number: '8', title: 'Set Up Form Targets', description: 'Configure target objects with resolution type (Record_Context/Running_User/Related_Record/New), direction (Inbound/Outbound/Bidirectional), record operation (Create/Update/Upsert), and resolution-specific fields (context key, user lookup field, related target/field path, external ID field).' },
            { number: '9', title: 'Set Up Field Mappings', description: 'Link questions to target fields via Form Targets. Choose mapping type (Field_Value/Static_Value/Table_JSON/File_Attachment) and specify the target object and field.' },
            { number: '10', title: 'Publish Form', description: 'Set the form status to Published to make it available to end users. Deploy to Experience Cloud, Screen Flows, or Lightning pages as needed.' }
        ];
    }

    get roadmapHighEffort() {
        return [
            {
                title: 'Survey Distribution via Cases (Replace SF Surveys)',
                description: 'Link a form to a Case record, send it to the customer via email (with a unique submission link), and capture the response back on the Case in Experience Cloud. Replaces Salesforce Surveys with a fully custom, configurable alternative. Requires email template integration, unique submission tokens, guest-user form access tied to Case context, response-to-Case field mapping, and an Experience Cloud respondent page.',
                effort: 'High'
            },
            {
                title: 'Admin Review / Manual Scoring',
                description: 'After a user submits a form, an Admin can open the submission, review each answer, and manually score or grade it — separate from the existing auto-calculated scoring. Introduces a review workflow with statuses (Pending Review, In Review, Reviewed), reviewer notes per section/question, manual score overrides, and a dedicated Review UI accessible from the Form Submission record.',
                effort: 'High'
            },
            {
                title: 'Form Layout Modes (Multiple UX/UI Templates)',
                description: 'Multiple pre-built renderer layouts per form: "Classic" (single-column paginated — current default), "Conversational" (one-question-at-a-time, Typeform-style), "Card-based" (visual grouping with cards), "Wizard" (sidebar step tracker). Stored as a picklist on C_Form__c, the renderer dynamically switches its template and CSS. Admins choose the layout when creating the form.',
                effort: 'High'
            },
            {
                title: 'AI-Powered Insights',
                description: 'Sentiment analysis on open-text responses, auto-categorization of free-text answers, and smart response suggestions based on historical submission data. Leverages Einstein AI or external LLM APIs to surface patterns and trends that manual review would miss.',
                effort: 'High'
            },
            {
                title: 'Real-time Collaboration',
                description: 'Multi-user simultaneous editing in the Visual Builder with presence indicators (like Google Docs). Uses Platform Events for live synchronization of changes between connected users. Prevents conflicts with optimistic locking and change merging.',
                effort: 'High'
            },
            {
                title: 'A/B Testing',
                description: 'Create form variants (different question orders, wording, page layouts) and randomly assign respondents to each variant. Track completion rates, scores, and drop-off per variant to data-drive form design improvements.',
                effort: 'High'
            },
            {
                title: 'Offline Mode (Mobile)',
                description: 'Allow form completion on Salesforce Mobile without network connectivity. Queue submissions locally and sync automatically when back online. Critical for field workers, inspectors, and remote survey collection.',
                effort: 'High'
            },
            {
                title: 'GDPR / Compliance Module',
                description: 'Data retention policies (auto-delete submissions after X days), right-to-erasure workflow, consent tracking fields, and a full audit trail of all form structure changes (who edited what, when).',
                effort: 'High'
            }
        ];
    }

    get roadmapMediumEffort() {
        return [
            {
                title: 'Pre-populate from Previous Submission (Same Form)',
                description: 'When a user opens a form they have already submitted before, offer to pre-fill all questions with their answers from the most recent submission. Useful for recurring forms (quarterly reviews, annual assessments) where most answers stay the same. Queries C_Question_Response__c from the user\'s latest C_Form_Submission__c for the same form and maps answers by question ID.',
                effort: 'Medium'
            },
            {
                title: 'Pre-populate from Another Form\'s Submission (Cross-Form)',
                description: 'Allow a form admin to configure "pull the answer from Form X, Question Y into this Question Z." At render time, the system queries the current user\'s latest submission of the source form and maps the answer. Handles edge cases: type mismatches between source and target questions, missing source submissions, and multiple submissions (uses most recent).',
                effort: 'Medium'
            },
            {
                title: 'Built-in Analytics Dashboard',
                description: 'A dedicated analytics tab showing submission counts, completion rates, average time-to-complete, drop-off by page, response distribution charts, and score averages. All data already exists in C_Form_Submission__c and C_Question_Response__c — needs a new reporting LWC with chart visualizations.',
                effort: 'Medium'
            },
            {
                title: 'Dynamic Table Column Types',
                description: 'Allow admins to configure each table column type independently (Text, Number, Date, Picklist, Checkbox, Currency, etc.) instead of all columns being text-only. The table column builder and table renderer update to show type-specific input controls per cell.',
                effort: 'Medium'
            },
            {
                title: 'Real File Storage (ContentVersion)',
                description: 'Upload files to Salesforce ContentVersion instead of capturing filenames only. Removes the #1 known limitation. Files are linked to the Form Submission record via ContentDocumentLink, enabling download, preview, and lifecycle management.',
                effort: 'Medium'
            },
            {
                title: 'New Question Types',
                description: 'Signature capture (canvas-based), Rating / NPS (star or 0-10 scale), Slider / Range, Matrix / Likert grid, and Rich Text editor. Each fills a gap for specific use cases like HR surveys, compliance forms, and customer feedback.',
                effort: 'Medium'
            },
            {
                title: 'Theming / Branding',
                description: 'Custom colors, logo upload, and CSS overrides per form. Essential for Experience Cloud deployments where forms must match the site\'s look and feel. Stored as a JSON configuration on C_Form__c and applied dynamically by the renderer.',
                effort: 'Medium'
            },
            {
                title: 'Approval Workflows',
                description: 'Route submissions through Salesforce Approval Processes based on score, answers, or submitter profile. Built-in status transitions: Draft, Submitted, Under Review, Approved, Rejected. Integrates with standard Salesforce Approval Process infrastructure.',
                effort: 'Medium'
            },
            {
                title: 'Webhook / External API Integration',
                description: 'On-submit webhooks to external systems (Slack, Teams, Jira, external APIs). Dynamic picklist values fetched from external sources at render time. Configurable per form with retry logic and error logging.',
                effort: 'Medium'
            },
            {
                title: 'Public / Anonymous Access',
                description: 'Generate a shareable link for unauthenticated respondents (guest user profile). QR code generation for physical distribution (posters, flyers, event check-ins). Secured with unique tokens to prevent spam submissions.',
                effort: 'Medium'
            }
        ];
    }

    get roadmapLowEffort() {
        return [
            {
                title: 'Fix Naming Conventions (C_ prefix)',
                description: 'Review and standardize the C_ prefix across all custom objects and fields for consistency. Ensure all API names follow the same convention. Requires careful migration planning if any existing data or integrations reference current names.',
                effort: 'Low'
            },
            {
                title: 'PDF Export of Submissions',
                description: 'Generate a styled PDF from a completed submission for download or email attachment. Valuable for compliance, record-keeping, and sharing results with non-Salesforce users. Can leverage Visualforce PDF rendering or an external library.',
                effort: 'Low'
            },
            {
                title: 'CSV / Excel Bulk Export',
                description: 'Export all responses for a form into a downloadable spreadsheet. Essential for data analysis outside Salesforce. One-click export from the form list or submission list view.',
                effort: 'Low'
            },
            {
                title: 'Email Notifications',
                description: 'Configurable alerts on form submit, score threshold breached, or specific answer selected. Leverages Salesforce Custom Notifications, email alerts, or Platform Events. Admins configure notification rules per form.',
                effort: 'Low'
            },
            {
                title: 'Form Versioning',
                description: 'Automatic version snapshots on publish. Track version history with the ability to view previous versions and rollback. The C_Version__c field already exists but is manual — this automates versioning with a snapshot-on-publish mechanism.',
                effort: 'Low'
            },
            {
                title: 'Scheduled Availability',
                description: 'Open/close date fields on C_Form__c to control when a form accepts submissions. The renderer checks the window and shows a "not available" message outside the dates. Useful for time-bound surveys, application windows, and event registrations.',
                effort: 'Low'
            },
            {
                title: 'Submission Limits',
                description: 'Max submissions per user and/or max total submissions per form. Prevents duplicate entries and controls capacity for event registrations, applications, or limited surveys. Enforced at submit time with a clear message when the limit is reached.',
                effort: 'Low'
            },
            {
                title: 'Form Templates Library',
                description: 'Pre-built form templates (Customer Satisfaction, Employee Onboarding, Vendor Assessment, etc.) that admins can browse and clone. Accelerates adoption by providing ready-to-use starting points instead of building from scratch.',
                effort: 'Low'
            }
        ];
    }
}

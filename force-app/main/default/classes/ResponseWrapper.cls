/**
 * @description       : Wrapper classes for JSON deserialization of form responses
 * @author            : Daniel Murracas
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   18-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
public class ResponseWrapper {
    
    /**
     * @description Main wrapper containing all sections
     */
    public class MainWrapper {
        public List<ResponseSectionWrapper> sections;
    }
    
    /**
     * @description Wrapper for section-level data
     */
    public class ResponseSectionWrapper {
        public String sectionId;
        public Boolean hidden;
        public List<ResponseQuestionWrapper> questions;
    }
    
    /**
     * @description Wrapper for question-level data
     */
    public class ResponseQuestionWrapper {
        public String questionId;
        public String value;
        public String textValue;
        public Boolean hidden;
    }
}
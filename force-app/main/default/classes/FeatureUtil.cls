/**
 * @description       : Utility class for permission checks in Form Builder
 * @author            : Daniel Murracas
 * @last modified on  : 19-03-2026
 * @last modified by  : Daniel Murracas
 * Modifications Log
 * ------------------------------------------------------------
 * Ver   Date         Author              Modification
 * 1.0   19-03-2026   Daniel Murracas     Initial Version
 * ------------------------------------------------------------
**/
public with sharing class FeatureUtil {

    private static Boolean cachedIsAdmin;

    /**
     * @description When non-null during a test, {@link #isFormBuilderAdmin()} returns this value. Otherwise the real
     *     permission query runs (cache is not reused in tests when this is null).
     */
    @TestVisible
    private static Boolean testIsFormBuilderAdminOverride;

    public static Boolean isFormBuilderAdmin() {
        if (Test.isRunningTest() && testIsFormBuilderAdminOverride != null) {
            return testIsFormBuilderAdminOverride;
        }
        if (Test.isRunningTest()) {
            cachedIsAdmin = null;
        }
        if (cachedIsAdmin != null) return cachedIsAdmin;
        List<PermissionSetAssignment> assignments = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.Name = 'Forms_Admin'
            LIMIT 1
        ];
        cachedIsAdmin = !assignments.isEmpty();
        return cachedIsAdmin;
    }
}

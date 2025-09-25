public with sharing class DC_DateUtil {
    
    /**
     * Get the date filter clause based on sync days from custom metadata
     * @param stepName The step name to look up in DataSync_ObjectOrder__mdt
     * @param lastModifiedFieldName The field name for last modified date (default: 'ssot__LastModifiedDate__c')
     * @return String The WHERE clause for date filtering
     */
    public static String getDateFilterClause(String stepName, String lastModifiedFieldName) {
        if (String.isBlank(lastModifiedFieldName)) {
            lastModifiedFieldName = 'ssot__LastModifiedDate__c';
        }
        
        Integer syncDays = getSyncDaysForStep(stepName);
        
        if (syncDays == 1) {
            // For 1 day, use TODAY
            return lastModifiedFieldName + ' = TODAY';
        } else if (syncDays > 1) {
            // For multiple days, use LAST_N_DAYS
            return lastModifiedFieldName + ' = LAST_N_DAYS:' + syncDays;
        } else {
            // Default fallback to TODAY if no valid sync days found
            return lastModifiedFieldName + ' = TODAY';
        }
    }
    
    /**
     * Get the sync days value from custom metadata for a specific step
     * @param stepName The step name to look up
     * @return Integer The number of sync days (default: 1)
     */
    public static Integer getSyncDaysForStep(String stepName) {
        if (String.isBlank(stepName)) {
            return 1; // Default to 1 day
        }
        
        try {
            List<DataSync_ObjectOrder__mdt> records = [
                SELECT Sync_Data_Days__c 
                FROM DataSync_ObjectOrder__mdt 
                WHERE StepName__c = :stepName 
                AND Active__c = true 
                LIMIT 1
            ];
            
            if (!records.isEmpty() && records[0].Sync_Data_Days__c != null) {
                Integer syncDays = Integer.valueOf(records[0].Sync_Data_Days__c);
                // Ensure sync days is within valid range (1-20)
                if (syncDays >= 1 && syncDays <= 20) {
                    return syncDays;
                }
            }
        } catch (Exception e) {
            System.debug('Error retrieving sync days for step ' + stepName + ': ' + e.getMessage());
        }
        
        return 1; // Default to 1 day if not found or invalid
    }
    
    /**
     * Get formatted date filter clause for non-Data Cloud objects
     * @param stepName The step name to look up in DataSync_ObjectOrder__mdt  
     * @param lastModifiedFieldName The field name for last modified date (default: 'Last_Modified_Date__c')
     * @return String The WHERE clause for date filtering
     */
    public static String getDateFilterClauseForSeaware(String stepName, String lastModifiedFieldName) {
        if (String.isBlank(lastModifiedFieldName)) {
            lastModifiedFieldName = 'Last_Modified_Date__c';
        }
        
        return getDateFilterClause(stepName, lastModifiedFieldName);
    }
}
public with sharing class DC_DateUtil {
    
    // Mapping of Data Cloud objects to their last modified field names
    private static final Map<String, String> LAST_MODIFIED_FIELD_MAP = new Map<String, String>{
        // SSOT objects use ssot__LastModifiedDate__c
        'ssot__Account__dlm' => 'ssot__LastModifiedDate__c',
        'ssot__Individual__dlm' => 'ssot__LastModifiedDate__c',
        'ssot__Opportunity__dlm' => 'ssot__LastModifiedDate__c',
        
        // Seaware objects use Last_Modified_Date__c
        'Seaware_Commission_Structure__dlm' => 'Last_Modified_Date__c',
        'Seaware_Ship__dlm' => 'Last_Modified_Date__c',
        'Seaware_Sailing__dlm' => 'Last_Modified_Date__c',
        'Seaware_Booking__dlm' => 'Last_Modified_Date__c',
        'Seaware_Reservation__dlm' => 'Last_Modified_Date__c'
    };
    
    /**
     * Get the correct last modified field name for a given source object
     * @param sourceObject The Data Cloud object API name
     * @return String The correct last modified field name
     */
    public static String getLastModifiedFieldName(String sourceObject) {
        if (LAST_MODIFIED_FIELD_MAP.containsKey(sourceObject)) {
            return LAST_MODIFIED_FIELD_MAP.get(sourceObject);
        }
        
        // Default fallback based on object naming pattern
        if (sourceObject != null) {
            if (sourceObject.startsWith('ssot__')) {
                return 'ssot__LastModifiedDate__c';
            } else if (sourceObject.startsWith('Seaware_')) {
                return 'Last_Modified_Date__c';
            }
        }
        
        // Ultimate fallback
        return 'ssot__LastModifiedDate__c';
    }
    
    /**
     * Get the date filter clause based on sync days from custom metadata
     * @param stepName The step name to look up in DataSync_ObjectOrder__mdt
     * @param lastModifiedFieldName The field name for last modified date (optional - will auto-detect if null)
     * @return String The WHERE clause for date filtering
     */
    public static String getDateFilterClause(String stepName, String lastModifiedFieldName) {
        // Auto-detect field name if not provided
        if (String.isBlank(lastModifiedFieldName)) {
            // Try to get source object from step to auto-detect field name
            DC_IStep step = DC_StepFactory.make(stepName);
            if (step != null) {
                String sourceObject = step.sourceObjectApi();
                lastModifiedFieldName = getLastModifiedFieldName(sourceObject);
            } else {
                lastModifiedFieldName = 'ssot__LastModifiedDate__c'; // fallback
            }
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
     * Get the date filter clause with auto-detected field name based on step
     * @param stepName The step name to look up in DataSync_ObjectOrder__mdt
     * @return String The WHERE clause for date filtering
     */
    public static String getDateFilterClause(String stepName) {
        return getDateFilterClause(stepName, null);
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
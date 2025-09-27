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
        System.debug(LoggingLevel.ERROR, '=== DATE FILTER GENERATION START ===');
        System.debug(LoggingLevel.ERROR, 'Step Name: ' + stepName);
        System.debug(LoggingLevel.ERROR, 'Input lastModifiedFieldName: ' + lastModifiedFieldName);
        
        // Auto-detect field name if not provided
        if (String.isBlank(lastModifiedFieldName)) {
            // Try to get source object from step to auto-detect field name
            DC_IStep step = DC_StepFactory.make(stepName);
            if (step != null) {
                String sourceObject = step.sourceObjectApi();
                System.debug(LoggingLevel.ERROR, 'Source Object: ' + sourceObject);
                lastModifiedFieldName = getLastModifiedFieldName(sourceObject);
            } else {
                lastModifiedFieldName = 'ssot__LastModifiedDate__c'; // fallback
            }
        }
        
        System.debug(LoggingLevel.ERROR, 'Final lastModifiedFieldName: ' + lastModifiedFieldName);
        
        Integer syncDays = getSyncDaysForStep(stepName);
        System.debug(LoggingLevel.ERROR, 'Sync Days: ' + syncDays);
        
        String dateFilter = '';
        
        // **FIX: Use CDP from_iso8601_timestamp() function for timestamp fields**
        if (syncDays == 1) {
            // For 1 day, use today's date range
            DateTime todayStart = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
            DateTime tomorrowStart = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0, 0, 0, 0));
            String todayStartStr = formatDateTimeForCDP(todayStart);
            String tomorrowStartStr = formatDateTimeForCDP(tomorrowStart);
            System.debug(LoggingLevel.ERROR, 'Today start formatted: ' + todayStartStr);
            System.debug(LoggingLevel.ERROR, 'Tomorrow start formatted: ' + tomorrowStartStr);
            dateFilter = lastModifiedFieldName + ' >= from_iso8601_timestamp(\'' + todayStartStr + '\') AND ' + 
                         lastModifiedFieldName + ' < from_iso8601_timestamp(\'' + tomorrowStartStr + '\')';
        } else if (syncDays > 1) {
            // For multiple days, calculate the datetime range
            Date startDate = Date.today().addDays(-(syncDays - 1));
            Date endDate = Date.today().addDays(1); // Exclusive end date
            DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0));
            String startDateTimeStr = formatDateTimeForCDP(startDateTime);
            String endDateTimeStr = formatDateTimeForCDP(endDateTime);
            System.debug(LoggingLevel.ERROR, 'Start DateTime: ' + startDateTime + ' formatted: ' + startDateTimeStr);
            System.debug(LoggingLevel.ERROR, 'End DateTime: ' + endDateTime + ' formatted: ' + endDateTimeStr);
            dateFilter = lastModifiedFieldName + ' >= from_iso8601_timestamp(\'' + startDateTimeStr + '\') AND ' + 
                         lastModifiedFieldName + ' < from_iso8601_timestamp(\'' + endDateTimeStr + '\')';
        } else {
            // Default fallback to today if no valid sync days found
            DateTime todayStart = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
            DateTime tomorrowStart = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0, 0, 0, 0));
            String todayStartStr = formatDateTimeForCDP(todayStart);
            String tomorrowStartStr = formatDateTimeForCDP(tomorrowStart);
            System.debug(LoggingLevel.ERROR, 'Fallback - Today start formatted: ' + todayStartStr);
            System.debug(LoggingLevel.ERROR, 'Fallback - Tomorrow start formatted: ' + tomorrowStartStr);
            dateFilter = lastModifiedFieldName + ' >= from_iso8601_timestamp(\'' + todayStartStr + '\') AND ' + 
                         lastModifiedFieldName + ' < from_iso8601_timestamp(\'' + tomorrowStartStr + '\')';
        }
        
        System.debug(LoggingLevel.ERROR, 'Generated Date Filter: ' + dateFilter);
        System.debug(LoggingLevel.ERROR, '=== DATE FILTER GENERATION END ===');
        
        return dateFilter;
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
     * Format date for CDP queries in ISO format (YYYY-MM-DD)
     * @param dateValue The date to format
     * @return String The formatted date string
     */
    public static String formatDateForCDP(Date dateValue) {
        if (dateValue == null) return null;
        
        DateTime dt = DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
        return dt.formatGmt('yyyy-MM-dd');
    }
    
    /**
     * Format datetime for CDP queries in ISO format with timezone (YYYY-MM-DDTHH:mm:ss.sssZ)
     * @param dateTimeValue The datetime to format
     * @return String The formatted datetime string
     */
    public static String formatDateTimeForCDP(DateTime dateTimeValue) {
        if (dateTimeValue == null) return null;
        
        // Use ISO 8601 format with timezone indicator
        return dateTimeValue.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    }
    
    /**
     * Get formatted date filter clause for non-Data Cloud objects (backward compatibility)
     * @param stepName The step name to look up in DataSync_ObjectOrder__mdt  
     * @param lastModifiedFieldName The field name for last modified date (default: 'Last_Modified_Date__c')
     * @return String The WHERE clause for date filtering
     */
    public static String getDateFilterClauseForSeaware(String stepName, String lastModifiedFieldName) {
        if (String.isBlank(lastModifiedFieldName)) {
            lastModifiedFieldName = 'Last_Modified_Date__c';
        }
        
        // For Seaware objects, we might still want to use relative date functions if they support them
        // But for now, let's use the same format as CDP for consistency
        return getDateFilterClause(stepName, lastModifiedFieldName);
    }
}
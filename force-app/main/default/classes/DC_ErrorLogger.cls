/**
 * Centralized error logging utility for Data Cloud sync operations
 * Creates Error_Log__c records for failed DML operations
 */
public with sharing class DC_ErrorLogger {
    
    private static List<Error_Log__c> errorLogsToInsert = new List<Error_Log__c>();
    private static final Integer MAX_BATCH_SIZE = 100;
    
    /**
     * Log errors from upsert results
     * @param stepName The name of the sync step (e.g., 'Account', 'Contact')
     * @param bundle The upsert bundle containing records
     * @param results The upsert results from Database.upsert()
     * @param operationType The type of operation: 'INSERT', 'UPDATE', or 'UPSERT'
     */
    public static void logUpsertErrors(String stepName, DC_UpsertBundle bundle, 
                                       Database.UpsertResult[] results, String operationType) {
        if (results == null || results.isEmpty()) return;
        
        List<Error_Log__c> errorLogs = new List<Error_Log__c>();
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult result = results[i];
            
            if (!result.isSuccess()) {
                SObject failedRecord = bundle.records[i];
                
                // Get external ID value
                String externalIdValue = getExternalIdValue(failedRecord, bundle.externalIdField);
                
                // Get record ID if available
                String recordId = result.getId() != null ? String.valueOf(result.getId()) : null;
                
                // Create error log for each error
                for (Database.Error err : result.getErrors()) {
                    Error_Log__c errorLog = new Error_Log__c(
                        Step_Name__c = stepName,
                        Operation_Type__c = operationType,
                        External_ID__c = externalIdValue,
                        Record_ID__c = recordId,
                        Error_Message__c = err.getMessage(),
                        Error_Status_Code__c = String.valueOf(err.getStatusCode()),
                        Error_Fields__c = formatErrorFields(err.getFields()),
                        Record_Data__c = formatRecordData(failedRecord),
                        Error_Timestamp__c = DateTime.now()
                    );
                    
                    errorLogs.add(errorLog);
                    
                    // Log to system debug as well
                    System.debug(LoggingLevel.ERROR, 
                        '=== ERROR LOG CREATED ===\n' +
                        'Step: ' + stepName + '\n' +
                        'Operation: ' + operationType + '\n' +
                        'External ID: ' + externalIdValue + '\n' +
                        'Status Code: ' + err.getStatusCode() + '\n' +
                        'Message: ' + err.getMessage() + '\n' +
                        'Fields: ' + err.getFields()
                    );
                }
            }
        }
        
        if (!errorLogs.isEmpty()) {
            insertErrorLogs(errorLogs);
        }
    }
    
    /**
     * Log errors from update results
     * @param stepName The name of the sync step
     * @param records The records that were attempted to update
     * @param results The update results from Database.update()
     */
    public static void logUpdateErrors(String stepName, List<SObject> records, 
                                       Database.SaveResult[] results) {
        if (results == null || results.isEmpty()) return;
        
        List<Error_Log__c> errorLogs = new List<Error_Log__c>();
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            
            if (!result.isSuccess()) {
                SObject failedRecord = records[i];
                
                // Get record ID
                String recordId = result.getId() != null ? String.valueOf(result.getId()) : 
                                 (failedRecord.Id != null ? String.valueOf(failedRecord.Id) : null);
                
                // Create error log for each error
                for (Database.Error err : result.getErrors()) {
                    Error_Log__c errorLog = new Error_Log__c(
                        Step_Name__c = stepName,
                        Operation_Type__c = 'UPDATE',
                        Record_ID__c = recordId,
                        Error_Message__c = err.getMessage(),
                        Error_Status_Code__c = String.valueOf(err.getStatusCode()),
                        Error_Fields__c = formatErrorFields(err.getFields()),
                        Record_Data__c = formatRecordData(failedRecord),
                        Error_Timestamp__c = DateTime.now()
                    );
                    
                    errorLogs.add(errorLog);
                    
                    // Log to system debug as well
                    System.debug(LoggingLevel.ERROR, 
                        '=== ERROR LOG CREATED ===\n' +
                        'Step: ' + stepName + '\n' +
                        'Operation: UPDATE\n' +
                        'Record ID: ' + recordId + '\n' +
                        'Status Code: ' + err.getStatusCode() + '\n' +
                        'Message: ' + err.getMessage() + '\n' +
                        'Fields: ' + err.getFields()
                    );
                }
            }
        }
        
        if (!errorLogs.isEmpty()) {
            insertErrorLogs(errorLogs);
        }
    }
    
    /**
     * Log a general sync exception
     * @param stepName The name of the sync step
     * @param operationType The type of operation
     * @param ex The exception that occurred
     * @param additionalContext Any additional context information
     */
    public static void logException(String stepName, String operationType, 
                                    Exception ex, String additionalContext) {
        Error_Log__c errorLog = new Error_Log__c(
            Step_Name__c = stepName,
            Operation_Type__c = operationType,
            Error_Message__c = ex.getMessage() + '\n\nStack Trace:\n' + 
                               ex.getStackTraceString() +
                               (String.isNotBlank(additionalContext) ? '\n\nContext:\n' + additionalContext : ''),
            Error_Status_Code__c = ex.getTypeName(),
            Error_Timestamp__c = DateTime.now()
        );
        
        insertErrorLogs(new List<Error_Log__c>{ errorLog });
        
        // Log to system debug as well
        System.debug(LoggingLevel.ERROR, 
            '=== EXCEPTION LOG CREATED ===\n' +
            'Step: ' + stepName + '\n' +
            'Operation: ' + operationType + '\n' +
            'Exception Type: ' + ex.getTypeName() + '\n' +
            'Message: ' + ex.getMessage() + '\n' +
            'Stack Trace: ' + ex.getStackTraceString() +
            (String.isNotBlank(additionalContext) ? '\nContext: ' + additionalContext : '')
        );
    }
    
    /**
     * Insert error logs in batches to avoid governor limits
     */
    private static void insertErrorLogs(List<Error_Log__c> errorLogs) {
        if (errorLogs == null || errorLogs.isEmpty()) return;
        
        // Add to buffer
        errorLogsToInsert.addAll(errorLogs);
        
        // Insert in batches
        if (errorLogsToInsert.size() >= MAX_BATCH_SIZE) {
            flushErrorLogs();
        }
    }
    
    /**
     * Flush any pending error logs to the database
     * This should be called at the end of each sync step
     */
    public static void flushErrorLogs() {
        if (errorLogsToInsert.isEmpty()) return;
        
        try {
            // Use allOrNone = false to ensure other logs are saved even if one fails
            Database.SaveResult[] results = Database.insert(errorLogsToInsert, false);
            
            Integer successCount = 0;
            Integer failureCount = 0;
            
            for (Database.SaveResult result : results) {
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    failureCount++;
                    // If we can't log the error log, at least debug it
                    System.debug(LoggingLevel.ERROR, 'Failed to insert error log: ' + result.getErrors());
                }
            }
            
            System.debug(LoggingLevel.WARN, 
                'Error logs inserted: ' + successCount + ' success, ' + failureCount + ' failed');
            
        } catch (Exception e) {
            // Last resort - log to system debug if we can't save to database
            System.debug(LoggingLevel.ERROR, 'Critical: Unable to save error logs - ' + e.getMessage());
        } finally {
            // Clear the buffer
            errorLogsToInsert.clear();
        }
    }
    
    /**
     * Get external ID value from a record
     */
    private static String getExternalIdValue(SObject record, String externalIdField) {
        try {
            Object value = record.get(externalIdField);
            return value != null ? String.valueOf(value) : null;
        } catch (Exception e) {
            return null;
        }
    }
    
    /**
     * Format error fields as a readable string
     */
    private static String formatErrorFields(List<String> fields) {
        if (fields == null || fields.isEmpty()) return null;
        return String.join(fields, ', ');
    }
    
    /**
     * Format record data as JSON for storage
     * Includes all populated fields
     */
    private static String formatRecordData(SObject record) {
        if (record == null) return null;
        
        try {
            Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();
            
            // Create a simplified map for JSON serialization
            Map<String, Object> recordData = new Map<String, Object>();
            recordData.put('SObjectType', String.valueOf(record.getSObjectType()));
            recordData.put('Fields', populatedFields);
            
            String jsonData = JSON.serializePretty(recordData);
            
            // Truncate if too large (max 131,072 characters)
            if (jsonData.length() > 131000) {
                jsonData = jsonData.substring(0, 131000) + '\n... [TRUNCATED]';
            }
            
            return jsonData;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Unable to format record data: ' + e.getMessage());
            return 'Unable to serialize record data: ' + e.getMessage();
        }
    }
    
    /**
     * Get statistics about current error log buffer
     */
    public static Map<String, Integer> getBufferStats() {
        return new Map<String, Integer>{
            'bufferedCount' => errorLogsToInsert.size(),
            'bufferCapacity' => MAX_BATCH_SIZE
        };
    }
}
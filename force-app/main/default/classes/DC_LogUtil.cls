public with sharing class DC_LogUtil {
    
    /**
     * Enhanced logging that shows external ID, Salesforce ID, and all fields being updated
     */
    public static void logResults(DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        if (bundle == null || bundle.records == null || results == null) return;
        
        Integer successCount = 0;
        Integer failureCount = 0;
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult r = results[i];
            SObject rec = bundle.records[i];
            
            // Get external ID value
            String extVal = '';
            try { 
                extVal = String.valueOf(rec.get(bundle.externalIdField)); 
            } catch (Exception e) {
                extVal = '[Unable to read ext ID]';
            }
            
            if (r.isSuccess()) {
                successCount++;
                
                // Log success with details
                System.debug(LoggingLevel.INFO, '====================================');
                System.debug(LoggingLevel.INFO, '[UPSERT SUCCESS]');
                System.debug(LoggingLevel.INFO, 'External ID Field: ' + bundle.externalIdField);
                System.debug(LoggingLevel.INFO, 'External ID Value: ' + extVal);
                System.debug(LoggingLevel.INFO, 'Salesforce Record ID: ' + r.getId());
                System.debug(LoggingLevel.INFO, 'Operation: ' + (r.isCreated() ? 'INSERT' : 'UPDATE'));
                
                // Log all populated fields and their values
                logRecordFields(rec);
                
                System.debug(LoggingLevel.INFO, '====================================');
                
            } else {
                failureCount++;
                
                // Log failure with details
                System.debug(LoggingLevel.ERROR, '====================================');
                System.debug(LoggingLevel.ERROR, '[UPSERT FAILURE]');
                System.debug(LoggingLevel.ERROR, 'External ID Field: ' + bundle.externalIdField);
                System.debug(LoggingLevel.ERROR, 'External ID Value: ' + extVal);
                
                // Log all error messages
                for (Database.Error e : r.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Error Status: ' + e.getStatusCode());
                    System.debug(LoggingLevel.ERROR, 'Error Message: ' + e.getMessage());
                    System.debug(LoggingLevel.ERROR, 'Error Fields: ' + e.getFields());
                }
                
                // Log the record that failed so we can see what data caused the issue
                logRecordFields(rec);
                
                System.debug(LoggingLevel.ERROR, '====================================');
            }
        }
        
        // Summary
        System.debug(LoggingLevel.WARN, '====================================');
        System.debug(LoggingLevel.WARN, 'UPSERT SUMMARY');
        System.debug(LoggingLevel.WARN, 'Total Records: ' + results.size());
        System.debug(LoggingLevel.WARN, 'Successful: ' + successCount);
        System.debug(LoggingLevel.WARN, 'Failed: ' + failureCount);
        System.debug(LoggingLevel.WARN, 'Success Rate: ' + 
            (results.size() > 0 ? ((Decimal)successCount / results.size() * 100).setScale(2) + '%' : '0%'));
        System.debug(LoggingLevel.WARN, '====================================');
    }
    
    /**
     * Log all populated fields in a record with their values
     */
    private static void logRecordFields(SObject rec) {
        if (rec == null) return;
        
        try {
            Map<String, Object> populatedFields = rec.getPopulatedFieldsAsMap();
            
            System.debug(LoggingLevel.INFO, 'Record Type: ' + rec.getSObjectType());
            System.debug(LoggingLevel.INFO, 'Populated Fields Count: ' + populatedFields.size());
            System.debug(LoggingLevel.INFO, '--- Field Values ---');
            
            // Sort field names for easier reading
            List<String> fieldNames = new List<String>(populatedFields.keySet());
            fieldNames.sort();
            
            for (String fieldName : fieldNames) {
                Object fieldValue = populatedFields.get(fieldName);
                String displayValue = formatFieldValue(fieldValue);
                
                // Highlight external IDs and lookup fields
                if (fieldName.contains('__c') && fieldName.endsWith('ID__c')) {
                    System.debug(LoggingLevel.INFO, '  [EXT ID] ' + fieldName + ' = ' + displayValue);
                } else if (fieldValue instanceof Id) {
                    System.debug(LoggingLevel.INFO, '  [LOOKUP] ' + fieldName + ' = ' + displayValue);
                } else {
                    System.debug(LoggingLevel.INFO, '  ' + fieldName + ' = ' + displayValue);
                }
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not log record fields: ' + e.getMessage());
        }
    }
    
    /**
     * Format field values for readable logging
     */
    private static String formatFieldValue(Object value) {
        if (value == null) {
            return '[NULL]';
        }
        
        if (value instanceof String) {
            String strValue = (String)value;
            if (String.isBlank(strValue)) {
                return '[EMPTY STRING]';
            }
            // Truncate very long strings
            if (strValue.length() > 100) {
                return strValue.substring(0, 97) + '...';
            }
            return strValue;
        }
        
        if (value instanceof Date) {
            return String.valueOf((Date)value);
        }
        
        if (value instanceof DateTime) {
            return ((DateTime)value).format('yyyy-MM-dd HH:mm:ss');
        }
        
        if (value instanceof Decimal) {
            return ((Decimal)value).toPlainString();
        }
        
        if (value instanceof Boolean) {
            return String.valueOf((Boolean)value);
        }
        
        // Default to string conversion
        return String.valueOf(value);
    }
    
    /**
     * Compact version for less verbose logging
     */
    public static void logResultsCompact(DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        if (bundle == null || bundle.records == null || results == null) return;
        
        Integer successCount = 0;
        Integer failureCount = 0;
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult r = results[i];
            SObject rec = bundle.records[i];
            
            String extVal = '';
            try { extVal = String.valueOf(rec.get(bundle.externalIdField)); } catch (Exception e) {}
            
            if (r.isSuccess()) {
                successCount++;
                System.debug(LoggingLevel.INFO, 
                    '[OK] ' + (r.isCreated() ? 'INSERT' : 'UPDATE') + ' | ' +
                    'ExtID: ' + extVal + ' | ' +
                    'RecordID: ' + r.getId());
            } else {
                failureCount++;
                String errors = '';
                for (Database.Error e : r.getErrors()) {
                    errors += e.getMessage() + '; ';
                }
                System.debug(LoggingLevel.ERROR, 
                    '[FAIL] ExtID: ' + extVal + ' | ' +
                    'Errors: ' + errors);
            }
        }
        
        System.debug(LoggingLevel.WARN, 
            'Summary: ' + successCount + ' success, ' + failureCount + ' failed, ' +
            'Total: ' + results.size());
    }
}
public abstract with sharing class DC_BaseStep implements DC_IStep {
    
    // Default implementation for single-source steps
    public virtual Map<String, DC_JoinConfig> getAdditionalSources() {
        return new Map<String, DC_JoinConfig>();
    }
    
    // Default implementation calls mapScope for backward compatibility
    public virtual DC_UpsertBundle mapMultiSourceScope(DC_MultiSourceData data) {
        return mapScope(data.mainRecords);
    }
    
    // Abstract methods that must be implemented by concrete classes
    public abstract String sourceObjectApi();
    public abstract String orderBySourceField();
    public abstract Set<String> sourceFields();
    public abstract DC_UpsertBundle mapScope(List<SObject> scope);
    public abstract void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results);
    
    // Helper method to get first record from additional source
    protected SObject getFirstAdditionalRecord(DC_MultiSourceData data, String sourceAlias, String keyValue) {
        List<SObject> records = data.getAdditionalData(sourceAlias, keyValue);
        return records.isEmpty() ? null : records[0];
    }
    
    // Helper method to get all records from additional source
    protected List<SObject> getAllAdditionalRecords(DC_MultiSourceData data, String sourceAlias, String keyValue) {
        return data.getAdditionalData(sourceAlias, keyValue);
    }
    
    // **UPDATED: Helper method to safely get field value from SObject (works with CDP query results)**
    protected Object getFieldValue(SObject record, String fieldName) {
        try {
            // Check if this SObject has CDP data associated with it
            if (DC_CdpQueryUtil.hasCdpData(record)) {
                Map<String, Object> cdpData = DC_CdpQueryUtil.getCdpData(record);
                if (cdpData != null && cdpData.containsKey(fieldName)) {
                    return cdpData.get(fieldName);
                }
            }
            
            // Try regular SObject field access as fallback
            return record.get(fieldName);
        } catch (Exception e) {
            // For other edge cases, try alternative access
            try {
                Map<String, Object> recordMap = record.getPopulatedFieldsAsMap();
                if (recordMap != null && recordMap.containsKey(fieldName)) {
                    return recordMap.get(fieldName);
                }
            } catch (Exception e2) {
                // Last resort: log and return null
                System.debug('Could not get field ' + fieldName + ' from record: ' + e2.getMessage());
            }
            return null;
        }
    }
    
    // Helper method to safely set field value on SObject
    protected void setFieldValue(SObject record, String fieldName, Object value) {
        try {
            if (value != null) {
                record.put(fieldName, value);
            }
        } catch (Exception e) {
            System.debug('Could not set field ' + fieldName + ' on ' + record.getSObjectType() + ': ' + e.getMessage());
        }
    }
    
    // Helper method to determine if this step queries Data Cloud objects
    protected Boolean isDataCloudStep() {
        String sourceObject = sourceObjectApi();
        return sourceObject != null && (sourceObject.contains('__dlm') || sourceObject.startsWith('ssot__'));
    }
    
    // Helper method to get RecordType ID by name - CORRECT SIGNATURE
    protected Id getRecordTypeId(Schema.SObjectType sObjectType, String recordTypeName) {
        try {
            return sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        } catch (Exception e) {
            System.debug('RecordType not found: ' + recordTypeName + ' for ' + sObjectType);
            return null;
        }
    }
    
    // Helper method for bulk lookup resolution
    protected Map<String, Id> bulkLookupByExternalId(String objectName, String externalIdField, Set<String> externalIds) {
        Map<String, Id> resultMap = new Map<String, Id>();
        
        if (externalIds.isEmpty()) {
            return resultMap;
        }
        
        try {
            String query = 'SELECT Id, ' + externalIdField + ' FROM ' + objectName + 
                          ' WHERE ' + externalIdField + ' IN :externalIds';
            
            List<SObject> records = Database.query(query);
            
            for (SObject record : records) {
                String extId = (String) record.get(externalIdField);
                if (!String.isBlank(extId)) {
                    resultMap.put(extId, record.Id);
                }
            }
        } catch (Exception e) {
            System.debug('Error in bulk lookup for ' + objectName + ': ' + e.getMessage());
        }
        
        return resultMap;
    }
    
    // Helper method for date conversion from CDP query results
    protected Date convertToDate(Object value) {
        if (value == null) return null;
        
        if (value instanceof Date) {
            return (Date) value;
        } else if (value instanceof DateTime) {
            return ((DateTime) value).date();
        } else if (value instanceof String) {
            try {
                String dateStr = (String) value;
                // Handle various date formats that might come from CDP
                if (dateStr.contains('T')) {
                    // ISO format with time
                    return DateTime.valueOf(dateStr.replace('T', ' ').substring(0, 19)).date();
                } else {
                    // Simple date format
                    return Date.valueOf(dateStr);
                }
            } catch (Exception e) {
                System.debug('Could not convert string to date: ' + value);
                return null;
            }
        }
        
        return null;
    }
    
    // Helper method to format date for CDP queries
    protected String formatDateForCDP(Date dateValue) {
        if (dateValue == null) return null;
        
        DateTime dt = DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
        return dt.formatGmt('yyyy-MM-dd');
    }
    
    // Helper method for datetime conversion from CDP query results
    protected DateTime convertToDateTime(Object value) {
        if (value == null) return null;
        
        if (value instanceof DateTime) {
            return (DateTime) value;
        } else if (value instanceof Date) {
            return DateTime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0));
        } else if (value instanceof String) {
            try {
                String dateTimeStr = (String) value;
                // Handle various datetime formats that might come from CDP
                if (dateTimeStr.contains('T')) {
                    // ISO format
                    return DateTime.valueOf(dateTimeStr.replace('T', ' ').substring(0, 19));
                } else {
                    // Try standard format
                    return DateTime.valueOf(dateTimeStr);
                }
            } catch (Exception e) {
                System.debug('Could not convert string to datetime: ' + value);
                return null;
            }
        }
        
        return null;
    }
    
    // Helper method for decimal conversion from CDP query results
    protected Decimal convertToDecimal(Object value) {
        if (value == null) return null;
        
        if (value instanceof Decimal) {
            return (Decimal) value;
        } else if (value instanceof Integer) {
            return Decimal.valueOf((Integer) value);
        } else if (value instanceof String) {
            try {
                return Decimal.valueOf((String) value);
            } catch (Exception e) {
                System.debug('Could not convert string to decimal: ' + value);
                return null;
            }
        }
        
        return null;
    }
    
    // Helper method for boolean conversion from CDP query results
    protected Boolean convertToBoolean(Object value) {
        if (value == null) return null;
        
        if (value instanceof Boolean) {
            return (Boolean) value;
        } else if (value instanceof String) {
            String strValue = ((String) value).toLowerCase();
            if (strValue == 'true' || strValue == '1' || strValue == 'yes') return true;
            if (strValue == 'false' || strValue == '0' || strValue == 'no') return false;
        } else if (value instanceof Integer) {
            return ((Integer) value) != 0;
        } else if (value instanceof Decimal) {
            return ((Decimal) value) != 0;
        }
        
        return null;
    }
}
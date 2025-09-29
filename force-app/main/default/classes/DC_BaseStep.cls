public abstract with sharing class DC_BaseStep implements DC_IStep {
    
    public virtual Map<String, DC_JoinConfig> getAdditionalSources() {
        return new Map<String, DC_JoinConfig>();
    }
    
    public virtual DC_UpsertBundle mapMultiSourceScope(DC_MultiSourceData data) {
        return mapScope(data.mainRecords);
    }
    
    // Abstract methods - CHANGED signatures
    public abstract String sourceObjectApi();
    public abstract String orderBySourceField();
    public abstract Set<String> sourceFields();
    public abstract DC_UpsertBundle mapScope(Object scope);
    public abstract void afterUpsert(Object scope, DC_UpsertBundle bundle, Database.UpsertResult[] results);
    
    protected SObject getFirstAdditionalRecord(DC_MultiSourceData data, String sourceAlias, String keyValue) {
        List<SObject> records = data.getAdditionalData(sourceAlias, keyValue);
        return records.isEmpty() ? null : records[0];
    }
    
    protected List<SObject> getAllAdditionalRecords(DC_MultiSourceData data, String sourceAlias, String keyValue) {
        return data.getAdditionalData(sourceAlias, keyValue);
    }
    
    protected Object getFieldValue(Object record, String fieldName) {
        if (record == null || String.isBlank(fieldName)) {
            return null;
        }
        
        try {
            if (record instanceof Map<String, Object>) {
                Map<String, Object> mapRecord = (Map<String, Object>) record;
                return mapRecord.get(fieldName);
            }
            
            if (record instanceof SObject) {
                SObject sobjectRecord = (SObject) record;
                return sobjectRecord.get(fieldName);
            }
            
            System.debug(LoggingLevel.WARN, 'Unknown record type: ' + record);
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Could not get field ' + fieldName + ': ' + e.getMessage());
            return null;
        }
    }
    
    protected void setFieldValue(SObject record, String fieldName, Object value) {
        try {
            if (value != null) {
                record.put(fieldName, value);
            }
        } catch (Exception e) {
            System.debug('Could not set field ' + fieldName + ': ' + e.getMessage());
        }
    }
    
    protected Boolean isDataCloudStep() {
        String sourceObject = sourceObjectApi();
        return sourceObject != null && (sourceObject.contains('__dlm') || sourceObject.startsWith('ssot__'));
    }
    
    protected Id getRecordTypeId(Schema.SObjectType sObjectType, String recordTypeName) {
        try {
            return sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        } catch (Exception e) {
            System.debug('RecordType not found: ' + recordTypeName);
            return null;
        }
    }
    
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
            System.debug('Error in bulk lookup: ' + e.getMessage());
        }
        
        return resultMap;
    }
    
    protected Date convertToDate(Object value) {
        if (value == null) return null;
        
        if (value instanceof Date) {
            return (Date) value;
        } else if (value instanceof DateTime) {
            return ((DateTime) value).date();
        } else if (value instanceof String) {
            try {
                String dateStr = (String) value;
                if (dateStr.contains('T')) {
                    return DateTime.valueOf(dateStr.replace('T', ' ').substring(0, 19)).date();
                } else {
                    return Date.valueOf(dateStr);
                }
            } catch (Exception e) {
                System.debug('Could not convert to date: ' + value);
                return null;
            }
        }
        
        return null;
    }
    
    protected String formatDateForCDP(Date dateValue) {
        if (dateValue == null) return null;
        
        DateTime dt = DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
        return dt.formatGmt('yyyy-MM-dd');
    }
    
    protected DateTime convertToDateTime(Object value) {
        if (value == null) return null;
        
        if (value instanceof DateTime) {
            return (DateTime) value;
        } else if (value instanceof Date) {
            return DateTime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0));
        } else if (value instanceof String) {
            try {
                String dateTimeStr = (String) value;
                if (dateTimeStr.contains('T')) {
                    return DateTime.valueOf(dateTimeStr.replace('T', ' ').substring(0, 19));
                } else {
                    return DateTime.valueOf(dateTimeStr);
                }
            } catch (Exception e) {
                System.debug('Could not convert to datetime: ' + value);
                return null;
            }
        }
        
        return null;
    }
    
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
                System.debug('Could not convert to decimal: ' + value);
                return null;
            }
        }
        
        return null;
    }
    
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
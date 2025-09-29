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
    
    /**
     * UPDATED: Set field value with automatic type conversion
     * Uses DC_TypeConverter for proper type handling
     */
    protected void setFieldValue(SObject record, String fieldName, Object value) {
        if (value == null) return;
        
        // Use centralized type converter
        DC_TypeConverter.setFieldWithConversion(record, fieldName, value);
    }
    
    /**
     * NEW: Apply field mapping with automatic type conversion
     * This is the recommended way to map fields from Data Cloud to Salesforce
     */
    protected void applyFieldMapping(SObject targetRecord, Object sourceRecord, DC_FieldMap mapping) {
        Object value = getFieldValue(sourceRecord, mapping.src);
        if (value != null) {
            setFieldValue(targetRecord, mapping.tgt, value);
        }
    }
    
    /**
     * NEW: Apply multiple field mappings at once
     */
    protected void applyFieldMappings(SObject targetRecord, Object sourceRecord, List<DC_FieldMap> mappings) {
        for (DC_FieldMap mapping : mappings) {
            applyFieldMapping(targetRecord, sourceRecord, mapping);
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
    
    // DEPRECATED: Use DC_TypeConverter.convertToDate() instead
    protected Date convertToDate(Object value) {
        return DC_TypeConverter.convertToDate(value);
    }
    
    protected String formatDateForCDP(Date dateValue) {
        if (dateValue == null) return null;
        
        DateTime dt = DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
        return dt.formatGmt('yyyy-MM-dd');
    }
    
    // DEPRECATED: Use DC_TypeConverter.convertToDateTime() instead
    protected DateTime convertToDateTime(Object value) {
        return DC_TypeConverter.convertToDateTime(value);
    }
    
    // DEPRECATED: Use DC_TypeConverter.convertToDecimal() instead
    protected Decimal convertToDecimal(Object value) {
        return DC_TypeConverter.convertToDecimal(value);
    }
    
    // DEPRECATED: Use DC_TypeConverter.convertToBoolean() instead
    protected Boolean convertToBoolean(Object value) {
        return DC_TypeConverter.convertToBoolean(value);
    }
}
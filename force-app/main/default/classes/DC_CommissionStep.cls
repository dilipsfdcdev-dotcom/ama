public with sharing class DC_CommissionStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT   = 'Seaware_Commission_Structure__dlm';
    private static final String ORDER_BY_SRC = 'Agency_ID__c';
    private static final String COMMISSION_EXTID = 'AgencyID__c';
    private static final String TGT_OBJECT   = 'Commission_Structure__c';
    private static final String STEP_NAME = 'Commission';

    public override String sourceObjectApi()    { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        return DC_DateUtil.getDateFilterClause(STEP_NAME);
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.COMMISSION_MAP) f.add(m.src);
        f.add(ORDER_BY_SRC);
        return f;
    }

    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        
        System.debug(LoggingLevel.WARN, '=== COMMISSION STEP START ===');
        System.debug(LoggingLevel.WARN, 'Input scope size: ' + scope.size());
        
        // Deduplicate by external ID
        Map<String, Object> deduplicatedRecords = new Map<String, Object>();
        Map<String, DateTime> latestTimestamp = new Map<String, DateTime>();
        
        for (Object srcObj : scope) {
            String agencyId = (String) getFieldValue(srcObj, ORDER_BY_SRC);
            if (String.isBlank(agencyId)) {
                System.debug(LoggingLevel.WARN, 'Skipping record with blank agency ID');
                continue;
            }

            DateTime lastModified = convertToDateTime(getFieldValue(srcObj, 'Last_Modified_Date__c'));
            if (lastModified == null) lastModified = DateTime.now();

            if (!deduplicatedRecords.containsKey(agencyId) || 
                lastModified > latestTimestamp.get(agencyId)) {
                deduplicatedRecords.put(agencyId, srcObj);
                latestTimestamp.put(agencyId, lastModified);
            }
        }

        Integer duplicatesRemoved = scope.size() - deduplicatedRecords.size();
        if (duplicatesRemoved > 0) {
            System.debug(LoggingLevel.WARN, 'Removed ' + duplicatesRemoved + ' duplicate records');
        }

        List<SObject> out = new List<SObject>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        
        for (String agencyId : deduplicatedRecords.keySet()) {
            Object srcObj = deduplicatedRecords.get(agencyId);
            
            SObject rec = t.newSObject();
            
            // Set external ID FIRST
            rec.put(COMMISSION_EXTID, agencyId);
            
            // Apply other field mappings with proper type conversion
            for (DC_FieldMap m : DC_Mappings.COMMISSION_MAP) {
                if (m.tgt == COMMISSION_EXTID) continue;
                
                Object value = getFieldValue(srcObj, m.src);
                if (value != null) {
                    // Convert value to appropriate type based on target field
                    Object convertedValue = convertToTargetFieldType(rec, m.tgt, value);
                    if (convertedValue != null) {
                        setFieldValue(rec, m.tgt, convertedValue);
                    }
                }
            }
            out.add(rec);
        }
        
        System.debug(LoggingLevel.WARN, 'Final output size: ' + out.size());
        System.debug(LoggingLevel.WARN, '=== COMMISSION STEP END ===');
        
        return new DC_UpsertBundle(out, COMMISSION_EXTID);
    }

    /**
     * Convert value to the appropriate type for the target field
     */
private Object convertToTargetFieldType(SObject targetRecord, String fieldName, Object value) {
    if (value == null) return null;
    
    try {
        // Get the field type from schema
        Schema.SObjectType objType = targetRecord.getSObjectType();
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        
        Schema.SObjectField field = fieldMap.get(fieldName);
        if (field == null) {
            System.debug(LoggingLevel.WARN, 'Field not found: ' + fieldName);
            return value;
        }
        
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        Schema.DisplayType fieldType = fieldDescribe.getType();
        
        // Convert based on target field type
        if (fieldType == Schema.DisplayType.DATE) {
            return convertToDate(value);
        } 
        else if (fieldType == Schema.DisplayType.DATETIME) {
            return convertToDateTime(value);
        }
        else if (fieldType == Schema.DisplayType.CURRENCY || 
                 fieldType == Schema.DisplayType.PERCENT ||
                 fieldType == Schema.DisplayType.DOUBLE) {
            return convertToDecimal(value);
        }
        else if (fieldType == Schema.DisplayType.INTEGER) {
            Decimal decVal = convertToDecimal(value);
            return decVal != null ? decVal.intValue() : null;
        }
        else if (fieldType == Schema.DisplayType.BOOLEAN) {
            return convertToBoolean(value);
        }
        else if (fieldType == Schema.DisplayType.STRING || 
                 fieldType == Schema.DisplayType.TEXTAREA ||
                 fieldType == Schema.DisplayType.PICKLIST) {
            return String.valueOf(value);
        }
        else {
            // For other types, return as-is
            return value;
        }
        
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error converting field ' + fieldName + ': ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Value: ' + value + ', Type: ' + String.valueOf(value));
        return null;
    }
}

    public override void afterUpsert(Object scopeObj, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
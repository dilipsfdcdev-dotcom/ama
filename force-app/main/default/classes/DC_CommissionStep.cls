public with sharing class DC_CommissionStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT   = 'Seaware_Commission_Structure__dlm';
    private static final String ORDER_BY_SRC = 'Agency_ID__c';
    private static final String COMMISSION_EXTID = 'AgencyID__c';
    private static final String TGT_OBJECT   = 'Commission_Structure__c';
    private static final String STEP_NAME = 'Commission';

    public override String sourceObjectApi()    { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }


        public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME);
        String dataSourceObjectId = DC_DateUtil.getDataSourceObjectId(STEP_NAME);
        
        if (String.isBlank(dataSourceObjectId)) {
            System.debug(LoggingLevel.ERROR, 'DataSourceObjectId not found for step: ' + STEP_NAME);
            return dateFilter;
        }
        
        return 'DataSourceObject__c = \'' + dataSourceObjectId + '\' AND ' + dateFilter;
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

        // Bulk resolve Account by external ID for master-detail relationship
        Set<String> accountKeys = new Set<String>();
        for (String agencyId : deduplicatedRecords.keySet()) {
            Object srcObj = deduplicatedRecords.get(agencyId);
            String accountExtId = (String) getFieldValue(srcObj, 'Agency_ID__c');
            if (!String.isBlank(accountExtId)) {
                accountKeys.add(accountExtId);
            }
        }
        
        System.debug(LoggingLevel.WARN, 'Looking up ' + accountKeys.size() + ' accounts by SEAWARE_Agency_ID__c');
        Map<String, Id> accountByExt = bulkLookupByExternalId('Account', 'SEAWARE_Agency_ID__c', accountKeys);
        System.debug(LoggingLevel.WARN, 'Found ' + accountByExt.size() + ' matching accounts');

        List<SObject> out = new List<SObject>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        
        for (String agencyId : deduplicatedRecords.keySet()) {
            Object srcObj = deduplicatedRecords.get(agencyId);
            
            SObject rec = t.newSObject();
            
            // Set external ID FIRST
            rec.put(COMMISSION_EXTID, agencyId);
            
            // Resolve and set the Account master-detail relationship BEFORE other fields
            String accountExtId = (String) getFieldValue(srcObj, 'Agency_ID__c');
            if (!String.isBlank(accountExtId)) {
                Id accountId = accountByExt.get(accountExtId);
                if (accountId != null) {
                    rec.put('Agency_Name__c', accountId);
                    System.debug(LoggingLevel.INFO, 'Set Agency_Name__c to Account Id: ' + accountId);
                } else {
                    System.debug(LoggingLevel.ERROR, 'SKIPPING: No Account found with SEAWARE_Agency_ID__c = ' + accountExtId);
                    continue;
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'SKIPPING: No Agency_ID__c found for commission AgencyID: ' + agencyId);
                continue;
            }
            
            // UPDATED: Apply other field mappings - setFieldValue now handles type conversion!
            for (DC_FieldMap m : DC_Mappings.COMMISSION_MAP) {
                // Skip external ID and master-detail field as they're already set
                if (m.tgt == COMMISSION_EXTID || m.tgt == 'Agency_Name__c') continue;
                
                Object value = getFieldValue(srcObj, m.src);
                if (value != null) {
                    // setFieldValue now automatically handles type conversion!
                    setFieldValue(rec, m.tgt, value);
                }
            }
            out.add(rec);
        }
        
        System.debug(LoggingLevel.WARN, 'Final output size: ' + out.size());
        System.debug(LoggingLevel.WARN, '=== COMMISSION STEP END ===');
        
        return new DC_UpsertBundle(out, COMMISSION_EXTID);
    }

    public override void afterUpsert(Object scopeObj, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
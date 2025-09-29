public with sharing class DC_AccountStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT   = 'ssot__Account__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String ACCOUNT_EXTID = 'SEAWARE_Agency_ID__c';
    private static final String STEP_NAME = 'Account';
    private static final Set<String> ACCOUNT_LOOKUPS = new Set<String>{ 'Host_Account__c' };

    public override String sourceObjectApi()    { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME, 'ssot__LastModifiedDate__c');
        return 'ssot__DataSourceObjectId__c = \'Seaware_Account_E1C509FE\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) f.add(m.src);
        f.add(ORDER_BY_SRC);
        f.add('Parent_ID__c');
        f.add('ssot__LastModifiedDate__c');
        return f;
    }

    // CHANGED: Accept Object instead of List<SObject>
    public override DC_UpsertBundle mapScope(Object scopeObj) {
        System.debug(LoggingLevel.WARN, '=== ACCOUNT STEP START ===');
        
        // Convert Object to List<Object>
        List<Object> scope = (List<Object>)scopeObj;
        System.debug(LoggingLevel.WARN, 'Input scope size: ' + scope.size());
        
        // Deduplicate by external ID
        Map<String, Object> deduplicatedRecords = new Map<String, Object>();
        Map<String, DateTime> latestTimestamp = new Map<String, DateTime>();
        
        for (Object srcObj : scope) {
            String accountId = (String) getFieldValue(srcObj, ORDER_BY_SRC);
            if (String.isBlank(accountId)) {
                System.debug(LoggingLevel.WARN, 'Skipping record with blank external ID');
                continue;
            }

            DateTime lastModified = convertToDateTime(getFieldValue(srcObj, 'ssot__LastModifiedDate__c'));
            if (lastModified == null) lastModified = DateTime.now();

            if (!deduplicatedRecords.containsKey(accountId) || 
                lastModified > latestTimestamp.get(accountId)) {
                deduplicatedRecords.put(accountId, srcObj);
                latestTimestamp.put(accountId, lastModified);
            }
        }

        Integer duplicatesRemoved = scope.size() - deduplicatedRecords.size();
        if (duplicatesRemoved > 0) {
            System.debug(LoggingLevel.WARN, 'Removed ' + duplicatesRemoved + ' duplicate records');
        }

        List<SObject> out = new List<SObject>();

        // Bulk resolve Host_Account__c
        Set<String> hostKeys = new Set<String>();
        for (Object srcObj : deduplicatedRecords.values()) {
            String k = (String) getFieldValue(srcObj, 'Parent_ID__c');
            if (!String.isBlank(k)) hostKeys.add(k);
        }
        
        Map<String, Id> hostByExt = bulkLookupByExternalId('Account', 'SEAWARE_Agency_ID__c', hostKeys);

        // Process each unique account
        for (String accountId : deduplicatedRecords.keySet()) {
            Object srcObj = deduplicatedRecords.get(accountId);
            
            Account acc = new Account();
            acc.put(ACCOUNT_EXTID, accountId);

            for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) {
                if (m.tgt == ACCOUNT_EXTID) continue;
                
                if (ACCOUNT_LOOKUPS.contains(m.tgt)) {
                    String parentKey = (String) getFieldValue(srcObj, 'Parent_ID__c');
                    if (!String.isBlank(parentKey)) {
                        Id pid = hostByExt.get(parentKey);
                        if (pid != null) setFieldValue(acc, m.tgt, pid);
                    }
                } else {
                    Object value = getFieldValue(srcObj, m.src);
                    if (value != null) {
                        setFieldValue(acc, m.tgt, value);
                    }
                }
            }
            out.add(acc);
        }

        System.debug(LoggingLevel.WARN, 'Final output size: ' + out.size());
        
        return new DC_UpsertBundle(out, ACCOUNT_EXTID);
    }

    // CHANGED: Accept Object instead of List<SObject>
    public override void afterUpsert(Object scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
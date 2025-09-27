public with sharing class DC_AccountStep extends DC_BaseStep implements DC_IWhere {

    // Source + key
    private static final String SRC_OBJECT   = 'ssot__Account__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';

    // Target ext-id (change if your org uses a different one)
    private static final String ACCOUNT_EXTID = 'SEAWARE_Agency_ID__c';
    private static final String STEP_NAME = 'Account';

    // Treat these as lookups we try to resolve by Account external id
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

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        System.debug(LoggingLevel.WARN, '=== ACCOUNT STEP START ===');
        System.debug(LoggingLevel.WARN, 'Input scope size: ' + scope.size());
        
        // **FIX: Deduplicate by external ID first**
        Map<String, SObject> deduplicatedRecords = new Map<String, SObject>();
        Map<String, DateTime> latestTimestamp = new Map<String, DateTime>();
        
        for (SObject src : scope) {
            String accountId = (String) getFieldValue(src, ORDER_BY_SRC);
            if (String.isBlank(accountId)) {
                System.debug(LoggingLevel.WARN, 'Skipping record with blank external ID');
                continue;
            }

            DateTime lastModified = convertToDateTime(getFieldValue(src, 'ssot__LastModifiedDate__c'));
            if (lastModified == null) lastModified = DateTime.now();

            if (!deduplicatedRecords.containsKey(accountId) || 
                lastModified > latestTimestamp.get(accountId)) {
                deduplicatedRecords.put(accountId, src);
                latestTimestamp.put(accountId, lastModified);
            }
        }

        Integer duplicatesRemoved = scope.size() - deduplicatedRecords.size();
        if (duplicatesRemoved > 0) {
            System.debug(LoggingLevel.WARN, 'Removed ' + duplicatesRemoved + ' duplicate records');
        }

        List<SObject> out = new List<SObject>();

        // Bulk resolve Host_Account__c by Account external id
        Set<String> hostKeys = new Set<String>();
        for (SObject src : deduplicatedRecords.values()) {
            String k = (String) getFieldValue(src, 'Parent_ID__c');
            if (!String.isBlank(k)) hostKeys.add(k);
        }
        
        Map<String, Id> hostByExt = bulkLookupByExternalId('Account', 'SEAWARE_Agency_ID__c', hostKeys);

        for (String accountId : deduplicatedRecords.keySet()) {
            SObject src = deduplicatedRecords.get(accountId);
            
            Account acc = new Account();
            // **FIX: Set upsert key FIRST, before applying field mappings**
            setFieldValue(acc, ACCOUNT_EXTID, accountId);

            for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) {
                // **FIX: Skip the external ID mapping since we already set it above**
                if (m.tgt == ACCOUNT_EXTID) {
                    System.debug(LoggingLevel.WARN, 'Skipping external ID mapping to prevent overwrite: ' + m.src + ' → ' + m.tgt);
                    continue;
                }
                
                if (ACCOUNT_LOOKUPS.contains(m.tgt)) {
                    String parentKey = (String) getFieldValue(src, 'Parent_ID__c');
                    if (!String.isBlank(parentKey)) {
                        Id pid = hostByExt.get(parentKey);
                        if (pid != null) setFieldValue(acc, m.tgt, pid);
                    }
                } else {
                    Object value = getFieldValue(src, m.src);
                    if (value != null) {
                        setFieldValue(acc, m.tgt, value);
                    }
                }
            }
            out.add(acc);
        }

        System.debug(LoggingLevel.WARN, 'Final output size: ' + out.size());
        System.debug(LoggingLevel.WARN, '=== ACCOUNT STEP END ===');
        
        return new DC_UpsertBundle(out, ACCOUNT_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
       
    }
}
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
        return f;
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        List<SObject> out = new List<SObject>();

        // Bulk resolve Host_Account__c by Account external id
        Set<String> hostKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String) getFieldValue(src, 'Parent_ID__c');
            if (!String.isBlank(k)) hostKeys.add(k);
        }
        
        Map<String, Id> hostByExt = bulkLookupByExternalId('Account', 'SEAWARE_Agency_ID__c', hostKeys);

        for (SObject src : scope) {
            Account acc = new Account();
            // upsert key
            String accountId = (String) getFieldValue(src, ORDER_BY_SRC);
            setFieldValue(acc, ACCOUNT_EXTID, accountId);

            for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) {
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
        return new DC_UpsertBundle(out, ACCOUNT_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
       
    }
}
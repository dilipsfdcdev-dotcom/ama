public with sharing class DC_AccountStep implements DC_IStep, DC_IWhere {

    // Source + key
    private static final String SRC_OBJECT   = 'ssot__Account__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';

    // Target ext-id (change if your org uses a different one)
    private static final String ACCOUNT_EXTID = 'SEAWARE_Agency_ID__c';

    // Treat these as lookups we try to resolve by Account external id
    private static final Set<String> ACCOUNT_LOOKUPS = new Set<String>{ 'Host_Account__c' };

    public String sourceObjectApi()    { return SRC_OBJECT; }
    public String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
       // return 'ssot__DataSourceObjectId__c = \'Seaware_Account_E1C509FE\' AND ssot__LastModifiedDate__c = TODAY';
       return 'ssot__DataSourceObjectId__c = \'Seaware_Account_E1C509FE\' AND ssot__LastModifiedDate__c != null';
    }

    public Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) f.add(m.src);
        f.add(ORDER_BY_SRC);
        f.add('Parent_ID__c');
        return f;
    }

    public DC_UpsertBundle mapScope(List<SObject> scope) {
        List<SObject> out = new List<SObject>();

        // Bulk resolve Host_Account__c by Account external id
        Set<String> hostKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Parent_ID__c');
            if (!String.isBlank(k)) hostKeys.add(k);
        }
        Map<String, Id> hostByExt = new Map<String, Id>();
        if (!hostKeys.isEmpty()) {
            for (Account a : [
                SELECT Id, SEAWARE_Agency_ID__c
                FROM Account
                WHERE SEAWARE_Agency_ID__c IN :hostKeys
            ]) {
                hostByExt.put(a.SEAWARE_Agency_ID__c, a.Id);
            }
        }

        for (SObject src : scope) {
            Account acc = new Account();
            // upsert key
            acc.put(ACCOUNT_EXTID, (String)src.get(ORDER_BY_SRC));

            for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) {
                if (ACCOUNT_LOOKUPS.contains(m.tgt)) {
                    String parentKey = (String)src.get('Parent_ID__c');
                    if (!String.isBlank(parentKey)) {
                        Id pid = hostByExt.get(parentKey);
                        if (pid != null) acc.put(m.tgt, pid);
                    }
                } else {
                    acc.put(m.tgt, src.get(m.src));
                }
            }
            out.add(acc);
        }
        return new DC_UpsertBundle(out, ACCOUNT_EXTID);
    }

    public void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
       
    }
}

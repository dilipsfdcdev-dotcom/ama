public with sharing class DC_SailingStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'Seaware_Sailing__dlm';
    private static final String ORDER_BY_SRC = 'Sailing_Code__c';
    private static final String SAILING_EXTID = 'Sailing_Code__c';
    private static final String TGT_OBJECT = 'Sailing__c';
    private static final String STEP_NAME = 'Sailing';
    
    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        return DC_DateUtil.getDateFilterClauseForSeaware(STEP_NAME, 'Last_Modified_Date__c');
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.SAILING_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        f.add('Ship_ID__c'); // for Ship lookup
        return f;
    }

    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();

        // Bulk resolve Ship by external id (using Ship_Code now)
        Set<String> shipKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Ship_ID__c');
            if (!String.isBlank(k)) shipKeys.add(k);
        }
        Map<String, Id> shipByExt = bulkLookupByExternalId('Ship__c', 'Ship_ID__c', shipKeys);
        
        for (Object src : scope) {
            SObject sailing = t.newSObject();
            String sailingCode = (String) getFieldValue(src, ORDER_BY_SRC);
            setFieldValue(sailing, SAILING_EXTID, sailingCode);
            
            for (DC_FieldMap m : DC_Mappings.SAILING_MAP) {
                if (m.tgt == 'Ship__c') {
                    // Handle Ship lookup using Ship_Code
                    String shipKey = (String) getFieldValue(src, 'Ship_ID__c'); // This should map to Ship_Code
                    if (!String.isBlank(shipKey)) {
                        Id shipRecordId = shipByExt.get(shipKey);
                        if (shipRecordId != null) {
                            setFieldValue(sailing, m.tgt, shipRecordId);
                        }
                    }
                } else {
                    Object value = getFieldValue(src, m.src);
                    if (value != null) {
                        setFieldValue(sailing, m.tgt, value);
                    }
                }
            }
            out.add(sailing);
        }
        return new DC_UpsertBundle(out, SAILING_EXTID);
    }

    public override void afterUpsert(Object scopeObj, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
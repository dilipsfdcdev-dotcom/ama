public with sharing class DC_SailingStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'Seaware_Sailing__dlm';
    private static final String ORDER_BY_SRC = 'Sailing_Code__c';
    private static final String SAILING_EXTID = 'Sailing_Code__c';
    private static final String TGT_OBJECT = 'Sailing__c';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
       return 'Last_Modified_Date__c = TODAY';
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

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();

        // Bulk resolve Ship by external id (using Ship_Code now)
        Set<String> shipKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Ship_ID__c');
            if (!String.isBlank(k)) shipKeys.add(k);
        }
        Map<String, Id> shipByExt = new Map<String, Id>();
        if (!shipKeys.isEmpty()) {
            for (Ship__c s : [
                SELECT Id, Ship_Code__c
                FROM Ship__c
                WHERE Ship_Code__c IN :shipKeys
            ]) {
                shipByExt.put(s.Ship_Code__c, s.Id);
            }
        }
        
        for (SObject src : scope) {
            SObject sailing = t.newSObject();
            sailing.put(SAILING_EXTID, (String)src.get(ORDER_BY_SRC));
            
            for (DC_FieldMap m : DC_Mappings.SAILING_MAP) {
                if (m.tgt == 'Ship__c') {
                    // Handle Ship lookup using Ship_Code
                    String shipKey = (String)src.get('Ship_ID__c'); // This should map to Ship_Code
                    if (!String.isBlank(shipKey)) {
                        Id shipRecordId = shipByExt.get(shipKey);
                        if (shipRecordId != null) {
                            sailing.put(m.tgt, shipRecordId);
                        }
                    }
                } else {
                    Object value = src.get(m.src);
                    if (value != null) {
                        sailing.put(m.tgt, value);
                    }
                }
            }
            out.add(sailing);
        }
        return new DC_UpsertBundle(out, SAILING_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
public with sharing class DC_ShipStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'Seaware_Ship__dlm';
    private static final String ORDER_BY_SRC = 'Ship_ID__c';
    private static final String SHIP_EXTID = 'Ship_Code__c'; // Updated to use Ship_Code as external ID
    private static final String TGT_OBJECT = 'Ship__c';
    private static final String STEP_NAME = 'Ship';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        return DC_DateUtil.getDateFilterClauseForSeaware(STEP_NAME, 'Last_Modified_Date__c');
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.SHIP_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor
        f.add('Ship_Code__c'); // ext-id source
        return f;
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();
        
        for (SObject src : scope) {
            SObject ship = t.newSObject();
            // Use Ship_Code as external ID instead of Ship_ID
            String shipCode = (String) getFieldValue(src, 'Ship_Code__c');
            setFieldValue(ship, SHIP_EXTID, shipCode);
            
            for (DC_FieldMap m : DC_Mappings.SHIP_MAP) {
                Object value = getFieldValue(src, m.src);
                if (value != null) {
                    setFieldValue(ship, m.tgt, value);
                }
            }
            out.add(ship);
        }
        return new DC_UpsertBundle(out, SHIP_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
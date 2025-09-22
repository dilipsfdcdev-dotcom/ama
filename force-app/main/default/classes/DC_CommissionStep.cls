public with sharing class DC_CommissionStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT   = 'Seaware_Commission_Structure__dlm';
    private static final String ORDER_BY_SRC = 'Agency_ID__c';
    private static final String COMMISSION_EXTID = 'AgencyID__c';
    private static final String TGT_OBJECT   = 'Commission_Structure__c';

    public override String sourceObjectApi()    { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
       return 'Last_Modified_Date__c = TODAY';
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.COMMISSION_MAP) f.add(m.src);
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        return f;
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();
        for (SObject src : scope) {
            SObject rec = t.newSObject();
            rec.put(COMMISSION_EXTID, (String)src.get(ORDER_BY_SRC));
            for (DC_FieldMap m : DC_Mappings.COMMISSION_MAP) {
                system.debug('fields m.tgt-->'+m.tgt);
                system.debug('fields src.get(m.src)-->'+src.get(m.src));
                rec.put(m.tgt, src.get(m.src));
            }
            out.add(rec);
        }
        return new DC_UpsertBundle(out, COMMISSION_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
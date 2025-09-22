public with sharing class DC_DmlUtil {
    public static Database.UpsertResult[] upsertByExtId(
        List<SObject> recs,
        String extFieldApi,
        Boolean allOrNone
    ){
        if (recs == null || recs.isEmpty()) return new Database.UpsertResult[0];

        Schema.SObjectType sType = recs[0].getSObjectType();
        Schema.DescribeSObjectResult d = sType.getDescribe();
        Map<String, Schema.SObjectField> fmap = d.fields.getMap();

        Schema.SObjectField extField = fmap.get(extFieldApi);
        if (extField == null) {
            throw new DC_SyncException('External Id field not found: ' + extFieldApi + ' on ' + d.getName());
        }
        return Database.upsert(recs, extField, allOrNone);
    }
}


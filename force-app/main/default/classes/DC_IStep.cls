public interface DC_IStep {
    // Data Cloud source object API name, e.g., 'ssot__Account__dlm'
    String sourceObjectApi();

    // The source field to ORDER BY and page with (must be String-typed). e.g., 'ssot__Id__c'
    String orderBySourceField();

    // All source fields required by this step (mappings + keys/parents). Must include orderBySourceField().
    Set<String> sourceFields();

    // Map source scope → target records; set ext-id on each record; return bundle with externalIdField API name
    DC_UpsertBundle mapScope(List<SObject> scope);

    // Optional post-upsert hook
    void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results);
}

public interface DC_IStep {
    String sourceObjectApi();
    String orderBySourceField();
    Set<String> sourceFields();
    
    // CHANGED: Accept Object instead of List<SObject>
    DC_UpsertBundle mapScope(Object scope);
    
    void afterUpsert(Object scope, DC_UpsertBundle bundle, Database.UpsertResult[] results);
    
    Map<String, DC_JoinConfig> getAdditionalSources();
    DC_UpsertBundle mapMultiSourceScope(DC_MultiSourceData data);
}
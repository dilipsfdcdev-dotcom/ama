public abstract with sharing class DC_BaseStep implements DC_IStep {
    
    // Default implementation for single-source steps
    public virtual Map<String, DC_JoinConfig> getAdditionalSources() {
        return new Map<String, DC_JoinConfig>();
    }
    
    // Default implementation calls mapScope for backward compatibility
    public virtual DC_UpsertBundle mapMultiSourceScope(DC_MultiSourceData data) {
        return mapScope(data.mainRecords);
    }
    
    // Abstract methods that must be implemented by concrete classes
    public abstract String sourceObjectApi();
    public abstract String orderBySourceField();
    public abstract Set<String> sourceFields();
    public abstract DC_UpsertBundle mapScope(List<SObject> scope);
    public abstract void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results);
    
    // Helper method to get first record from additional source
    protected SObject getFirstAdditionalRecord(DC_MultiSourceData data, String sourceAlias, String keyValue) {
        List<SObject> records = data.getAdditionalData(sourceAlias, keyValue);
        return records.isEmpty() ? null : records[0];
    }
    
    // Helper method to get all records from additional source
    protected List<SObject> getAllAdditionalRecords(DC_MultiSourceData data, String sourceAlias, String keyValue) {
        return data.getAdditionalData(sourceAlias, keyValue);
    }
}
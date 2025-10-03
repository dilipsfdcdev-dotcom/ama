public with sharing class DC_UpsertBundle {
    public List<SObject> records { get; private set; }
    public List<SObject> recordsToUpdate { get; private set; }
    public String externalIdField { get; private set; }
    
    // Original constructor for backward compatibility
    public DC_UpsertBundle(List<SObject> records, String externalIdField) {
        this.records = (records == null) ? new List<SObject>() : records;
        this.recordsToUpdate = new List<SObject>();
        this.externalIdField = externalIdField;
    }
    
    // **NEW: Constructor that accepts both INSERT and UPDATE lists**
    public DC_UpsertBundle(List<SObject> recordsToInsert, List<SObject> recordsToUpdate, String externalIdField) {
        this.records = (recordsToInsert == null) ? new List<SObject>() : recordsToInsert;
        this.recordsToUpdate = (recordsToUpdate == null) ? new List<SObject>() : recordsToUpdate;
        this.externalIdField = externalIdField;
    }
}
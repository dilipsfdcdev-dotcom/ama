public with sharing class DC_UpsertBundle {
    public List<SObject> records { get; private set; }
    public String externalIdField { get; private set; }
    public DC_UpsertBundle(List<SObject> records, String externalIdField) {
        this.records = (records == null) ? new List<SObject>() : records;
        this.externalIdField = externalIdField;
    }
}

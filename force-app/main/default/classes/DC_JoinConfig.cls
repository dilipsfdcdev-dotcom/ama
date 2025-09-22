public with sharing class DC_JoinConfig {
    public String sourceObject { get; private set; }
    public Set<String> sourceFields { get; private set; }
    public String joinField { get; private set; }      // Field in additional source to join on
    public String parentField { get; private set; }    // Field in main source that matches joinField
    public String whereClause { get; private set; }    // Optional additional WHERE clause
    
    public DC_JoinConfig(String sourceObject, Set<String> sourceFields, String joinField, String parentField) {
        this(sourceObject, sourceFields, joinField, parentField, null);
    }
    
    public DC_JoinConfig(String sourceObject, Set<String> sourceFields, String joinField, String parentField, String whereClause) {
        this.sourceObject = sourceObject;
        this.sourceFields = sourceFields != null ? sourceFields : new Set<String>();
        this.joinField = joinField;
        this.parentField = parentField;
        this.whereClause = whereClause;
    }
}
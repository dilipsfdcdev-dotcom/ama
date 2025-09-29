public with sharing class DC_MultiSourceData {
    public List<Object> mainRecords { get; private set; }  // CHANGED from List<SObject>
    public Map<String, Map<String, List<SObject>>> additionalData { get; private set; }
    
    public DC_MultiSourceData(List<Object> mainRecords) {  // CHANGED parameter type
        this.mainRecords = mainRecords != null ? mainRecords : new List<Object>();
        this.additionalData = new Map<String, Map<String, List<SObject>>>();
    }
    
    public void addAdditionalData(String sourceAlias, String keyValue, List<SObject> records) {
        if (!additionalData.containsKey(sourceAlias)) {
            additionalData.put(sourceAlias, new Map<String, List<SObject>>());
        }
        additionalData.get(sourceAlias).put(keyValue, records);
    }
    
    public List<SObject> getAdditionalData(String sourceAlias, String keyValue) {
        if (additionalData.containsKey(sourceAlias) && additionalData.get(sourceAlias).containsKey(keyValue)) {
            return additionalData.get(sourceAlias).get(keyValue);
        }
        return new List<SObject>();
    }
}
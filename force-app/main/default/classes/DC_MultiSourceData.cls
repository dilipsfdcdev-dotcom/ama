public with sharing class DC_MultiSourceData {
    public List<SObject> mainRecords { get; private set; }
    public Map<String, Map<String, List<SObject>>> additionalData { get; private set; }
    
    public DC_MultiSourceData(List<SObject> mainRecords) {
        this.mainRecords = mainRecords != null ? mainRecords : new List<SObject>();
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
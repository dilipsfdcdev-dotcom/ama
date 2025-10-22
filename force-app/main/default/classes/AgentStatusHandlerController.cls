public with sharing class AgentStatusHandlerController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getPresenceStatusMap() {
        Map<String, String> statusMap = new Map<String, String>();
        for (ServicePresenceStatus sps : [
            SELECT Id, DeveloperName 
            FROM ServicePresenceStatus
        ]) {
            String presenceStatusId = String.valueOf(sps.Id).substring(0, 15);
            statusMap.put(sps.DeveloperName, presenceStatusId);
        }
        return statusMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserId() {
        return UserInfo.getUserId();
    }
}
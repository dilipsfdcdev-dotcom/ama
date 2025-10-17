public class AgentWorkTriggerHandler {
    public static void handleAfterUpdate(List<AgentWork> newList, Map<Id, Agentwork> oldMap) {
        Set<Id> leadIdsToQuery = new Set<Id>();
        Group prcGroup = [SELECT Id, Name,DeveloperName FROM Group WHERE DeveloperName = 'PRC_Lead_Queue'];
        
        for (AgentWork aw : newList) {
            if (aw.Status == 'Opened' && oldMap.get(aw.Id).Status == 'Assigned' && aw.WorkItemId != null && String.valueOf(aw.WorkItemId).startsWith('00Q') && aw.OriginalGroupId == prcGroup.Id) {
                leadIdsToQuery.add(aw.WorkItemId);
            }
        }

        if (leadIdsToQuery.isEmpty()) {
            return;
        }

        Map<Id, Lead> leadMap = new Map<Id, Lead>(
            [SELECT Id, Converted_Opportunity__c, OwnerId 
             FROM Lead 
             WHERE Id IN :leadIdsToQuery]
        );

        Set<Id> opportunityIdsToUpdate = new Set<Id>();
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (AgentWork aw : newList) {
            if (aw.Status == 'Opened' && aw.WorkItemId != null && String.valueOf(aw.WorkItemId).startsWith('00Q')) {
                Lead ld = leadMap.get(aw.WorkItemId);
                if (ld != null && ld.Converted_Opportunity__c != null && !opportunityIdsToUpdate.contains(ld.Converted_Opportunity__c)) {
                    Opportunity opp = new Opportunity(
                        Id = ld.Converted_Opportunity__c,
                        OwnerId = ld.OwnerId,
                        Assignment_Timer_Start__c = true,
                        Timer_Starttime__c = System.now()
                    );
                    opportunitiesToUpdate.add(opp);
                    opportunityIdsToUpdate.add(ld.Converted_Opportunity__c);
                }
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }
}
public class TaskTriggerHandler {
    public static Boolean isRunning = false;

    // Cache PRC Case RecordTypeId (per-transaction)
    private static Id CASE_RTI_PRC;
    private static Id prcCaseRtId() {
        if (CASE_RTI_PRC != null) return CASE_RTI_PRC;
        CASE_RTI_PRC = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND DeveloperName = 'PRC'
            LIMIT 1
        ]?.Id;
        return CASE_RTI_PRC;
    }

    public static void linkTasksToConvertedContact(List<Task> newList, Map<Id, Task> oldMap) {
        if (newList == null || newList.isEmpty()) return;
        Id prcRtId = prcCaseRtId();
        if (prcRtId == null) return; // No PRC RT configured; nothing to do.

        // 1) Collect candidate Tasks
        List<Task> candidates = new List<Task>();
        Set<Id> caseIds = new Set<Id>();

        for (Task t : newList) {
            Task oldT = (oldMap == null) ? null : oldMap.get(t.Id);

            Boolean relatedToCase = (t.WhatId != null && String.valueOf(t.WhatId).startsWith('500')); // Case prefix
            if (!relatedToCase) continue;

            // a) Inserted as Completed OR updated to Completed
            Boolean becameCompleted = (oldT == null)
                ? (t.Status == 'Completed')
                : (oldT.Status != 'Completed' && t.Status == 'Completed');

            // b) WhoId changed (including null -> non-null)
            Boolean whoChanged = (oldT != null && t.WhoId != oldT.WhoId);

            if (becameCompleted || whoChanged) {
                candidates.add(t);
                caseIds.add(t.WhatId);
            }
        }
        if (candidates.isEmpty()) return;

        // 2) Only PRC cases among candidates
        Map<Id, Case> prcCasesById = new Map<Id, Case>([
            SELECT Id, RecordTypeId
            FROM Case
            WHERE Id IN :caseIds AND RecordTypeId = :prcRtId
        ]);
        if (prcCasesById.isEmpty()) return;

        // 3) Lead → Converted Contact mapping by Case_ID__c
        Map<Id, Id> caseIdToContactId = new Map<Id, Id>(); // CaseId -> ContactId
        for (Lead l : [
            SELECT Id, Case_ID__c, Converted_Contact__c
            FROM Lead
            WHERE Case_ID__c IN :prcCasesById.keySet()
                  AND Converted_Contact__c != null
        ]) {
            if (l.Case_ID__c != null) {
                caseIdToContactId.put((Id) l.Case_ID__c, l.Converted_Contact__c);
            }
        }
        if (caseIdToContactId.isEmpty()) return;

        // 4) Prepare Task updates (idempotent: only if different)
        List<Task> toUpdate = new List<Task>();
        for (Task t : candidates) {
            if (!prcCasesById.containsKey(t.WhatId)) continue; // ensure PRC Case
            Id desiredContactId = caseIdToContactId.get(t.WhatId);
            if (desiredContactId == null) continue;

            if (t.WhoId != desiredContactId) {
                toUpdate.add(new Task(
                    Id    = t.Id,
                    WhoId = desiredContactId
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}
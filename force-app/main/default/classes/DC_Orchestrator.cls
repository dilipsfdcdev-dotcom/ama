public with sharing class DC_Orchestrator {

    public static void start() {
        // Read active steps ordered by sequence
        List<DataSync_ObjectOrder__mdt> rows = [
            SELECT StepName__c, Sequence__c, Active__c
            FROM DataSync_ObjectOrder__mdt
            WHERE Active__c = true
            ORDER BY Sequence__c ASC
        ];
        if (rows.isEmpty()) return;

        List<String> stepNames = new List<String>();
        for (DataSync_ObjectOrder__mdt r : rows) {
            if (!String.isBlank(r.StepName__c)) stepNames.add(r.StepName__c);
        }
        if (stepNames.isEmpty()) return;

        Integer pageSize = (DC_Debug.ENABLE && DC_Debug.MAX_ROWS > 0)
            ? DC_Debug.MAX_ROWS : DC_StepRunner.DEFAULT_PAGE_SIZE;

        // Kick off first step (page 1, no lastKey)
        System.enqueueJob(new StepStarter(stepNames, 0, pageSize));
    }

    // Starts a given step (index) at page 1
    public class StepStarter implements Queueable, Database.AllowsCallouts {
        private final List<String> stepNames;
        private final Integer index;
        private final Integer pageSize;
        public StepStarter(List<String> stepNames, Integer index, Integer pageSize) {
            this.stepNames = stepNames; this.index = index; this.pageSize = pageSize;
        }
        public void execute(QueueableContext qc) {
            if (index == null || index >= stepNames.size()) return;
            System.enqueueJob(new DC_StepRunner(stepNames, index, null, pageSize));
        }
    }
}

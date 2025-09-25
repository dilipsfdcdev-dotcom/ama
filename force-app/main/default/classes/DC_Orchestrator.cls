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

        // Start with date chunking for Data Cloud steps
        System.enqueueJob(new StepStarter(stepNames, 0, pageSize));
    }

    // Starts a given step (index) at page 1
    public class StepStarter implements Queueable, Database.AllowsCallouts {
        private final List<String> stepNames;
        private final Integer index;
        private final Integer pageSize;
        
        public StepStarter(List<String> stepNames, Integer index, Integer pageSize) {
            this.stepNames = stepNames; 
            this.index = index; 
            this.pageSize = pageSize;
        }
        
        public void execute(QueueableContext qc) {
            if (index == null || index >= stepNames.size()) return;
            
            // Check if the step is a Data Cloud step and initialize date chunking
            String stepName = stepNames[index];
            DC_IStep step = DC_StepFactory.make(stepName);
            
            if (step != null) {
                String srcObject = step.sourceObjectApi();
                Boolean isDataCloudObject = srcObject.contains('__dlm') || srcObject.startsWith('ssot__');
                
                if (isDataCloudObject) {
                    // Initialize date chunking for Data Cloud objects
                    Date endDate = Date.today();
                    Date startDate = getChunkStartDate(stepName, endDate);
                    
                    System.debug(LoggingLevel.WARN, 'Starting Data Cloud step ' + stepName + 
                                ' with date chunk: ' + startDate + ' to ' + endDate);
                    
                    System.enqueueJob(new DC_StepRunner(stepNames, index, null, pageSize, 0, startDate, endDate));
                } else {
                    // Regular Salesforce object - no date chunking needed
                    System.enqueueJob(new DC_StepRunner(stepNames, index, null, pageSize, 0));
                }
            } else {
                // Skip invalid step
                System.debug(LoggingLevel.ERROR, 'Invalid step: ' + stepName);
                if (index + 1 < stepNames.size()) {
                    System.enqueueJob(new StepStarter(stepNames, index + 1, pageSize));
                }
            }
        }
        
        private Date getChunkStartDate(String stepName, Date endDate) {
            // Get sync days from metadata
            Integer syncDays = DC_DateUtil.getSyncDaysForStep(stepName);
            
            // For Data Cloud objects, we need to process data in smaller chunks
            // to stay within the OFFSET limit of 2000
            if (syncDays > 7) {
                // For large sync periods, start with the oldest data first
                // Calculate the full date range first
                Date fullRangeStartDate = endDate.addDays(-(syncDays - 1));
                
                // Start with the first 7-day chunk from the beginning of the range
                return fullRangeStartDate;
            } else {
                // Use the full sync period if it's small (7 days or less)
                return endDate.addDays(-(syncDays - 1));
            }
        }
    }
}
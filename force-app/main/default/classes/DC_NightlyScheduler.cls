global with sharing class DC_NightlyScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        DC_Orchestrator.start();
    }
}


// DC_Debug.ENABLE   = true;
// DC_Debug.MAX_ROWS = 10;
// DC_Orchestrator.start();
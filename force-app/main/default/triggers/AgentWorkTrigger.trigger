trigger AgentWorkTrigger on AgentWork (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        AgentWorkTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
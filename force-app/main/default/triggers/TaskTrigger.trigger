trigger TaskTrigger on Task (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            if (TaskTriggerHandler.isRunning) return;
            TaskTriggerHandler.isRunning = true;
            try {
                TaskTriggerHandler.linkTasksToConvertedContact(Trigger.new, Trigger.oldMap);
            } finally {
                TaskTriggerHandler.isRunning = false;
            }
        }
    }
}
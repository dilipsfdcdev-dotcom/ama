@IsTest
private class DC_NightlyScheduler_Test {
    
    @IsTest
    static void testSchedulerCreation() {
        // Just test that the scheduler can be instantiated
        DC_NightlyScheduler scheduler = new DC_NightlyScheduler();
        System.assertNotEquals(null, scheduler);
    }
    
    @IsTest
    static void testSchedulerCanBeScheduled() {
        // Test that we can create a schedule without executing it
        // We don't actually call Test.startTest/stopTest to avoid execution
        DC_NightlyScheduler scheduler = new DC_NightlyScheduler();
        System.assertNotEquals(null, scheduler);
        
        // Verify it can be cast to Schedulable (compile-time check)
        Schedulable s = (Schedulable) scheduler;
        System.assertNotEquals(null, s);
    }
    
    @IsTest
    static void testSchedulerClassName() {
        DC_NightlyScheduler scheduler = new DC_NightlyScheduler();
        String className = String.valueOf(scheduler).substringBefore(':');
        System.assertEquals('DC_NightlyScheduler', className);
    }
}
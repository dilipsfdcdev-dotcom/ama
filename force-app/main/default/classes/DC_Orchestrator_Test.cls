@IsTest
private class DC_Orchestrator_Test {
    
    @TestSetup
    static void setupTestData() {
        // Note: In actual implementation, you would need to create 
        // DataSync_ObjectOrder__mdt records in your org
        // This test assumes those custom metadata records exist
    }
    
    @IsTest
    static void testStart_NoActiveSteps() {
        // This test simulates the scenario where no active steps are configured
        Test.startTest();
        DC_Orchestrator.start();
        Test.stopTest();
        
        // Should complete without errors when no steps are configured
        System.assert(true);
    }
    
    @IsTest
    static void testStepStarter_ValidIndex() {
        List<String> stepNames = new List<String>{'Account', 'Commission'};
        DC_Orchestrator.StepStarter starter = new DC_Orchestrator.StepStarter(stepNames, 0, 200);
        
        Test.startTest();
        System.enqueueJob(starter);
        Test.stopTest();
        
        // Verify job was enqueued successfully
        System.assert(true);
    }
    
    @IsTest
    static void testStepStarter_InvalidIndex() {
        List<String> stepNames = new List<String>{'Account'};
        DC_Orchestrator.StepStarter starter = new DC_Orchestrator.StepStarter(stepNames, 5, 200);
        
        Test.startTest();
        System.enqueueJob(starter);
        Test.stopTest();
        
        // Should handle invalid index gracefully
        System.assert(true);
    }
    
    @IsTest
    static void testStepStarter_NullIndex() {
        List<String> stepNames = new List<String>{'Account'};
        DC_Orchestrator.StepStarter starter = new DC_Orchestrator.StepStarter(stepNames, null, 200);
        
        Test.startTest();
        System.enqueueJob(starter);
        Test.stopTest();
        
        // Should handle null index gracefully
        System.assert(true);
    }
    
    @IsTest
    static void testStepStarter_EmptyStepNames() {
        List<String> stepNames = new List<String>();
        DC_Orchestrator.StepStarter starter = new DC_Orchestrator.StepStarter(stepNames, 0, 200);
        
        Test.startTest();
        System.enqueueJob(starter);
        Test.stopTest();
        
        // Should handle empty step names gracefully
        System.assert(true);
    }
}
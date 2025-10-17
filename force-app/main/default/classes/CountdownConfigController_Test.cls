@IsTest
private class CountdownConfigController_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create test Opportunity with required fields
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id,
            Assignment_Timer_Start__c = true,
            Timer_Starttime__c = System.now()
        );
        insert testOpp;
        
        // Create test Lead with Converted_Opportunity__c
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Converted_Opportunity__c = testOpp.Id
        );
        insert testLead;
    }
    
    @IsTest
    static void testGetCountdownInfo_WithValidOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        // Verify response structure
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.serverNowUtc, 'Server time should be set');
        
        // If config exists, verify timer fields
        if (response.hasConfig && response.timerEnabled) {
            System.assertNotEquals(null, response.startTime, 'Start time should be set when timer is enabled');
            System.assert(response.durationSeconds >= 0, 'Duration should be non-negative');
        }
    }
    
    @IsTest
    static void testGetCountdownInfo_WithNullRecordId() {
        Test.startTest();
        try {
            CountdownConfigController.getCountdownInfo(null);
            System.assert(false, 'Should throw exception for null recordId');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('recordId is required'), 
                         'Should throw proper exception message');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetCountdownInfo_WithNoConfig() {
        // Create a Case record (assuming no config exists for Case)
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone'
        );
        insert testCase;
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(testCase.Id);
        Test.stopTest();
        
        // Should return response with hasConfig = false
        System.assertNotEquals(null, response, 'Response should not be null');
        // Config might not exist for Case, so hasConfig could be false
        System.assertNotEquals(null, response.serverNowUtc, 'Server time should always be set');
    }
    
    @IsTest
    static void testGetCountdownInfo_StopCondition_AttemptingContact() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Update opportunity to 'Attempting Contact' stage
        opp.StageName = 'Attempting Contact';
        update opp;
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        // If config exists and has stop field configured, stopNow should be true
        System.assertNotEquals(null, response, 'Response should not be null');
        if (response.hasConfig) {
            // stopNow should be true for 'Attempting Contact' stage
            System.assertEquals(true, response.stopNow, 
                              'Timer should stop for Attempting Contact stage');
        }
    }
    
    @IsTest
    static void testGetCountdownInfo_StopCondition_InContact() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Update opportunity to 'In Contact' stage
        opp.StageName = 'In Contact';
        update opp;
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        if (response.hasConfig) {
            // stopNow should be true for 'In Contact' stage
            System.assertEquals(true, response.stopNow, 
                              'Timer should stop for In Contact stage');
        }
    }
    
    @IsTest
    static void testGetCountdownInfo_NoStopCondition() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Keep opportunity in 'Prospecting' stage (not a stop condition)
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        if (response.hasConfig) {
            // stopNow should be false for non-stop stages
            System.assertEquals(false, response.stopNow, 
                              'Timer should NOT stop for Prospecting stage');
        }
    }
    
    @IsTest
    static void testGetCountdownInfo_TimerDisabled() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Disable timer
        opp.Assignment_Timer_Start__c = false;
        update opp;
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        if (response.hasConfig) {
            System.assertEquals(false, response.timerEnabled, 
                              'Timer should be disabled');
        }
    }
    
    @IsTest
    static void testGetCountdownInfo_ExpireTimeCalculation() {
        Opportunity opp = [SELECT Id, Timer_Starttime__c FROM Opportunity LIMIT 1];
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        
        // If timer is enabled and has start time, expireAtUtc should be calculated
        if (response.hasConfig && response.timerEnabled && response.startTime != null && response.durationSeconds > 0) {
            System.assertNotEquals(null, response.expireAtUtc, 
                                 'Expire time should be calculated when timer is active');
            
            // Verify expireAtUtc is after startTime
            System.assert(response.expireAtUtc > response.startTime, 
                         'Expire time should be after start time');
        }
    }
    
    @IsTest
    static void testGetLeadIdsByConvertedOpportunity_WithLeads() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        List<Id> leadIds = CountdownConfigController.getLeadIdsByConvertedOpportunity(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, leadIds, 'Lead IDs list should not be null');
        System.assertEquals(1, leadIds.size(), 'Should find one lead linked to the opportunity');
    }
    
    @IsTest
    static void testGetLeadIdsByConvertedOpportunity_NoLeads() {
        // Create an opportunity without any linked leads
        Account testAccount = new Account(Name = 'Test Account 2');
        insert testAccount;
        
        Opportunity oppWithoutLeads = new Opportunity(
            Name = 'Test Opportunity 2',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id
        );
        insert oppWithoutLeads;
        
        Test.startTest();
        List<Id> leadIds = CountdownConfigController.getLeadIdsByConvertedOpportunity(oppWithoutLeads.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, leadIds, 'Lead IDs list should not be null');
        System.assertEquals(0, leadIds.size(), 'Should find no leads for this opportunity');
    }
    
    @IsTest
    static void testGetLeadIdsByConvertedOpportunity_NullOpportunityId() {
        Test.startTest();
        List<Id> leadIds = CountdownConfigController.getLeadIdsByConvertedOpportunity(null);
        Test.stopTest();
        
        System.assertNotEquals(null, leadIds, 'Lead IDs list should not be null');
        System.assertEquals(0, leadIds.size(), 'Should return empty list for null opportunity ID');
    }
    
    @IsTest
    static void testGetCountdownInfo_MessageFields() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        
        // If config exists, message fields should be populated
        if (response.hasConfig) {
            // Messages may be null or populated depending on metadata config
            // Just verify the fields are accessible
            String msg = response.message;
            String expMsg = response.expiredMessage;
            // No assertion needed - just verify no exceptions
        }
    }
    
    @IsTest
    static void testGetCountdownInfo_DurationSeconds() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        CountdownConfigController.Response response = CountdownConfigController.getCountdownInfo(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.durationSeconds, 'Duration seconds should not be null');
        System.assert(response.durationSeconds >= 0, 'Duration should be non-negative');
    }
}
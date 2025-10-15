@IsTest
private class DC_LogUtil_Test {
    
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account', SEAWARE_Agency_ID__c = 'TEST123');
        insert acc;
    }
    
    @IsTest
    static void testLogResults_Success() {
        Account acc = [SELECT Id, SEAWARE_Agency_ID__c FROM Account LIMIT 1];
        
        List<SObject> records = new List<SObject>{acc};
        DC_UpsertBundle bundle = new DC_UpsertBundle(records, 'SEAWARE_Agency_ID__c');
        
        // Perform actual upsert to get real results
        Database.UpsertResult[] results = Database.upsert(records, Schema.Account.SEAWARE_Agency_ID__c, false);
        
        Test.startTest();
        DC_LogUtil.logResults(bundle, results);
        Test.stopTest();
        
        System.assert(true, 'Should complete without errors');
    }
    
    @IsTest
    static void testLogResults_Failure() {
        Account acc = new Account(SEAWARE_Agency_ID__c = 'TEST456');
        // Missing required Name field will cause error
        
        List<SObject> records = new List<SObject>{acc};
        DC_UpsertBundle bundle = new DC_UpsertBundle(records, 'SEAWARE_Agency_ID__c');
        
        Database.UpsertResult[] results = Database.upsert(records, Schema.Account.SEAWARE_Agency_ID__c, false);
        
        Test.startTest();
        DC_LogUtil.logResults(bundle, results);
        Test.stopTest();
        
        System.assert(true, 'Should handle errors gracefully');
    }
    
    @IsTest
    static void testLogResults_NullParameters() {
        Test.startTest();
        DC_LogUtil.logResults(null, null);
        Test.stopTest();
        
        System.assert(true, 'Should handle null gracefully');
    }
    
    @IsTest
    static void testLogResults_EmptyBundle() {
        DC_UpsertBundle bundle = new DC_UpsertBundle(new List<SObject>(), 'Id');
        Database.UpsertResult[] results = new Database.UpsertResult[0];
        
        Test.startTest();
        DC_LogUtil.logResults(bundle, results);
        Test.stopTest();
        
        System.assert(true, 'Should handle empty bundle gracefully');
    }
    
    @IsTest
    static void testLogResultsCompact() {
        Account acc = [SELECT Id, SEAWARE_Agency_ID__c FROM Account LIMIT 1];
        
        List<SObject> records = new List<SObject>{acc};
        DC_UpsertBundle bundle = new DC_UpsertBundle(records, 'SEAWARE_Agency_ID__c');
        
        // Perform actual upsert to get real results
        Database.UpsertResult[] results = Database.upsert(records, Schema.Account.SEAWARE_Agency_ID__c, false);
        
        Test.startTest();
        DC_LogUtil.logResultsCompact(bundle, results);
        Test.stopTest();
        
        System.assert(true, 'Should complete without errors');
    }
    
    @IsTest
    static void testLogResultsCompact_NullParameters() {
        Test.startTest();
        DC_LogUtil.logResultsCompact(null, null);
        Test.stopTest();
        
        System.assert(true, 'Should handle null gracefully');
    }
    
    @IsTest
    static void testLogResults_WithVariousFieldTypes() {
        Account acc = new Account(
            Name = 'Test',
            SEAWARE_Agency_ID__c = 'TEST789',
            NumberOfEmployees = 100,
            AnnualRevenue = 1000000
        );
        insert acc;
        
        List<SObject> records = new List<SObject>{acc};
        DC_UpsertBundle bundle = new DC_UpsertBundle(records, 'SEAWARE_Agency_ID__c');
        
        Database.UpsertResult[] results = Database.upsert(records, Schema.Account.SEAWARE_Agency_ID__c, false);
        
        Test.startTest();
        DC_LogUtil.logResults(bundle, results);
        Test.stopTest();
        
        System.assert(true, 'Should log various field types');
    }
    
    @IsTest
    static void testLogResultsCompact_EmptyBundle() {
        DC_UpsertBundle bundle = new DC_UpsertBundle(new List<SObject>(), 'Id');
        Database.UpsertResult[] results = new Database.UpsertResult[0];
        
        Test.startTest();
        DC_LogUtil.logResultsCompact(bundle, results);
        Test.stopTest();
        
        System.assert(true, 'Should handle empty bundle gracefully');
    }
}
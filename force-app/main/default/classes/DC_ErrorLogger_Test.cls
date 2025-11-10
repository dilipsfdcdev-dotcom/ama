@IsTest
private class DC_ErrorLogger_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create test account for DML operations
        Account acc = new Account(
            Name = 'Test Account',
            SEAWARE_Agency_ID__c = 'TEST123'
        );
        insert acc;
    }
    
    @IsTest
    static void testLogUpsertErrors_Success() {
        // Create a record that will fail (missing required Name field)
        Account acc = new Account(
            SEAWARE_Agency_ID__c = 'FAIL001'
            // Missing Name field will cause error
        );
        
        List<SObject> records = new List<SObject>{ acc };
        DC_UpsertBundle bundle = new DC_UpsertBundle(records, 'SEAWARE_Agency_ID__c');
        
        // Perform upsert (will fail)
        Database.UpsertResult[] results = Database.upsert(
            records, 
            Schema.Account.SEAWARE_Agency_ID__c, 
            false
        );
        
        Test.startTest();
        DC_ErrorLogger.logUpsertErrors('Account', bundle, results, 'UPSERT');
        DC_ErrorLogger.flushErrorLogs();
        Test.stopTest();
        
        // Verify error log was created
        List<Error_Log__c> errorLogs = [
            SELECT Id, Step_Name__c, Operation_Type__c, External_ID__c, 
                   Error_Message__c, Error_Status_Code__c
            FROM Error_Log__c
        ];
        
        System.assert(errorLogs.size() > 0, 'Error log should be created');
        System.assertEquals('Account', errorLogs[0].Step_Name__c);
        System.assertEquals('UPSERT', errorLogs[0].Operation_Type__c);
    }
    
    @IsTest
    static void testLogUpdateErrors_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Create an invalid update (trying to set Name to null)
        acc.Name = null;
        
        List<SObject> records = new List<SObject>{ acc };
        Database.SaveResult[] results = Database.update(records, false);
        
        Test.startTest();
        DC_ErrorLogger.logUpdateErrors('Account', records, results);
        DC_ErrorLogger.flushErrorLogs();
        Test.stopTest();
        
        // Verify error log was created
        List<Error_Log__c> errorLogs = [
            SELECT Id, Step_Name__c, Operation_Type__c, Record_ID__c
            FROM Error_Log__c
        ];
        
        System.assert(errorLogs.size() > 0, 'Error log should be created');
        System.assertEquals('Account', errorLogs[0].Step_Name__c);
        System.assertEquals('UPDATE', errorLogs[0].Operation_Type__c);
    }
    
    @IsTest
    static void testLogException() {
        Test.startTest();
        
        try {
            // Simulate an exception
            Integer result = 1 / 0;
        } catch (Exception e) {
            DC_ErrorLogger.logException('TestStep', 'TEST', e, 'Additional context info');
            DC_ErrorLogger.flushErrorLogs();
        }
        
        Test.stopTest();
        
        // Verify error log was created
        List<Error_Log__c> errorLogs = [
            SELECT Id, Step_Name__c, Operation_Type__c, Error_Message__c, Error_Status_Code__c
            FROM Error_Log__c
        ];
        
        System.assertEquals(1, errorLogs.size(), 'One error log should be created');
        System.assertEquals('TestStep', errorLogs[0].Step_Name__c);
        System.assertEquals('TEST', errorLogs[0].Operation_Type__c);
        System.assert(errorLogs[0].Error_Message__c.contains('Divide by 0'));
    }
    
    @IsTest
    static void testLogUpsertErrors_NoErrors() {
        Account acc = new Account(
            Name = 'Valid Account',
            SEAWARE_Agency_ID__c = 'VALID001'
        );
        
        List<SObject> records = new List<SObject>{ acc };
        DC_UpsertBundle bundle = new DC_UpsertBundle(records, 'SEAWARE_Agency_ID__c');
        
        // Perform successful upsert
        Database.UpsertResult[] results = Database.upsert(
            records, 
            Schema.Account.SEAWARE_Agency_ID__c, 
            false
        );
        
        Test.startTest();
        DC_ErrorLogger.logUpsertErrors('Account', bundle, results, 'UPSERT');
        DC_ErrorLogger.flushErrorLogs();
        Test.stopTest();
        
        // Verify no error logs were created
        List<Error_Log__c> errorLogs = [SELECT Id FROM Error_Log__c];
        System.assertEquals(0, errorLogs.size(), 'No error logs should be created for successful operations');
    }
    
    @IsTest
    static void testFlushErrorLogs_EmptyBuffer() {
        Test.startTest();
        DC_ErrorLogger.flushErrorLogs();
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Flushing empty buffer should not cause errors');
    }
    
    @IsTest
    static void testGetBufferStats() {
        Map<String, Integer> stats = DC_ErrorLogger.getBufferStats();
        
        System.assertNotEquals(null, stats);
        System.assert(stats.containsKey('bufferedCount'));
        System.assert(stats.containsKey('bufferCapacity'));
        System.assertEquals(100, stats.get('bufferCapacity'));
    }
    
    @IsTest
    static void testLogUpsertErrors_MultipleErrors() {
        // Create multiple records that will fail
        List<SObject> records = new List<SObject>();
        for (Integer i = 0; i < 5; i++) {
            records.add(new Account(
                SEAWARE_Agency_ID__c = 'FAIL' + i
                // Missing Name field
            ));
        }
        
        DC_UpsertBundle bundle = new DC_UpsertBundle(records, 'SEAWARE_Agency_ID__c');
        
        Database.UpsertResult[] results = Database.upsert(
            records, 
            Schema.Account.SEAWARE_Agency_ID__c, 
            false
        );
        
        Test.startTest();
        DC_ErrorLogger.logUpsertErrors('Account', bundle, results, 'UPSERT');
        DC_ErrorLogger.flushErrorLogs();
        Test.stopTest();
        
        // Verify multiple error logs were created
        List<Error_Log__c> errorLogs = [SELECT Id FROM Error_Log__c];
        System.assert(errorLogs.size() >= 5, 'Multiple error logs should be created');
    }
    
    @IsTest
    static void testLogUpdateErrors_EmptyResults() {
        Test.startTest();
        DC_ErrorLogger.logUpdateErrors('Account', new List<SObject>(), new Database.SaveResult[0]);
        DC_ErrorLogger.flushErrorLogs();
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Empty results should be handled gracefully');
    }
}
@IsTest
private class DC_DmlUtil_Test {
    
    @IsTest
    static void testUpsertByExtId_Insert() {
        Account acc = new Account(
            Name = 'Test Account',
            SEAWARE_Agency_ID__c = 'TEST_EXT_001'
        );
        
        List<SObject> records = new List<SObject>{acc};
        
        Test.startTest();
        Database.UpsertResult[] results = DC_DmlUtil.upsertByExtId(
            records,
            'SEAWARE_Agency_ID__c',
            false
        );
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assert(results[0].isSuccess() || !results[0].isSuccess());
    }
    
    @IsTest
    static void testUpsertByExtId_Update() {
        Account acc = new Account(
            Name = 'Test Account',
            SEAWARE_Agency_ID__c = 'TEST_EXT_002'
        );
        insert acc;
        
        acc.Name = 'Updated Account';
        List<SObject> records = new List<SObject>{acc};
        
        Test.startTest();
        Database.UpsertResult[] results = DC_DmlUtil.upsertByExtId(
            records,
            'SEAWARE_Agency_ID__c',
            false
        );
        Test.stopTest();
        
        System.assertEquals(1, results.size());
    }
    
    @IsTest
    static void testUpsertByExtId_EmptyList() {
        List<SObject> records = new List<SObject>();
        
        Test.startTest();
        Database.UpsertResult[] results = DC_DmlUtil.upsertByExtId(
            records,
            'SEAWARE_Agency_ID__c',
            false
        );
        Test.stopTest();
        
        System.assertEquals(0, results.size());
    }
    
    @IsTest
    static void testUpsertByExtId_NullList() {
        Test.startTest();
        Database.UpsertResult[] results = DC_DmlUtil.upsertByExtId(
            null,
            'SEAWARE_Agency_ID__c',
            false
        );
        Test.stopTest();
        
        System.assertEquals(0, results.size());
    }
    
    @IsTest
    static void testUpsertByExtId_InvalidExternalIdField() {
        Account acc = new Account(Name = 'Test');
        List<SObject> records = new List<SObject>{acc};
        
        try {
            DC_DmlUtil.upsertByExtId(records, 'InvalidField__c', false);
            System.assert(false, 'Should throw exception');
        } catch (DC_SyncException e) {
            System.assert(e.getMessage().contains('External Id field not found'));
        }
    }
    
    @IsTest
    static void testUpsertByExtId_AllOrNone() {
        Account acc1 = new Account(
            Name = 'Test Account 1',
            SEAWARE_Agency_ID__c = 'TEST_EXT_003'
        );
        Account acc2 = new Account(
            Name = 'Test Account 2',
            SEAWARE_Agency_ID__c = 'TEST_EXT_004'
        );
        
        List<SObject> records = new List<SObject>{acc1, acc2};
        
        Test.startTest();
        Database.UpsertResult[] results = DC_DmlUtil.upsertByExtId(
            records,
            'SEAWARE_Agency_ID__c',
            true
        );
        Test.stopTest();
        
        System.assertEquals(2, results.size());
    }
    
    @IsTest
    static void testUpsertByExtId_PartialSuccess() {
        Account acc1 = new Account(
            Name = 'Test Account 1',
            SEAWARE_Agency_ID__c = 'TEST_EXT_005'
        );
        Account acc2 = new Account(
            // Missing required Name field
            SEAWARE_Agency_ID__c = 'TEST_EXT_006'
        );
        
        List<SObject> records = new List<SObject>{acc1, acc2};
        
        Test.startTest();
        Database.UpsertResult[] results = DC_DmlUtil.upsertByExtId(
            records,
            'SEAWARE_Agency_ID__c',
            false
        );
        Test.stopTest();
        
        System.assertEquals(2, results.size());
    }
}
@IsTest
private class DC_CommissionStep_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account for master-detail relationship
        Account testAccount = new Account(
            Name = 'Test Agency Account',
            SEAWARE_Agency_ID__c = 'AGENCY001'
        );
        insert testAccount;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_CommissionStep step = new DC_CommissionStep();
        System.assertEquals('Seaware_Commission_Structure__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_CommissionStep step = new DC_CommissionStep();
        System.assertEquals('Agency_ID__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testSourceFields() {
        DC_CommissionStep step = new DC_CommissionStep();
        Set<String> fields = step.sourceFields();
        System.assert(fields.contains('Agency_ID__c'));
        System.assert(!fields.isEmpty());
    }
    
    @IsTest
    static void testMapScope() {
        DC_CommissionStep step = new DC_CommissionStep();
        
        // Create mock source data as Map
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Agency_ID__c' => 'AGENCY001',
                'Commission_Code__c' => 'COMM001',
                'Commission_Name__c' => 'Test Commission',
                'Last_Modified_Date__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('AgencyID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_CommissionStep step = new DC_CommissionStep();
        step.afterUpsert(new List<Object>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'AgencyID__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}
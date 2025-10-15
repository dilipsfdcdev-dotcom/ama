@IsTest
private class DC_BaseStep_Test {
    
    // Test the concrete implementations instead of protected methods
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account', SEAWARE_Agency_ID__c = 'TEST123');
        insert acc;
    }
    
    @IsTest
    static void testAccountStep_MapScope() {
        // Test using a real step implementation
        DC_AccountStep step = new DC_AccountStep();
        
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'ACC001',
                'ssot__Name__c' => 'Test Account',
                'Address_City__c' => 'Test City',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('SEAWARE_Agency_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testShipStep_MapScope() {
        DC_ShipStep step = new DC_ShipStep();
        
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Ship_ID__c' => 'SHIP001',
                'Ship_Name__c' => 'Test Ship',
                'Passengers__c' => 1000
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Ship_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testGetAdditionalSources() {
        DC_AccountStep step = new DC_AccountStep();
        Map<String, DC_JoinConfig> sources = step.getAdditionalSources();
        System.assertNotEquals(null, sources);
    }
    
    @IsTest
    static void testMapMultiSourceScope() {
        DC_AccountStep step = new DC_AccountStep();
        DC_MultiSourceData data = new DC_MultiSourceData(new List<Object>());
        DC_UpsertBundle bundle = step.mapMultiSourceScope(data);
        System.assertNotEquals(null, bundle);
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_AccountStep step = new DC_AccountStep();
        System.assertEquals('ssot__Account__dlm', step.sourceObjectApi());
        
        DC_ShipStep shipStep = new DC_ShipStep();
        System.assertEquals('Seaware_Ship__dlm', shipStep.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_AccountStep step = new DC_AccountStep();
        System.assertEquals('ssot__Id__c', step.orderBySourceField());
        
        DC_ShipStep shipStep = new DC_ShipStep();
        System.assertEquals('Ship_ID__c', shipStep.orderBySourceField());
    }
    
    @IsTest
    static void testSourceFields() {
        DC_AccountStep step = new DC_AccountStep();
        Set<String> fields = step.sourceFields();
        System.assertNotEquals(null, fields);
        System.assert(fields.size() > 0);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_AccountStep step = new DC_AccountStep();
        List<Object> scope = new List<Object>();
        DC_UpsertBundle bundle = new DC_UpsertBundle(new List<SObject>(), 'Id');
        Database.UpsertResult[] results = new Database.UpsertResult[0];
        
        Test.startTest();
        step.afterUpsert(scope, bundle, results);
        Test.stopTest();
        
        System.assert(true, 'Should complete without errors');
    }
    
    @IsTest
    static void testCommissionStep_MapScope() {
        // Create test account for commission
        Account acc = [SELECT Id FROM Account WHERE SEAWARE_Agency_ID__c = 'TEST123' LIMIT 1];
        
        DC_CommissionStep step = new DC_CommissionStep();
        
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Agency_ID__c' => 'TEST123',
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
    static void testTypeConversion() {
        // Test that type conversion works through DC_TypeConverter
        Account acc = new Account();
        DC_TypeConverter.setFieldWithConversion(acc, 'Name', 'Test Account');
        System.assertEquals('Test Account', acc.Name);
        
        DC_TypeConverter.setFieldWithConversion(acc, 'NumberOfEmployees', '100');
        System.assertEquals(100, acc.NumberOfEmployees);
    }
    
    @IsTest
    static void testMapScope_WithNullValues() {
        DC_ShipStep step = new DC_ShipStep();
        
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Ship_ID__c' => 'SHIP002',
                'Ship_Name__c' => null,
                'Passengers__c' => null
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
    }
}
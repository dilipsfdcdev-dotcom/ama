@IsTest
private class DC_AccountStep_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account for parent relationship
        Account parentAccount = new Account(
            Name = 'Parent Test Account',
            SEAWARE_Agency_ID__c = 'PARENT123'
        );
        insert parentAccount;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_AccountStep step = new DC_AccountStep();
        System.assertEquals('ssot__Account__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_AccountStep step = new DC_AccountStep();
        System.assertEquals('ssot__Id__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testWhereClause() {
        DC_AccountStep step = new DC_AccountStep();
        String whereClause = step.whereClause();
        System.assert(whereClause.contains('ssot__DataSourceObjectId__c = \'Seaware_Account_E1C509FE\''));
        System.assert(whereClause.contains('ssot__LastModifiedDate__c = TODAY'));
    }
    
    @IsTest
    static void testSourceFields() {
        DC_AccountStep step = new DC_AccountStep();
        Set<String> fields = step.sourceFields();
        
        // Should include all mapped fields
        System.assert(fields.contains('ssot__Id__c'));
        System.assert(fields.contains('Parent_ID__c'));
        System.assert(fields.contains('Address_City__c'));
        System.assert(fields.contains('ssot__Name__c'));
    }
    
    @IsTest
    static void testMapScope_WithoutParent() {
        DC_AccountStep step = new DC_AccountStep();
        
        // Create mock source data
        Map<String, Object> sourceData = new Map<String, Object>{
            'ssot__Id__c' => 'TEST_ACCOUNT_001',
            'Address_City__c' => 'Test City',
            'ssot__Name__c' => 'Test Account',
            'Phone__c' => '555-1234',
            'Parent_ID__c' => null
        };
        
        // Create mock SObject using Map approach
        SObject mockSource = createMockSObject('ssot__Account__dlm', sourceData);
        List<SObject> scope = new List<SObject>{ mockSource };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('SEAWARE_Agency_ID__c', bundle.externalIdField);
        
        Account resultAccount = (Account) bundle.records[0];
        System.assertEquals('TEST_ACCOUNT_001', resultAccount.SEAWARE_Agency_ID__c);
        System.assertEquals('Test City', resultAccount.BillingCity);
        System.assertEquals('Test Account', resultAccount.Name);
        System.assertEquals('555-1234', resultAccount.Phone);
    }
    
    @IsTest
    static void testMapScope_WithParent() {
        DC_AccountStep step = new DC_AccountStep();
        
        // Create mock source data with parent reference
        Map<String, Object> sourceData = new Map<String, Object>{
            'ssot__Id__c' => 'TEST_ACCOUNT_002',
            'Address_City__c' => 'Test City 2',
            'ssot__Name__c' => 'Test Account 2',
            'Parent_ID__c' => 'PARENT123'
        };
        
        SObject mockSource = createMockSObject('ssot__Account__dlm', sourceData);
        List<SObject> scope = new List<SObject>{ mockSource };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        Account resultAccount = (Account) bundle.records[0];
        System.assertEquals('TEST_ACCOUNT_002', resultAccount.SEAWARE_Agency_ID__c);
        System.assertNotEquals(null, resultAccount.Host_Account__c);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_AccountStep step = new DC_AccountStep();
        List<SObject> scope = new List<SObject>();
        DC_UpsertBundle bundle = new DC_UpsertBundle(new List<SObject>(), 'SEAWARE_Agency_ID__c');
        Database.UpsertResult[] results = new Database.UpsertResult[0];
        
        // Should not throw exception
        Test.startTest();
        step.afterUpsert(scope, bundle, results);
        Test.stopTest();
        
        // No assertions needed as it's a no-op method
    }
    
    // Helper method to create mock SObjects
    private static SObject createMockSObject(String objectType, Map<String, Object> fieldValues) {
        String jsonString = JSON.serialize(fieldValues);
        Map<String, Object> populatedFieldsMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        
        // Create a generic SObject and populate fields
        SObject obj = Schema.getGlobalDescribe().get('Account').newSObject();
        for (String field : fieldValues.keySet()) {
            try {
                obj.put(field, fieldValues.get(field));
            } catch (Exception e) {
                // Skip fields that don't exist on the target object
                System.debug('Field not found: ' + field);
            }
        }
        return obj;
    }
}
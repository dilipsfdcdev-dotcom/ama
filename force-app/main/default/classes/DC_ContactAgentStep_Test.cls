@IsTest
private class DC_ContactAgentStep_Test {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Agency',
            SEAWARE_Agency_ID__c = 'AGENCY123'
        );
        insert testAccount;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        System.assertEquals('ssot__Individual__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        System.assertEquals('ssot__Id__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testWhereClause() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        String whereClause = step.whereClause();
        System.assert(whereClause.contains('ssot__DataSourceObjectId__c = \'Seaware_Agent_E1C50A02\''));
        // Just verify it contains the field name
        System.assert(whereClause.contains('ssot__LastModifiedDate__c'));
    }
    
    @IsTest
    static void testSourceFields() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        Set<String> fields = step.sourceFields();
        
        System.assert(fields.contains('ssot__Id__c'));
        System.assert(fields.contains('ssot__PartyId__c'));
        System.assert(fields.contains('ssot__FirstName__c'));
        System.assert(fields.contains('ssot__LastName__c'));
    }
    
    @IsTest
    static void testGetAdditionalSources() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        Map<String, DC_JoinConfig> additionalSources = step.getAdditionalSources();
        
        // Agent step now uses separate CDP queries, not join configs
        System.assertEquals(0, additionalSources.size());
    }
    
    @IsTest
    static void testMapScope() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        
        // Create mock source data as Map
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Agent_ID__c' => 'AGENT001',
                'ssot__PartyId__c' => 'PARTY001',
                'ssot__FirstName__c' => 'John',
                'ssot__LastName__c' => 'Agent',
                'Agency_ID__c' => 'AGENCY123',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Agent_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        
        // Should not throw exception
        Test.startTest();
        step.afterUpsert(new List<Object>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Agent_ID__c'), 
                        new Database.UpsertResult[0]);
        Test.stopTest();
    }
}
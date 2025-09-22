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
        System.assert(whereClause.contains('ssot__LastModifiedDate__c = TODAY'));
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
        
        System.assertEquals(3, additionalSources.size());
        System.assert(additionalSources.containsKey('email'));
        System.assert(additionalSources.containsKey('phone'));
        System.assert(additionalSources.containsKey('address'));
        
        DC_JoinConfig emailConfig = additionalSources.get('email');
        System.assertEquals('ssot__ContactPointEmail__dlm', emailConfig.sourceObject);
        System.assertEquals('ssot__PartyId__c', emailConfig.joinField);
        System.assertEquals('ssot__PartyId__c', emailConfig.parentField);
    }
    
    @IsTest
    static void testMapMultiSourceScope() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        
        Map<String, Object> agentData = new Map<String, Object>{
            'Agent_ID__c' => 'AGENT001',
            'ssot__PartyId__c' => 'PARTY001',
            'ssot__FirstName__c' => 'John',
            'ssot__LastName__c' => 'Agent',
            'Agency_ID__c' => 'AGENCY123'
        };
        
        Contact mockAgent = new Contact();
        for (String field : agentData.keySet()) {
            try { 
                mockAgent.put(field, agentData.get(field)); 
            } catch (Exception e) {
                System.debug('Field not accessible in test: ' + field);
            }
        }
        
        DC_MultiSourceData data = new DC_MultiSourceData(new List<SObject>{ mockAgent });
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapMultiSourceScope(data);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Agent_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_ContactAgentStep step = new DC_ContactAgentStep();
        
        // Should not throw exception
        Test.startTest();
        step.afterUpsert(new List<SObject>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Agent_ID__c'), 
                        new Database.UpsertResult[0]);
        Test.stopTest();
    }
}
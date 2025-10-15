@IsTest
private class DC_OpportunityStep_Test {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account',
            SEAWARE_Agency_ID__c = 'ACC123'
        );
        insert testAccount;
        
        Ship__c testShip = new Ship__c(
            Name = 'Test Ship',
            Ship_Code__c = 'SHIP123',
            Ship_ID__c = 'SHIP123'
        );
        insert testShip;
        
        Sailing__c testSailing = new Sailing__c(
            Name = 'Test Sailing',
            Sailing_Code__c = 'SAIL123',
            Ship__c = testShip.Id
        );
        insert testSailing;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_OpportunityStep step = new DC_OpportunityStep();
        System.assertEquals('ssot__Opportunity__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_OpportunityStep step = new DC_OpportunityStep();
        System.assertEquals('Group_Id__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testWhereClause() {
        DC_OpportunityStep step = new DC_OpportunityStep();
        String whereClause = step.whereClause();
        System.assert(whereClause.contains('ssot__DataSourceObjectId__c = \'Seaware_Opportunity_E1C50A03\''));
        // Just verify it contains the field name
        System.assert(whereClause.contains('ssot__LastModifiedDate__c'));
    }
    
    @IsTest
    static void testSourceFields() {
        DC_OpportunityStep step = new DC_OpportunityStep();
        Set<String> fields = step.sourceFields();
        System.assert(fields.contains('Group_Id__c'));
        System.assert(fields.contains('Sailing__c'));
        System.assert(fields.contains('Agent_ID__c'));
    }
    
    @IsTest
    static void testMapScope() {
        DC_OpportunityStep step = new DC_OpportunityStep();
        
        // Create mock source data as Map
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Group_Id__c' => 'GROUP001',
                'SEAWARE_Agency_ID__c' => 'ACC123',
                'Sailing__c' => 'SAIL123',
                'ssot__OpportunityName__c' => 'Test Opportunity',
                'ssot__OpportunityStageId__c' => 'Prospecting',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Group_Id__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_OpportunityStep step = new DC_OpportunityStep();
        step.afterUpsert(new List<Object>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Group_Id__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}
@IsTest
private class DC_ShipStep_Test {
    
    @IsTest
    static void testSourceObjectApi() {
        DC_ShipStep step = new DC_ShipStep();
        System.assertEquals('Seaware_Ship__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_ShipStep step = new DC_ShipStep();
        System.assertEquals('Ship_ID__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testSourceFields() {
        DC_ShipStep step = new DC_ShipStep();
        Set<String> fields = step.sourceFields();
        System.assert(fields.contains('Ship_ID__c'));
        System.assert(fields.contains('Ship_Code__c'));
        System.assert(!fields.isEmpty());
    }
    
    @IsTest
    static void testMapScope() {
        DC_ShipStep step = new DC_ShipStep();
        
        // Create mock source data as Map
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Ship_ID__c' => 'SHIP001',
                'Ship_Code__c' => 'SHIP_CODE_001',
                'Ship_Name__c' => 'Test Ship',
                'Passengers__c' => 1000,
                'Staterooms__c' => 500
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        // The external ID field is Ship_ID__c, not Ship_Code__c
        System.assertEquals('Ship_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_ShipStep step = new DC_ShipStep();
        step.afterUpsert(new List<Object>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Ship_ID__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}
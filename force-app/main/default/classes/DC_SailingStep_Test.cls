@IsTest
private class DC_SailingStep_Test {
    
    @TestSetup
    static void setupTestData() {
        Ship__c testShip = new Ship__c(
            Name = 'Test Ship',
            Ship_Code__c = 'SHIP123'
        );
        insert testShip;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_SailingStep step = new DC_SailingStep();
        System.assertEquals('Seaware_Sailing__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_SailingStep step = new DC_SailingStep();
        System.assertEquals('Sailing_Code__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testSourceFields() {
        DC_SailingStep step = new DC_SailingStep();
        Set<String> fields = step.sourceFields();
        System.assert(fields.contains('Sailing_Code__c'));
        System.assert(fields.contains('Ship_ID__c'));
        System.assert(!fields.isEmpty());
    }
    
    @IsTest
    static void testMapScope() {
        DC_SailingStep step = new DC_SailingStep();
        
        Map<String, Object> sailingData = new Map<String, Object>{
            'Sailing_Code__c' => 'SAIL001',
            'Ship_ID__c' => 'SHIP123',
            'Name__c' => 'Test Sailing',
            'Is_Active__c' => true
        };
        
        SObject mockSailing = Schema.getGlobalDescribe().get('Account').newSObject();
        for (String field : sailingData.keySet()) {
            try { 
                mockSailing.put(field, sailingData.get(field)); 
            } catch (Exception e) {
                System.debug('Field not accessible: ' + field);
            }
        }
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(new List<SObject>{ mockSailing });
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Sailing_Code__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_SailingStep step = new DC_SailingStep();
        step.afterUpsert(new List<SObject>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Sailing_Code__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}
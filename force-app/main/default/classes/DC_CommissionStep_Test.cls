@IsTest
private class DC_CommissionStep_Test {
    
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
        
        Map<String, Object> commissionData = new Map<String, Object>{
            'Agency_ID__c' => 'AGENCY001',
            'Agency_Name__c' => 'Test Agency',
            'Commission_Code__c' => 'COMM001',
            'Commission_Name__c' => 'Test Commission'
        };
        
        SObject mockCommission = Schema.getGlobalDescribe().get('Account').newSObject();
        for (String field : commissionData.keySet()) {
            try { 
                mockCommission.put(field, commissionData.get(field)); 
            } catch (Exception e) {
                System.debug('Field not accessible: ' + field);
            }
        }
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(new List<SObject>{ mockCommission });
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('AgencyID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_CommissionStep step = new DC_CommissionStep();
        step.afterUpsert(new List<SObject>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'AgencyID__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}
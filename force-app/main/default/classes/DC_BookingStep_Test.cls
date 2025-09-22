@IsTest
private class DC_BookingStep_Test {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account',
            SEAWARE_Agency_ID__c = 'ACC123'
        );
        insert testAccount;
        
        Contact testAgent = new Contact(
            FirstName = 'Test',
            LastName = 'Agent',
            Agent_ID__c = 'AGENT123'
        );
        insert testAgent;
        
        Contact testClient = new Contact(
            FirstName = 'Test',
            LastName = 'Client',
            Client_ID__c = 'CLIENT123'
        );
        insert testClient;
        
        Ship__c testShip = new Ship__c(
            Name = 'Test Ship',
            Ship_Code__c = 'SHIP123'
        );
        insert testShip;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_BookingStep step = new DC_BookingStep();
        System.assertEquals('Seaware_Booking__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_BookingStep step = new DC_BookingStep();
        System.assertEquals('Res_ID__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testSourceFields() {
        DC_BookingStep step = new DC_BookingStep();
        Set<String> fields = step.sourceFields();
        System.assert(fields.contains('Res_ID__c'));
        System.assert(!fields.isEmpty());
    }
    
    @IsTest
    static void testMapScope() {
        DC_BookingStep step = new DC_BookingStep();
        
        Map<String, Object> bookingData = new Map<String, Object>{
            'Res_ID__c' => 'BOOKING001',
            'Account_ID__c' => 'ACC123',
            'Agent_ID__c' => 'AGENT123',
            'Primary_Passenger__c' => 'CLIENT123',
            'Ship__c' => 'SHIP123',
            'Booking_Date__c' => Date.today()
        };
        
        SObject mockBooking = Schema.getGlobalDescribe().get('Opportunity').newSObject();
        for (String field : bookingData.keySet()) {
            try { 
                mockBooking.put(field, bookingData.get(field)); 
            } catch (Exception e) {
                System.debug('Field not accessible: ' + field);
            }
        }
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(new List<SObject>{ mockBooking });
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Booking_Number__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_BookingStep step = new DC_BookingStep();
        step.afterUpsert(new List<SObject>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Booking_Number__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}
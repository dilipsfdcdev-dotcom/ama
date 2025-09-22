@IsTest
private class DC_ReservationStep_Test {
    
    @TestSetup
    static void setupTestData() {
        Contact testClient = new Contact(
            FirstName = 'Test',
            LastName = 'Client',
            Client_ID__c = 'CLIENT123'
        );
        insert testClient;
        
        Booking__c testBooking = new Booking__c(
            Booking_Number__c = 'BOOKING123'
        );
        insert testBooking;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_ReservationStep step = new DC_ReservationStep();
        System.assertEquals('Seaware_Reservation__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_ReservationStep step = new DC_ReservationStep();
        System.assertEquals('Guest_ID__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testSourceFields() {
        DC_ReservationStep step = new DC_ReservationStep();
        Set<String> fields = step.sourceFields();
        System.assert(fields.contains('Guest_ID__c'));
        System.assert(!fields.isEmpty());
    }
    
    @IsTest
    static void testMapScope() {
        DC_ReservationStep step = new DC_ReservationStep();
        
        Map<String, Object> reservationData = new Map<String, Object>{
            'Guest_ID__c' => 'GUEST001',
            'SF_Booking_ID__c' => 'BOOKING123',
            'Client_Name_ID__c' => 'CLIENT123',
            'Name__c' => 'Test Reservation'
        };
        
        SObject mockReservation = Schema.getGlobalDescribe().get('Account').newSObject();
        for (String field : reservationData.keySet()) {
            try { 
                mockReservation.put(field, reservationData.get(field)); 
            } catch (Exception e) {
                System.debug('Field not accessible: ' + field);
            }
        }
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(new List<SObject>{ mockReservation });
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Guest_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_ReservationStep step = new DC_ReservationStep();
        step.afterUpsert(new List<SObject>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Guest_ID__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}

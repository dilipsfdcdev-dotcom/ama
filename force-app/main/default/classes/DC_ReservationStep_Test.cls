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
        
        // Create Ship first
        Ship__c testShip = new Ship__c(
            Name = 'Test Ship',
            Ship_Code__c = 'SHIP123',
            Ship_ID__c = 'SHIP123'
        );
        insert testShip;
        
        // Create Sailing with required field
        Sailing__c testSailing = new Sailing__c(
            Name = 'Test Sailing',
            Sailing_Code__c = 'SAIL123',
            Ship__c = testShip.Id
        );
        insert testSailing;
        
        // Create Booking with required Sailing_Name__c field
        Booking__c testBooking = new Booking__c(
            Booking_Number__c = 'BOOKING123',
            Sailing_Name__c = testSailing.Id
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
        
        // Create mock source data as Map
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Guest_ID__c' => 'GUEST001',
                'Booking_ID__c' => 'BOOKING123',
                'Client_ID__c' => 'CLIENT123',
                'Name__c' => 'Test Reservation'
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Guest_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_ReservationStep step = new DC_ReservationStep();
        step.afterUpsert(new List<Object>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Guest_ID__c'),
                        new Database.UpsertResult[0]);
        System.assert(true); // Should not throw exception
    }
}
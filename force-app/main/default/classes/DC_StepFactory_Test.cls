@IsTest
private class DC_StepFactory_Test {
    
    @IsTest
    static void testMakeAccount() {
        DC_IStep step = DC_StepFactory.make('Account');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_AccountStep);
    }
    
    @IsTest
    static void testMakeCommission() {
        DC_IStep step = DC_StepFactory.make('Commission');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_CommissionStep);
    }
    
    @IsTest
    static void testMakeAgent() {
        DC_IStep step = DC_StepFactory.make('Agent');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_ContactAgentStep);
    }
    
    @IsTest
    static void testMakeClient() {
        DC_IStep step = DC_StepFactory.make('Client');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_ContactClientStep);
    }
    
    @IsTest
    static void testMakeShip() {
        DC_IStep step = DC_StepFactory.make('Ship');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_ShipStep);
    }
    
    @IsTest
    static void testMakeSailing() {
        DC_IStep step = DC_StepFactory.make('Sailing');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_SailingStep);
    }
    
    @IsTest
    static void testMakeOpportunity() {
        DC_IStep step = DC_StepFactory.make('Opportunity');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_OpportunityStep);
    }
    
    @IsTest
    static void testMakeBooking() {
        DC_IStep step = DC_StepFactory.make('Booking');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_BookingStep);
    }
    
    @IsTest
    static void testMakeReservation() {
        DC_IStep step = DC_StepFactory.make('Reservation');
        System.assertNotEquals(null, step);
        System.assert(step instanceof DC_ReservationStep);
    }
    
    @IsTest
    static void testMakeInvalid() {
        DC_IStep step = DC_StepFactory.make('InvalidStep');
        System.assertEquals(null, step);
    }
    
    @IsTest
    static void testMakeNull() {
        DC_IStep step = DC_StepFactory.make(null);
        System.assertEquals(null, step);
    }
    
    @IsTest
    static void testMakeEmptyString() {
        DC_IStep step = DC_StepFactory.make('');
        System.assertEquals(null, step);
    }
}
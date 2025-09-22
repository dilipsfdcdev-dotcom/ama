public with sharing class DC_StepFactory {
    public static DC_IStep make(String name) {
        if (name == 'Account')         return new DC_AccountStep();
        if (name == 'Commission')      return new DC_CommissionStep();
        if (name == 'ContactAgent')    return new DC_ContactAgentStep();
        if (name == 'ContactClient')   return new DC_ContactClientStep();
        if (name == 'Ship')            return new DC_ShipStep();
        if (name == 'Sailing')         return new DC_SailingStep();
        if (name == 'Opportunity')     return new DC_OpportunityStep();
        if (name == 'Booking')         return new DC_BookingStep();
        if (name == 'Reservation')     return new DC_ReservationStep();
        
        return null;
    }
}
public with sharing class DC_ReservationStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'Seaware_Reservation__dlm';
    private static final String ORDER_BY_SRC = 'Guest_ID__c';
    private static final String RESERVATION_EXTID = 'Guest_ID__c';
    private static final String TGT_OBJECT = 'Reservation__c';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
       return 'Last_Modified_Date__c = TODAY';
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.RESERVATION_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        return f;
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();

        // Bulk resolve Booking by external id
        Set<String> bookingKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('SF_Booking_ID__c');
            if (!String.isBlank(k)) bookingKeys.add(k);
        }
        Map<String, Id> bookingByExt = new Map<String, Id>();
        if (!bookingKeys.isEmpty()) {
            for (Booking__c b : [
                SELECT Id, Booking_Number__c
                FROM Booking__c
                WHERE Booking_Number__c IN :bookingKeys
            ]) {
                bookingByExt.put(b.Booking_Number__c, b.Id);
            }
        }

        // Bulk resolve Contact (Client) by external id
        Set<String> clientKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Client_Name_ID__c');
            if (!String.isBlank(k)) clientKeys.add(k);
        }
        Map<String, Id> clientByExt = new Map<String, Id>();
        if (!clientKeys.isEmpty()) {
            for (Contact c : [
                SELECT Id, Client_ID__c
                FROM Contact
                WHERE Client_ID__c IN :clientKeys
                AND RecordType.Name = 'Client'
            ]) {
                clientByExt.put(c.Client_ID__c, c.Id);
            }
        }
        
        for (SObject src : scope) {
            SObject reservation = t.newSObject();
            reservation.put(RESERVATION_EXTID, (String)src.get(ORDER_BY_SRC));
            
            for (DC_FieldMap m : DC_Mappings.RESERVATION_MAP) {
                if (m.tgt == 'BookingID__c') {
                    // Handle Booking lookup
                    String bookingKey = (String)src.get('SF_Booking_ID__c');
                    if (!String.isBlank(bookingKey)) {
                        Id bookingId = bookingByExt.get(bookingKey);
                        if (bookingId != null) {
                            reservation.put(m.tgt, bookingId);
                        }
                    }
                } else if (m.tgt == 'Client_NameID__c') {
                    // Handle Client lookup
                    String clientKey = (String)src.get('Client_Name_ID__c');
                    if (!String.isBlank(clientKey)) {
                        Id clientId = clientByExt.get(clientKey);
                        if (clientId != null) {
                            reservation.put(m.tgt, clientId);
                        }
                    }
                } else {
                    Object value = src.get(m.src);
                    if (value != null) {
                        reservation.put(m.tgt, value);
                    }
                }
            }
            out.add(reservation);
        }
        return new DC_UpsertBundle(out, RESERVATION_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
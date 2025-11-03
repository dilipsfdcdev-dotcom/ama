public with sharing class DC_ReservationStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'Seaware_Reservation__dlm';
    private static final String ORDER_BY_SRC = 'Guest_ID__c';
    private static final String RESERVATION_EXTID = 'Guest_ID__c';
    private static final String TGT_OBJECT = 'Reservation__c';
    private static final String STEP_NAME = 'Reservation';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME);
        String dataSourceObjectId = DC_DateUtil.getDataSourceObjectId(STEP_NAME);
        
        if (String.isBlank(dataSourceObjectId)) {
            System.debug(LoggingLevel.ERROR, 'DataSourceObjectId not found for step: ' + STEP_NAME);
            return dateFilter;
        }
        
        return 'DataSourceObject__c = \'' + dataSourceObjectId + '\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.RESERVATION_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        return f;
    }

    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();

        // Bulk resolve Booking by external id
        Set<String> bookingKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Booking_ID__c');
            if (!String.isBlank(k)) bookingKeys.add(k);
        }
        Map<String, Id> bookingByExt = bulkLookupByExternalId('Booking__c', 'Booking_Number__c', bookingKeys);

        // Bulk resolve Contact (Client) by external id
        Set<String> clientKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Client_ID__c');
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
        
        for (Object src : scope) {
            SObject reservation = t.newSObject();
            String guestId = (String) getFieldValue(src, ORDER_BY_SRC);
            setFieldValue(reservation, RESERVATION_EXTID, guestId);
            
            for (DC_FieldMap m : DC_Mappings.RESERVATION_MAP) {
                if (m.tgt == 'BookingID__c') {
                    // Handle Booking lookup
                    String bookingKey = (String) getFieldValue(src, 'Booking_ID__c');
                    if (!String.isBlank(bookingKey)) {
                        Id bookingId = bookingByExt.get(bookingKey);
                        if (bookingId != null) {
                            setFieldValue(reservation, m.tgt, bookingId);
                        }
                    }
                } else if (m.tgt == 'Client_NameID__c') {
                    // Handle Client lookup
                    String clientKey = (String) getFieldValue(src, 'Client_ID__c');
                    if (!String.isBlank(clientKey)) {
                        Id clientId = clientByExt.get(clientKey);
                        if (clientId != null) {
                            setFieldValue(reservation, m.tgt, clientId);
                        }
                    }
                } else {
                    // UPDATED: Simplified - setFieldValue now handles type conversion automatically!
                    Object value = getFieldValue(src, m.src);
                    if (value != null) {
                        setFieldValue(reservation, m.tgt, value);
                    }
                }
            }
            out.add(reservation);
        }
        return new DC_UpsertBundle(out, RESERVATION_EXTID);
    }

    public override void afterUpsert(Object scopeObj, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
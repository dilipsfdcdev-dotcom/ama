public with sharing class DC_ReservationStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'Seaware_Reservation__dlm';
    private static final String ORDER_BY_SRC = 'Guest_ID__c';
    private static final String RESERVATION_EXTID = 'Guest_ID__c';
    private static final String TGT_OBJECT = 'Reservation__c';
    private static final String STEP_NAME = 'Reservation';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        return DC_DateUtil.getDateFilterClause(STEP_NAME);
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
            String k = (String) getFieldValue(src, 'Booking_ID__c');
            if (!String.isBlank(k)) bookingKeys.add(k);
        }
        Map<String, Id> bookingByExt = bulkLookupByExternalId('Booking__c', 'Booking_Number__c', bookingKeys);

        // Bulk resolve Contact (Client) by external id
        Set<String> clientKeys = new Set<String>();
        for (SObject src : scope) {
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
        
        for (SObject src : scope) {
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
                    // Handle data type conversion safely
                    Object value = getFieldValue(src, m.src);
                    if (value != null) {
                        Object convertedValue = convertDataTypeLocal(value, m.tgt, reservation);
                        if (convertedValue != null) {
                            setFieldValue(reservation, m.tgt, convertedValue);
                        }
                    }
                }
            }
            out.add(reservation);
        }
        return new DC_UpsertBundle(out, RESERVATION_EXTID);
    }

    /**
     * Convert source value to appropriate target field type - LOCAL METHOD
     */
    private Object convertDataTypeLocal(Object sourceValue, String targetFieldName, SObject targetRecord) {
        if (sourceValue == null) return null;
        
        try {
            // Get target field type from schema
            Schema.SObjectType targetType = targetRecord.getSObjectType();
            Schema.DescribeSObjectResult describe = targetType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
            
            Schema.SObjectField targetField = fieldMap.get(targetFieldName);
            if (targetField == null) {
                System.debug('Target field not found: ' + targetFieldName);
                return sourceValue; // Return as-is if field not found
            }
            
            Schema.DescribeFieldResult fieldDescribe = targetField.getDescribe();
            Schema.DisplayType targetFieldType = fieldDescribe.getType();
            
            // Convert based on target field type
            switch on targetFieldType {
                when STRING, TEXTAREA, PICKLIST, MULTIPICKLIST, EMAIL, PHONE, URL {
                    return String.valueOf(sourceValue);
                }
                when INTEGER {
                    return convertToIntegerLocal(sourceValue);
                }
                when DOUBLE, CURRENCY, PERCENT {
                    return convertToDecimalLocal(sourceValue);
                }
                when BOOLEAN {
                    return convertToBooleanLocal(sourceValue);
                }
                when DATE {
                    return convertToDate(sourceValue);
                }
                when DATETIME {
                    return convertToDateTime(sourceValue);
                }
                when ID, REFERENCE {
                    // For lookup fields, return as-is (should be handled in specific lookup logic above)
                    return sourceValue;
                }
                when else {
                    // For unknown types, return as-is
                    System.debug('Unknown target field type for ' + targetFieldName + ': ' + targetFieldType);
                    return sourceValue;
                }
            }
        } catch (Exception e) {
            System.debug('Error converting data type for field ' + targetFieldName + ': ' + e.getMessage());
            System.debug('Source value: ' + sourceValue + ' (Type: ' + String.valueOf(sourceValue));
            return null; // Return null to skip this field assignment
        }
    }
    
    private Integer convertToIntegerLocal(Object value) {
        if (value == null) return null;
        if (value instanceof Integer) return (Integer)value;
        if (value instanceof Decimal) return ((Decimal)value).intValue();
        if (value instanceof String) {
            try {
                return Integer.valueOf((String)value);
            } catch (Exception e) {
                System.debug('Cannot convert string to integer: ' + value);
                return null;
            }
        }
        return null;
    }
    
    private Decimal convertToDecimalLocal(Object value) {
        if (value == null) return null;
        if (value instanceof Decimal) return (Decimal)value;
        if (value instanceof Integer) return Decimal.valueOf((Integer)value);
        if (value instanceof String) {
            try {
                return Decimal.valueOf((String)value);
            } catch (Exception e) {
                System.debug('Cannot convert string to decimal: ' + value);
                return null;
            }
        }
        return null;
    }
    
    private Boolean convertToBooleanLocal(Object value) {
        if (value == null) return null;
        if (value instanceof Boolean) return (Boolean)value;
        if (value instanceof String) {
            String strValue = ((String)value).toLowerCase();
            if (strValue == 'true' || strValue == '1' || strValue == 'yes') return true;
            if (strValue == 'false' || strValue == '0' || strValue == 'no') return false;
        }
        if (value instanceof Integer) {
            return ((Integer)value) != 0;
        }
        if (value instanceof Decimal) {
            return ((Decimal)value) != 0;
        }
        return null;
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
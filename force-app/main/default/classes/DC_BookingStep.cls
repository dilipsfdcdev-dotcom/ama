public with sharing class DC_BookingStep extends DC_BaseStep implements DC_IWhere{

    private static final String SRC_OBJECT = 'Seaware_Booking__dlm';
    private static final String ORDER_BY_SRC = 'Res_ID__c';
    private static final String BOOKING_EXTID = 'Booking_Number__c';
    private static final String TGT_OBJECT = 'Booking__c';
    private static final String STEP_NAME = 'Booking';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME);
        String dataSourceObjectId = DC_DateUtil.getDataSourceObjectId(STEP_NAME);
        
        if (String.isBlank(dataSourceObjectId)) {
            System.debug(LoggingLevel.ERROR, 'DataSourceObjectId not found for step: ' + STEP_NAME);
            return dateFilter;
        }
        
        return 'ssot__DataSourceObjectId__c = \'' + dataSourceObjectId + '\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.BOOKING_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        return f;
    }

    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();

        // Bulk resolve Account by external id
        Set<String> accountKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Account_ID__c');
            if (!String.isBlank(k)) accountKeys.add(k);
        }
        Map<String, Id> accountByExt = bulkLookupByExternalId('Account', 'SEAWARE_Agency_ID__c', accountKeys);

        // Bulk resolve Opportunity by external id
        Set<String> oppKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Group_ID__c');
            if (!String.isBlank(k)) oppKeys.add(k);
        }
        Map<String, Id> oppByExt = bulkLookupByExternalId('Opportunity', 'Group_Id__c', oppKeys);

        // Bulk resolve Ship by external id (using Ship_Code)
        Set<String> shipKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Ship__c');
            if (!String.isBlank(k)) shipKeys.add(k);
        }
        Map<String, Id> shipByExt = bulkLookupByExternalId('Ship__c', 'Ship_Code__c', shipKeys);

        // FIX: Bulk resolve Sailing by external id (using Sailing_Code__c)
        Set<String> sailingKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Sailing_ID__c');
            if (!String.isBlank(k)) sailingKeys.add(k);
        }
        Map<String, Id> sailingByExt = bulkLookupByExternalId('Sailing__c', 'Sailing_Code__c', sailingKeys);

        // Bulk resolve Contact (Client) by external id for Primary Passenger
        Set<String> clientKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Primary_Passenger__c');
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

        // Bulk resolve Contact (Agent) by external id
        Set<String> agentKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Agent_ID__c');
            if (!String.isBlank(k)) agentKeys.add(k);
        }
        Map<String, Id> agentByExt = new Map<String, Id>();
        if (!agentKeys.isEmpty()) {
            for (Contact c : [
                SELECT Id, Agent_ID__c
                FROM Contact
                WHERE Agent_ID__c IN :agentKeys
                AND RecordType.Name = 'Agent'
            ]) {
                agentByExt.put(c.Agent_ID__c, c.Id);
            }
        }
        
        for (Object src : scope) {
            SObject booking = t.newSObject();
            String bookingNumber = (String) getFieldValue(src, ORDER_BY_SRC);
            setFieldValue(booking, BOOKING_EXTID, bookingNumber);
            
            for (DC_FieldMap m : DC_Mappings.BOOKING_MAP) {
                if (m.tgt == 'Agency__c') {
                    // Handle Account lookup
                    String accountKey = (String) getFieldValue(src, 'Account_ID__c');
                    if (!String.isBlank(accountKey)) {
                        Id accountId = accountByExt.get(accountKey);
                        if (accountId != null) {
                            setFieldValue(booking, m.tgt, accountId);
                        }
                    }
                } else if (m.tgt == 'Opportunity__c') {
                    // Handle Opportunity lookup
                    String oppKey = (String) getFieldValue(src, 'Opportunity__c');
                    if (!String.isBlank(oppKey)) {
                        Id oppId = oppByExt.get(oppKey);
                        if (oppId != null) {
                            setFieldValue(booking, m.tgt, oppId);
                        }
                    }
                } else if (m.tgt == 'Ship__c') {
                    // Handle Ship lookup
                    String shipKey = (String) getFieldValue(src, 'Ship__c');
                    if (!String.isBlank(shipKey)) {
                        Id shipId = shipByExt.get(shipKey);
                        if (shipId != null) {
                            setFieldValue(booking, m.tgt, shipId);
                        }
                    }
                } else if (m.tgt == 'Sailing_Name__c') {
                    // FIX: Handle Sailing lookup using Sailing_ID__c source field
                    String sailingKey = (String) getFieldValue(src, 'Sailing_ID__c');
                    if (!String.isBlank(sailingKey)) {
                        Id sailingId = sailingByExt.get(sailingKey);
                        if (sailingId != null) {
                            setFieldValue(booking, m.tgt, sailingId);
                        }
                    }
                } else if (m.tgt == 'Primary_Passenger__c') {
                    // Handle Client lookup
                    String clientKey = (String) getFieldValue(src, 'Primary_Passenger__c');
                    if (!String.isBlank(clientKey)) {
                        Id clientId = clientByExt.get(clientKey);
                        if (clientId != null) {
                            setFieldValue(booking, m.tgt, clientId);
                        }
                    }
                } else if (m.tgt == 'Travel_Agent__c') {
                    // Handle Agent lookup
                    String agentKey = (String) getFieldValue(src, 'Agent_ID__c');
                    if (!String.isBlank(agentKey)) {
                        Id agentId = agentByExt.get(agentKey);
                        if (agentId != null) {
                            setFieldValue(booking, m.tgt, agentId);
                        }
                    }
                } else {
                    Object value = getFieldValue(src, m.src);
                    if (value != null) {
                        setFieldValue(booking, m.tgt, value);
                    }
                }
            }
            out.add(booking);
        }
        return new DC_UpsertBundle(out, BOOKING_EXTID);
    }

    public override void afterUpsert(Object scopeObj, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
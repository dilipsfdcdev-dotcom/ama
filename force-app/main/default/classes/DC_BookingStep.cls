public with sharing class DC_BookingStep extends DC_BaseStep implements DC_IWhere{

    private static final String SRC_OBJECT = 'Seaware_Booking__dlm';
    private static final String ORDER_BY_SRC = 'Res_ID__c';
    private static final String BOOKING_EXTID = 'Booking_Number__c';
    private static final String TGT_OBJECT = 'Booking__c';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
       return 'Last_Modified_Date__c = TODAY';
    }


    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.BOOKING_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        return f;
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(TGT_OBJECT);
        List<SObject> out = new List<SObject>();

        // Bulk resolve Account by external id
        Set<String> accountKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Account_ID__c');
            if (!String.isBlank(k)) accountKeys.add(k);
        }
        Map<String, Id> accountByExt = new Map<String, Id>();
        if (!accountKeys.isEmpty()) {
            for (Account a : [
                SELECT Id, SEAWARE_Agency_ID__c
                FROM Account
                WHERE SEAWARE_Agency_ID__c IN :accountKeys
            ]) {
                accountByExt.put(a.SEAWARE_Agency_ID__c, a.Id);
            }
        }

        // Bulk resolve Opportunity by external id
        Set<String> oppKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Group_ID__c');
            if (!String.isBlank(k)) oppKeys.add(k);
        }
        Map<String, Id> oppByExt = new Map<String, Id>();
        if (!oppKeys.isEmpty()) {
            for (Opportunity o : [
                SELECT Id, Group_Id__c
                FROM Opportunity
                WHERE Group_Id__c IN :oppKeys
            ]) {
                oppByExt.put(o.Group_Id__c, o.Id);
            }
        }

        // Bulk resolve Ship by external id (using Ship_Code)
        Set<String> shipKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Ship__c');
            if (!String.isBlank(k)) shipKeys.add(k);
        }
        Map<String, Id> shipByExt = new Map<String, Id>();
        if (!shipKeys.isEmpty()) {
            for (Ship__c s : [
                SELECT Id, Ship_Code__c
                FROM Ship__c
                WHERE Ship_Code__c IN :shipKeys
            ]) {
                shipByExt.put(s.Ship_Code__c, s.Id);
            }
        }

        // Bulk resolve Contact (Client) by external id for Primary Passenger
        Set<String> clientKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Primary_Passenger__c');
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
        for (SObject src : scope) {
            String k = (String)src.get('Agent_ID__c');
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
        
        for (SObject src : scope) {
            SObject booking = t.newSObject();
            booking.put(BOOKING_EXTID, (String)src.get(ORDER_BY_SRC));
            
            for (DC_FieldMap m : DC_Mappings.BOOKING_MAP) {
                if (m.tgt == 'Agency__c') {
                    // Handle Account lookup
                    String accountKey = (String)src.get('Account_ID__c');
                    if (!String.isBlank(accountKey)) {
                        Id accountId = accountByExt.get(accountKey);
                        if (accountId != null) {
                            booking.put(m.tgt, accountId);
                        }
                    }
                } else if (m.tgt == 'Opportunity__c') {
                    // Handle Opportunity lookup
                    String oppKey = (String)src.get('Opportunity__c');
                    if (!String.isBlank(oppKey)) {
                        Id oppId = oppByExt.get(oppKey);
                        if (oppId != null) {
                            booking.put(m.tgt, oppId);
                        }
                    }
                } else if (m.tgt == 'Ship__c') {
                    // Handle Ship lookup
                    String shipKey = (String)src.get('Ship__c');
                    if (!String.isBlank(shipKey)) {
                        Id shipId = shipByExt.get(shipKey);
                        if (shipId != null) {
                            booking.put(m.tgt, shipId);
                        }
                    }
                } else if (m.tgt == 'Primary_Passenger__c') {
                    // Handle Client lookup
                    String clientKey = (String)src.get('Primary_Passenger__c');
                    if (!String.isBlank(clientKey)) {
                        Id clientId = clientByExt.get(clientKey);
                        if (clientId != null) {
                            booking.put(m.tgt, clientId);
                        }
                    }
                } else if (m.tgt == 'Travel_Agent__c') {
                    // Handle Agent lookup
                    String agentKey = (String)src.get('Agent_ID__c');
                    if (!String.isBlank(agentKey)) {
                        Id agentId = agentByExt.get(agentKey);
                        if (agentId != null) {
                            booking.put(m.tgt, agentId);
                        }
                    }
                } else {
                    Object value = src.get(m.src);
                    if (value != null) {
                        booking.put(m.tgt, value);
                    }
                }
            }
            out.add(booking);
        }
        return new DC_UpsertBundle(out, BOOKING_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
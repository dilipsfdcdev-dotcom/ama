public with sharing class DC_OpportunityStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Opportunity__dlm';
    private static final String ORDER_BY_SRC = 'Group_Id__c';
    private static final String OPPORTUNITY_EXTID = 'Group_Id__c';
    private static final String STEP_NAME = 'Opportunity';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME, 'ssot__LastModifiedDate__c');
        return 'ssot__DataSourceObjectId__c = \'Seaware_Opportunity_E1C50A03\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.OPPORTUNITY_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        f.add('Sailing__c'); // for Sailing lookup
        f.add('Agent_ID__c'); // for Agent lookup
        f.add('SEAWARE_Agency_ID__c');
        return f;
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        List<SObject> out = new List<SObject>();

        // Bulk resolve Account by external id
        Set<String> accountKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('SEAWARE_Agency_ID__c');
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

        // Bulk resolve Sailing by external id
        Set<String> sailingKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Sailing__c');
            if (!String.isBlank(k)) sailingKeys.add(k);
        }
        Map<String, Id> sailingByExt = new Map<String, Id>();
        if (!sailingKeys.isEmpty()) {
            for (Sailing__c s : [
                SELECT Id, Sailing_Code__c
                FROM Sailing__c
                WHERE Sailing_Code__c IN :sailingKeys
            ]) {
                sailingByExt.put(s.Sailing_Code__c, s.Id);
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
            Opportunity opp = new Opportunity();
            opp.put(OPPORTUNITY_EXTID, (String)src.get(ORDER_BY_SRC));
            
            for (DC_FieldMap m : DC_Mappings.OPPORTUNITY_MAP) {
                if (m.tgt == 'AccountId') {
                    // Handle Account lookup
                    String accountKey = (String)src.get('SEAWARE_Agency_ID__c');
                    if (!String.isBlank(accountKey)) {
                        Id accountId = accountByExt.get(accountKey);
                        if (accountId != null) {
                            opp.AccountId = accountId;
                        }
                    }
                } else if (m.tgt == 'Sailing__c') {
                    // Handle Sailing lookup
                    String sailingKey = (String)src.get('Sailing__c');
                    if (!String.isBlank(sailingKey)) {
                        Id sailingId = sailingByExt.get(sailingKey);
                        if (sailingId != null) {
                            opp.put(m.tgt, sailingId);
                        }
                    }
                } else if (m.tgt == 'agent_ID__c') {
                    // Handle Agent lookup - store Contact Id in agent_ID__c field
                    String agentKey = (String)src.get('Agent_ID__c');
                    if (!String.isBlank(agentKey)) {
                        Id agentId = agentByExt.get(agentKey);
                        if (agentId != null) {
                            opp.put(m.tgt, agentId);
                        }
                    }
                } else {
                    Object value = src.get(m.src);
                    if (value != null) {
                        opp.put(m.tgt, value);
                    }
                }
            }

            // Set RecordType for Charters Proposal
            opp.RecordTypeId = getOpportunityRecordTypeId('Charters Proposal');
            
            // Set required Opportunity fields
            if (opp.CloseDate == null) {
                opp.CloseDate = Date.today().addDays(30); // Default close date
            }
            
            out.add(opp);
        }
        return new DC_UpsertBundle(out, OPPORTUNITY_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }

    private Id getOpportunityRecordTypeId(String recordTypeName) {
        try {
            return Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        } catch (Exception e) {
            System.debug('RecordType not found: ' + recordTypeName);
            return null;
        }
    }
}
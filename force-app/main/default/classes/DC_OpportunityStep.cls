public with sharing class DC_OpportunityStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Opportunity__dlm';
    private static final String ORDER_BY_SRC = 'Group_Id__c';
    private static final String OPPORTUNITY_EXTID = 'Group_Id__c';
    private static final String STEP_NAME = 'Opportunity';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        // **FIX: Use CDP timestamp function for proper date filtering**
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
        // **FIX: Add the last modified date field to the field list**
        f.add('ssot__LastModifiedDate__c');
        return f;
    }

    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        List<SObject> out = new List<SObject>();

        // Bulk resolve Account by external id
        Set<String> accountKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'SEAWARE_Agency_ID__c');
            if (!String.isBlank(k)) accountKeys.add(k);
        }
        Map<String, Id> accountByExt = bulkLookupByExternalId('Account', 'SEAWARE_Agency_ID__c', accountKeys);

        // Bulk resolve Sailing by external id
        Set<String> sailingKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Sailing__c');
            if (!String.isBlank(k)) sailingKeys.add(k);
        }
        Map<String, Id> sailingByExt = bulkLookupByExternalId('Sailing__c', 'Sailing_Code__c', sailingKeys);

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
            Opportunity opp = new Opportunity();
            String groupId = (String) getFieldValue(src, ORDER_BY_SRC);
            setFieldValue(opp, OPPORTUNITY_EXTID, groupId);
            
            for (DC_FieldMap m : DC_Mappings.OPPORTUNITY_MAP) {
                if (m.tgt == 'AccountId') {
                    // Handle Account lookup
                    String accountKey = (String) getFieldValue(src, 'SEAWARE_Agency_ID__c');
                    if (!String.isBlank(accountKey)) {
                        Id accountId = accountByExt.get(accountKey);
                        if (accountId != null) {
                            opp.AccountId = accountId;
                        }
                    }
                } else if (m.tgt == 'Sailing__c') {
                    // Handle Sailing lookup
                    String sailingKey = (String) getFieldValue(src, 'Sailing__c');
                    if (!String.isBlank(sailingKey)) {
                        Id sailingId = sailingByExt.get(sailingKey);
                        if (sailingId != null) {
                            setFieldValue(opp, m.tgt, sailingId);
                        }
                    }
                } else if (m.tgt == 'agent_ID__c') {
                    // Handle Agent lookup - store Contact Id in agent_ID__c field
                    String agentKey = (String) getFieldValue(src, 'Agent_ID__c');
                    if (!String.isBlank(agentKey)) {
                        Id agentId = agentByExt.get(agentKey);
                        if (agentId != null) {
                            setFieldValue(opp, m.tgt, agentId);
                        }
                    }
                } else {
                    Object value = getFieldValue(src, m.src);
                    if (value != null) {
                        setFieldValue(opp, m.tgt, value);
                    }
                }
            }

            // Set RecordType for Charters Proposal
            opp.RecordTypeId = getChartersProposalRecordTypeId();
            
            // Set required Opportunity fields
            if (opp.CloseDate == null) {
                opp.CloseDate = Date.today().addDays(30); // Default close date
            }
            
            out.add(opp);
        }
        return new DC_UpsertBundle(out, OPPORTUNITY_EXTID);
    }

    // Local method to avoid inheritance issues
    private Id getChartersProposalRecordTypeId() {
        try {
            return Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Charters Proposal').getRecordTypeId();
        } catch (Exception e) {
            System.debug('Charters Proposal RecordType not found');
            return null;
        }
    }

    public override void afterUpsert(Object scopeObj, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
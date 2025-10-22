public with sharing class DC_OpportunityStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Opportunity__dlm';
    private static final String ORDER_BY_SRC = 'Group_Id__c';
    private static final String OPPORTUNITY_EXTID = 'Group_Id__c';
    private static final String STEP_NAME = 'Opportunity';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        // **UPDATED: Use dynamic DataSourceObjectId from custom metadata**
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME, 'ssot__LastModifiedDate__c');
        String dataSourceObjectId = DC_DateUtil.getDataSourceObjectId(STEP_NAME);
        
        if (String.isBlank(dataSourceObjectId)) {
            System.debug(LoggingLevel.ERROR, 'DataSourceObjectId not found for step: ' + STEP_NAME);
            return dateFilter;
        }
        
        return 'ssot__DataSourceObjectId__c = \'' + dataSourceObjectId + '\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.OPPORTUNITY_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC); // cursor + ext-id source
        f.add('Sailing__c'); // for both Sailing__c lookup AND SailingTxt__c text field
        f.add('Agent_ID__c'); // for Agent lookup (Travel_Agent__c)
        f.add('SEAWARE_Agency_ID__c'); // for Account lookup (AccountId)
        f.add('ssot__LastModifiedDate__c');
        return f;
    }

    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        List<SObject> out = new List<SObject>();

        System.debug(LoggingLevel.WARN, '=== OPPORTUNITY STEP START ===');
        System.debug(LoggingLevel.WARN, 'Processing ' + scope.size() + ' opportunity records');

        // **Bulk resolve Account by external id (SEAWARE_Agency_ID__c → AccountId)**
        Set<String> accountKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'SEAWARE_Agency_ID__c');
            if (!String.isBlank(k)) accountKeys.add(k);
        }
        Map<String, Id> accountByExt = bulkLookupByExternalId('Account', 'SEAWARE_Agency_ID__c', accountKeys);
        System.debug(LoggingLevel.WARN, 'Found ' + accountByExt.size() + ' matching Accounts');

        // **Bulk resolve Sailing by external id (Sailing__c → Sailing__c lookup)**
        Set<String> sailingKeys = new Set<String>();
        for (Object src : scope) {
            String k = (String) getFieldValue(src, 'Sailing__c');
            if (!String.isBlank(k)) sailingKeys.add(k);
        }
        Map<String, Id> sailingByExt = bulkLookupByExternalId('Sailing__c', 'Sailing_Code__c', sailingKeys);
        System.debug(LoggingLevel.WARN, 'Found ' + sailingByExt.size() + ' matching Sailings');

        // **Bulk resolve Contact (Agent) by external id (Agent_ID__c → Travel_Agent__c)**
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
                AND RecordType.Name = 'Confirmed Agent'
            ]) {
                agentByExt.put(c.Agent_ID__c, c.Id);
            }
        }
        System.debug(LoggingLevel.WARN, 'Found ' + agentByExt.size() + ' matching Agents');
        
        // Process each opportunity
        for (Object src : scope) {
            Opportunity opp = new Opportunity();
            String groupId = (String) getFieldValue(src, ORDER_BY_SRC);
            setFieldValue(opp, OPPORTUNITY_EXTID, groupId);
            
            System.debug(LoggingLevel.INFO, '--- Processing Opportunity: ' + groupId + ' ---');
            
            // Get sailing code value once for both lookup and text field
            String sailingCodeValue = (String) getFieldValue(src, 'Sailing__c');
            
            for (DC_FieldMap m : DC_Mappings.OPPORTUNITY_MAP) {
                if (m.tgt == 'AccountId') {
                    // **Handle Account lookup (SEAWARE_Agency_ID__c → AccountId)**
                    String accountKey = (String) getFieldValue(src, 'SEAWARE_Agency_ID__c');
                    if (!String.isBlank(accountKey)) {
                        Id accountId = accountByExt.get(accountKey);
                        if (accountId != null) {
                            opp.AccountId = accountId;
                            System.debug(LoggingLevel.INFO, 'Set AccountId: ' + accountId + ' (from ' + accountKey + ')');
                        } else {
                            System.debug(LoggingLevel.WARN, 'Account not found for SEAWARE_Agency_ID: ' + accountKey);
                        }
                    }
                } else if (m.tgt == 'Sailing__c') {
                    // **Handle Sailing lookup (Sailing__c → Sailing__c lookup field)**
                    if (!String.isBlank(sailingCodeValue)) {
                        Id sailingId = sailingByExt.get(sailingCodeValue);
                        if (sailingId != null) {
                            setFieldValue(opp, m.tgt, sailingId);
                            System.debug(LoggingLevel.INFO, 'Set Sailing__c lookup: ' + sailingId + ' (from ' + sailingCodeValue + ')');
                        } else {
                            System.debug(LoggingLevel.WARN, 'Sailing not found for code: ' + sailingCodeValue);
                        }
                    }
                } else if (m.tgt == 'SailingTxt__c') {
                    // **Handle Sailing text field (Sailing__c → SailingTxt__c text field)**
                    // Store the sailing code as plain text
                    if (!String.isBlank(sailingCodeValue)) {
                        setFieldValue(opp, m.tgt, sailingCodeValue);
                        System.debug(LoggingLevel.INFO, 'Set SailingTxt__c text: ' + sailingCodeValue);
                    }
                } else if (m.tgt == 'Travel_Agent__c') {
                    // **Handle Agent lookup (Agent_ID__c → Travel_Agent__c)**
                    String agentKey = (String) getFieldValue(src, 'Agent_ID__c');
                    if (!String.isBlank(agentKey)) {
                        Id agentId = agentByExt.get(agentKey);
                        if (agentId != null) {
                            setFieldValue(opp, m.tgt, agentId);
                            System.debug(LoggingLevel.INFO, 'Set Travel_Agent__c: ' + agentId + ' (from ' + agentKey + ')');
                        } else {
                            System.debug(LoggingLevel.WARN, 'Agent not found for Agent_ID: ' + agentKey);
                        }
                    }
                } else {
                    // Handle all other standard field mappings
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
        
        System.debug(LoggingLevel.WARN, 'Prepared ' + out.size() + ' opportunities for upsert');
        System.debug(LoggingLevel.WARN, '=== OPPORTUNITY STEP END ===');
        
        return new DC_UpsertBundle(out, OPPORTUNITY_EXTID);
    }

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
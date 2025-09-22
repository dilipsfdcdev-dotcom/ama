public with sharing class DC_ContactAgentStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Individual__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String AGENT_EXTID = 'Agent_ID__c';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        return 'ssot__DataSourceObjectId__c = \'Seaware_Agent_E1C50A02\' AND ssot__LastModifiedDate__c = TODAY';
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        
        // Add main Individual fields from mappings (non-relationship fields)
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_AGENT_MAP) {
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                f.add(mapping.src);
            }
        }
        
        // Add order by field if not already included
        f.add(ORDER_BY_SRC);
        
        // Add subqueries based on relationship mappings
        Set<String> subqueries = DC_RelationshipQueryUtil.buildSubqueriesFromMappings(DC_Mappings.CONTACT_AGENT_MAP);
        f.addAll(subqueries);
        
        return f;
    }

    // No additional sources - using relationship queries
    public override Map<String, DC_JoinConfig> getAdditionalSources() {
        return new Map<String, DC_JoinConfig>();
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        List<SObject> out = new List<SObject>();

        // Bulk resolve Account by external id for Agency relationship
        Set<String> agencyKeys = new Set<String>();
        for (SObject src : scope) {
            String k = (String)src.get('Agency_ID__c');
            if (!String.isBlank(k)) agencyKeys.add(k);
        }
        Map<String, Id> accountByExt = new Map<String, Id>();
        if (!agencyKeys.isEmpty()) {
            for (Account a : [
                SELECT Id, SEAWARE_Agency_ID__c
                FROM Account
                WHERE SEAWARE_Agency_ID__c IN :agencyKeys
            ]) {
                accountByExt.put(a.SEAWARE_Agency_ID__c, a.Id);
            }
        }

        for (SObject src : scope) {
            Contact agent = new Contact();
            
            // Set upsert key using composite Agent ID logic from mappings
            String agentId = (String)src.get('Agent_ID__c');
            if (String.isBlank(agentId)) agentId = (String)src.get('ssot__Id__c');
            if (String.isBlank(agentId)) agentId = (String)src.get('ssot__PartyId__c');
            agent.put(AGENT_EXTID, agentId);

            // Set RecordType for Agent
            agent.RecordTypeId = getContactRecordTypeId('Agent');

            // Apply all field mappings using the mapping-based approach
            for (DC_FieldMap mapping : DC_Mappings.CONTACT_AGENT_MAP) {
                if (mapping.tgt == 'Agent_ID__c') continue; // Skip, already set above
                
                if (DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                    // Relationship fields will be handled by applyRelationshipDataToContact
                    continue;
                } else {
                    // Direct field mapping from Individual record
                    Object value = src.get(mapping.src);
                    if (value != null) {
                        agent.put(mapping.tgt, value);
                    }
                }
            }

            // Apply relationship data using mappings
            DC_RelationshipQueryUtil.applyRelationshipDataToContact(agent, src, DC_Mappings.CONTACT_AGENT_MAP);

            // Set Account relationship
            String agencyId = (String)src.get('Agency_ID__c');
            if (!String.isBlank(agencyId)) {
                Id accountId = accountByExt.get(agencyId);
                if (accountId != null) {
                    agent.AccountId = accountId;
                }
            }

            out.add(agent);
        }
        return new DC_UpsertBundle(out, AGENT_EXTID);
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }

    private Id getContactRecordTypeId(String recordTypeName) {
        try {
            return Schema.SObjectType.Contact.getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        } catch (Exception e) {
            System.debug('RecordType not found: ' + recordTypeName);
            return null;
        }
    }
}
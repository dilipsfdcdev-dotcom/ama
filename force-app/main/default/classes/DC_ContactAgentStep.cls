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
        for (DC_FieldMap m : DC_Mappings.CONTACT_AGENT_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC);
        f.add('ssot__PartyId__c'); // for joining to contact points
        return f;
    }

    public override Map<String, DC_JoinConfig> getAdditionalSources() {
        Map<String, DC_JoinConfig> sources = new Map<String, DC_JoinConfig>();
        
        // Add email contact point
        sources.put('email', new DC_JoinConfig(
            'ssot__ContactPointEmail__dlm',
            new Set<String>{'ssot__EmailAddress__c', 'ssot__PartyId__c'},
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        ));
        
        // Add phone contact point
        sources.put('phone', new DC_JoinConfig(
            'ssot__ContactPointPhone__dlm',
            new Set<String>{'ssot__FormattedE164PhoneNumber__c', 'ssot__ExtensionNumber__c', 'ssot__PartyId__c'},
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        ));
        
        // Add address contact point
        sources.put('address', new DC_JoinConfig(
            'ssot__ContactPointAddress__dlm',
            new Set<String>{'ssot__AddressLine1__c', 'ssot__CityId__c', 'ssot__StateProvinceId__c', 'ssot__CountryId__c', 'Zipcode__c', 'ssot__PartyId__c'},
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        ));
        
        return sources;
    }

    // Default mapScope implementation for backward compatibility
    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        // For multi-source steps, this should not be called directly
        // but we provide a default implementation for interface compliance
        DC_MultiSourceData data = new DC_MultiSourceData(scope);
        return mapMultiSourceScope(data);
    }

    public override DC_UpsertBundle mapMultiSourceScope(DC_MultiSourceData data) {
        List<SObject> out = new List<SObject>();

        // Bulk resolve Account by external id for Agent lookups
        Set<String> agencyKeys = new Set<String>();
        for (SObject src : data.mainRecords) {
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

        for (SObject src : data.mainRecords) {
            Contact agent = new Contact();
            
            // Set upsert key - try multiple fields as per mapping
            String agentId = (String)src.get('Agent_ID__c');
            if (String.isBlank(agentId)) agentId = (String)src.get('ssot__Id__c');
            if (String.isBlank(agentId)) agentId = (String)src.get('ssot__PartyId__c');
            agent.put(AGENT_EXTID, agentId);

            // Set RecordType for Confirmed Agent
            agent.RecordTypeId = getContactRecordTypeId('Confirmed Agent');

            // Map main individual fields
            for (DC_FieldMap m : DC_Mappings.CONTACT_AGENT_MAP) {
                if (m.tgt == 'Agent_ID__c') continue; // Skip, already set above
                
                Object value = src.get(m.src);
                if (value != null) {
                    agent.put(m.tgt, value);
                }
            }

            // Get related contact point data
            String partyId = (String)src.get('ssot__PartyId__c');
            if (!String.isBlank(partyId)) {
                // Email
                SObject emailRec = getFirstAdditionalRecord(data, 'email', partyId);
                if (emailRec != null) {
                    agent.Email = (String)emailRec.get('ssot__EmailAddress__c');
                }
                
                // Phone
                SObject phoneRec = getFirstAdditionalRecord(data, 'phone', partyId);
                if (phoneRec != null) {
                    agent.Phone = (String)phoneRec.get('ssot__FormattedE164PhoneNumber__c');
                    agent.Extension__c = (String)phoneRec.get('ssot__ExtensionNumber__c');
                }
                
                // Address
                SObject addressRec = getFirstAdditionalRecord(data, 'address', partyId);
                if (addressRec != null) {
                    agent.MailingStreet = (String)addressRec.get('ssot__AddressLine1__c');
                    agent.MailingCity = (String)addressRec.get('ssot__CityId__c');
                    agent.MailingState = (String)addressRec.get('ssot__StateProvinceId__c');
                    agent.MailingCountry = (String)addressRec.get('ssot__CountryId__c');
                    agent.MailingPostalCode = (String)addressRec.get('Zipcode__c');
                }
            }

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
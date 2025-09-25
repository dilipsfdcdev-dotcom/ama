public with sharing class DC_ContactAgentStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Individual__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String AGENT_EXTID = 'Agent_ID__c';
    private static final String STEP_NAME = 'Agent';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        return 'ssot__DataSourceObjectId__c = \'Seaware_Agent_E1C50A02\' AND ' + DC_DateUtil.getDateFilterClause(STEP_NAME);
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        
        // Add only main Individual fields (no relationship fields)
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_AGENT_MAP) {
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                f.add(mapping.src);
            }
        }
        
        // Add order by field if not already included
        f.add(ORDER_BY_SRC);
        
        // Add Party ID for contact point queries
        f.add('ssot__PartyId__c');
        
        return f;
    }

    // Remove additional sources - we'll query them separately
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

        // Get all Party IDs for contact point queries
        Set<String> partyIds = new Set<String>();
        for (SObject src : scope) {
            String partyId = (String)src.get('ssot__PartyId__c');
            if (!String.isBlank(partyId)) {
                partyIds.add(partyId);
            }
        }

        // Query contact points separately to avoid complexity issues
        Map<String, String> emailByParty = queryEmailContactPoints(partyIds);
        Map<String, String> phoneByParty = queryPhoneContactPoints(partyIds);
        Map<String, Map<String, Object>> addressByParty = queryAddressContactPoints(partyIds);

        for (SObject src : scope) {
            Contact agent = new Contact();
            
            // Set upsert key using composite Agent ID logic
            String agentId = (String)src.get('Agent_ID__c');
            if (String.isBlank(agentId)) agentId = (String)src.get('ssot__Id__c');
            if (String.isBlank(agentId)) agentId = (String)src.get('ssot__PartyId__c');
            agent.put(AGENT_EXTID, agentId);

            // Set RecordType for Agent
            agent.RecordTypeId = getContactRecordTypeId('Confirmed Agent');

            // Apply direct field mappings (non-relationship fields)
            for (DC_FieldMap mapping : DC_Mappings.CONTACT_AGENT_MAP) {
                if (mapping.tgt == 'Agent_ID__c') continue; // Skip, already set above
                
                if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                    // Direct field mapping from Individual record
                    Object value = src.get(mapping.src);
                    if (value != null) {
                        agent.put(mapping.tgt, value);
                    }
                }
            }

            // Apply contact point data from separate queries
            String partyId = (String)src.get('ssot__PartyId__c');
            if (!String.isBlank(partyId)) {
                // Set email
                if (emailByParty.containsKey(partyId)) {
                    agent.Email = emailByParty.get(partyId);
                }
                
                // Set phone
                if (phoneByParty.containsKey(partyId)) {
                    agent.Phone = phoneByParty.get(partyId);
                }
                
                // Set address
                if (addressByParty.containsKey(partyId)) {
                    Map<String, Object> address = addressByParty.get(partyId);
                    if (address.get('MailingStreet') != null) agent.MailingStreet = (String)address.get('MailingStreet');
                    if (address.get('MailingCity') != null) agent.MailingCity = (String)address.get('MailingCity');
                    if (address.get('MailingState') != null) agent.MailingState = (String)address.get('MailingState');
                    if (address.get('MailingCountry') != null) agent.MailingCountry = (String)address.get('MailingCountry');
                    if (address.get('MailingPostalCode') != null) agent.MailingPostalCode = (String)address.get('MailingPostalCode');
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

    private Map<String, String> queryEmailContactPoints(Set<String> partyIds) {
        Map<String, String> emailByParty = new Map<String, String>();
        
        if (partyIds.isEmpty()) return emailByParty;
        
        try {
            String emailQuery = 'SELECT ssot__PartyId__c, ssot__EmailAddress__c ' +
                               'FROM ssot__ContactPointEmail__dlm ' +
                               'WHERE ssot__PartyId__c IN :partyIds ' +
                               'LIMIT 1000';
            
            List<SObject> emailRecords = Database.query(emailQuery);
            
            for (SObject emailRec : emailRecords) {
                String partyId = (String)emailRec.get('ssot__PartyId__c');
                String email = (String)emailRec.get('ssot__EmailAddress__c');
                if (!String.isBlank(partyId) && !String.isBlank(email)) {
                    emailByParty.put(partyId, email);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying email contact points: ' + e.getMessage());
        }
        
        return emailByParty;
    }

    private Map<String, String> queryPhoneContactPoints(Set<String> partyIds) {
        Map<String, String> phoneByParty = new Map<String, String>();
        
        if (partyIds.isEmpty()) return phoneByParty;
        
        try {
            String phoneQuery = 'SELECT ssot__PartyId__c, ssot__FormattedE164PhoneNumber__c, ssot__ExtensionNumber__c ' +
                               'FROM ssot__ContactPointPhone__dlm ' +
                               'WHERE ssot__PartyId__c IN :partyIds ' +
                               'LIMIT 1000';
            
            List<SObject> phoneRecords = Database.query(phoneQuery);
            
            for (SObject phoneRec : phoneRecords) {
                String partyId = (String)phoneRec.get('ssot__PartyId__c');
                String phone = (String)phoneRec.get('ssot__FormattedE164PhoneNumber__c');
                if (!String.isBlank(partyId) && !String.isBlank(phone)) {
                    phoneByParty.put(partyId, phone);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying phone contact points: ' + e.getMessage());
        }
        
        return phoneByParty;
    }

    private Map<String, Map<String, Object>> queryAddressContactPoints(Set<String> partyIds) {
        Map<String, Map<String, Object>> addressByParty = new Map<String, Map<String, Object>>();
        
        if (partyIds.isEmpty()) return addressByParty;
        
        try {
            String addressQuery = 'SELECT ssot__PartyId__c, ssot__AddressLine1__c, ssot__CityId__c, ' +
                                 'ssot__StateProvinceId__c, ssot__CountryId__c, Zipcode__c ' +
                                 'FROM ssot__ContactPointAddress__dlm ' +
                                 'WHERE ssot__PartyId__c IN :partyIds ' +
                                 'LIMIT 1000';
            
            List<SObject> addressRecords = Database.query(addressQuery);
            
            for (SObject addressRec : addressRecords) {
                String partyId = (String)addressRec.get('ssot__PartyId__c');
                if (!String.isBlank(partyId)) {
                    Map<String, Object> address = new Map<String, Object>();
                    address.put('MailingStreet', addressRec.get('ssot__AddressLine1__c'));
                    address.put('MailingCity', addressRec.get('ssot__CityId__c'));
                    address.put('MailingState', addressRec.get('ssot__StateProvinceId__c'));
                    address.put('MailingCountry', addressRec.get('ssot__CountryId__c'));
                    address.put('MailingPostalCode', addressRec.get('Zipcode__c'));
                    
                    addressByParty.put(partyId, address);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying address contact points: ' + e.getMessage());
        }
        
        return addressByParty;
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
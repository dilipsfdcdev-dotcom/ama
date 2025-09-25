public with sharing class DC_ContactClientStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Individual__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String CLIENT_EXTID = 'Client_ID__c';
    private static final String STEP_NAME = 'Client';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME, 'ssot__LastModifiedDate__c');
        return 'ssot__DataSourceObjectId__c = \'Seaware_Client_E1C50A05\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        
        // Add main Individual fields from mappings (non-relationship fields)
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                f.add(mapping.src);
            }
        }
        
        // Add order by field if not already included
        f.add(ORDER_BY_SRC);
        
        // Add subqueries based on relationship mappings
        Set<String> subqueries = DC_RelationshipQueryUtil.buildSubqueriesFromMappings(DC_Mappings.CONTACT_CLIENT_MAP);
        f.addAll(subqueries);
        
        return f;
    }

    // No additional sources - using relationship queries
    public override Map<String, DC_JoinConfig> getAdditionalSources() {
        return new Map<String, DC_JoinConfig>();
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        // Group clients by unified profile (ssot__PartyId__c) - same logic as before
        Map<String, List<SObject>> clientsByParty = new Map<String, List<SObject>>();
        for (SObject src : scope) {
            String partyId = (String)src.get('ssot__PartyId__c');
            if (!String.isBlank(partyId)) {
                if (!clientsByParty.containsKey(partyId)) {
                    clientsByParty.put(partyId, new List<SObject>());
                }
                clientsByParty.get(partyId).add(src);
            }
        }

        // Get existing contacts using relationship data for email/phone matching
        Map<String, List<Contact>> existingContactsByParty = queryExistingContactsByParty(clientsByParty.keySet(), scope);
        
        List<SObject> contactsToUpsert = new List<SObject>();
        
        // Process each unified profile using the same 8 scenarios as before
        for (String partyId : clientsByParty.keySet()) {
            List<SObject> seawareClients = clientsByParty.get(partyId);
            List<Contact> existingContacts = existingContactsByParty.get(partyId);
            
            List<Contact> processedContacts = processUnifiedProfile(seawareClients, existingContacts);
            contactsToUpsert.addAll(processedContacts);
        }

        return new DC_UpsertBundle(contactsToUpsert, CLIENT_EXTID);
    }

    private Map<String, List<Contact>> queryExistingContactsByParty(Set<String> partyIds, List<SObject> sourceRecords) {
        Map<String, List<Contact>> result = new Map<String, List<Contact>>();
        
        // Initialize map
        for (String partyId : partyIds) {
            result.put(partyId, new List<Contact>());
        }
        
        // Extract contact points using mapping-based approach
        Map<String, Map<String, String>> contactPointMaps = 
            DC_RelationshipQueryUtil.extractContactPointsFromMappings(sourceRecords, DC_Mappings.CONTACT_CLIENT_MAP);
        
        Map<String, String> emailToPartyMap = contactPointMaps.get('email');
        Map<String, String> phoneToPartyMap = contactPointMaps.get('phone');
        
        // Query existing contacts
        Set<String> emailsToSearch = emailToPartyMap.keySet();
        Set<String> phonesToSearch = phoneToPartyMap.keySet();
        
        List<Contact> existingContacts = new List<Contact>();
        Set<Id> processedContactIds = new Set<Id>();
        
        if (!emailsToSearch.isEmpty()) {
            List<Contact> emailMatches = [
                SELECT Id, Client_ID__c, Email, Phone, LastModifiedDate, FirstName, LastName
                FROM Contact
                WHERE RecordType.Name = 'Client' AND Email IN :emailsToSearch
            ];
            existingContacts.addAll(emailMatches);
            for (Contact c : emailMatches) processedContactIds.add(c.Id);
        }
        
        if (!phonesToSearch.isEmpty()) {
            List<Contact> phoneMatches = [
                SELECT Id, Client_ID__c, Email, Phone, LastModifiedDate, FirstName, LastName
                FROM Contact
                WHERE RecordType.Name = 'Client' AND Phone IN :phonesToSearch AND Id NOT IN :processedContactIds
            ];
            existingContacts.addAll(phoneMatches);
        }
        
        // Map contacts back to party IDs
        for (Contact contact : existingContacts) {
            String matchedPartyId = null;
            if (!String.isBlank(contact.Email) && emailToPartyMap.containsKey(contact.Email)) {
                matchedPartyId = emailToPartyMap.get(contact.Email);
            } else if (!String.isBlank(contact.Phone) && phoneToPartyMap.containsKey(contact.Phone)) {
                matchedPartyId = phoneToPartyMap.get(contact.Phone);
            }
            
            if (matchedPartyId != null && result.containsKey(matchedPartyId)) {
                result.get(matchedPartyId).add(contact);
            }
        }
        
        return result;
    }

    private List<Contact> processUnifiedProfile(List<SObject> seawareClients, List<Contact> existingContacts) {
        List<Contact> result = new List<Contact>();
        
        Integer seawareCount = seawareClients.size();
        Integer salesforceCount = existingContacts.size();
        
        // Same 8 scenarios as before
        if (seawareCount == 1 && salesforceCount == 0) {
            // Scenario 1: Only 1 Seaware Client
            result.add(createContactFromSeawareClient(seawareClients[0]));
            
        } else if (seawareCount == 0 && salesforceCount == 1) {
            // Scenario 2: Only 1 Salesforce Contact - do nothing
            
        } else if (seawareCount > 1 && salesforceCount == 0) {
            // Scenario 3: Multiple Seaware Clients, no Salesforce contacts
            for (SObject seawareClient : seawareClients) {
                result.add(createContactFromSeawareClient(seawareClient));
            }
            
        } else if (seawareCount == 0 && salesforceCount > 1) {
            // Scenario 4: Multiple Salesforce Contacts - do nothing
            
        } else if (seawareCount == 1 && salesforceCount == 1) {
            // Scenario 5: 1 Salesforce Contact and 1 Seaware Client
            result.addAll(handleScenario5(seawareClients[0], existingContacts[0]));
            
        } else if (seawareCount > 1 && salesforceCount == 1) {
            // Scenario 6: 1 Salesforce Contact and multiple Seaware Clients
            result.addAll(handleScenario6(seawareClients, existingContacts[0]));
            
        } else if (seawareCount == 1 && salesforceCount > 1) {
            // Scenario 7: Multiple Salesforce Contacts and 1 Seaware Client
            result.addAll(handleScenario7(seawareClients[0], existingContacts));
            
        } else if (seawareCount > 1 && salesforceCount > 1) {
            // Scenario 8: Multiple Salesforce Contacts and multiple Seaware Clients
            result.addAll(handleScenario8(seawareClients, existingContacts));
        }
        
        return result;
    }

    private Contact createContactFromSeawareClient(SObject src) {
        Contact client = new Contact();
        
        // Set upsert key using composite Client ID logic from mappings
        String clientId = getClientIdFromSeawareClient(src);
        client.put(CLIENT_EXTID, clientId);

        // Set RecordType for Client
        client.RecordTypeId = getContactRecordTypeId('Client');

        // Apply all field mappings using the mapping-based approach
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue; // Skip, already set above
            
            if (DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                // Relationship fields will be handled by applyRelationshipDataToContact
                continue;
            } else {
                // Direct field mapping from Individual record
                Object value = src.get(mapping.src);
                if (value != null) {
                    client.put(mapping.tgt, value);
                }
            }
        }

        // Apply relationship data using mappings - includes passport data
        DC_RelationshipQueryUtil.applyRelationshipDataToContact(client, src, DC_Mappings.CONTACT_CLIENT_MAP);

        return client;
    }

    private List<Contact> handleScenario5(SObject seawareClient, Contact existingContact) {
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        
        if (String.isBlank(existingContact.Client_ID__c)) {
            updateContactFromSeawareClient(existingContact, seawareClient);
            result.add(existingContact);
        } else if (existingContact.Client_ID__c == seawareClientId) {
            updateContactFromSeawareClient(existingContact, seawareClient);
            result.add(existingContact);
        } else {
            result.add(createContactFromSeawareClient(seawareClient));
        }
        return result;
    }

    private List<Contact> handleScenario6(List<SObject> seawareClients, Contact existingContact) {
        List<Contact> result = new List<Contact>();
        
        SObject mostRecent = findMostRecentSeawareClient(seawareClients);
        
        if (String.isBlank(existingContact.Client_ID__c)) {
            updateContactFromSeawareClient(existingContact, mostRecent);
            result.add(existingContact);
            
            for (SObject client : seawareClients) {
                if (client != mostRecent) {
                    result.add(createContactFromSeawareClient(client));
                }
            }
        } else {
            Boolean foundMatch = false;
            for (SObject client : seawareClients) {
                String clientId = getClientIdFromSeawareClient(client);
                if (existingContact.Client_ID__c == clientId) {
                    updateContactFromSeawareClient(existingContact, client);
                    result.add(existingContact);
                    foundMatch = true;
                    break;
                }
            }
            
            for (SObject client : seawareClients) {
                String clientId = getClientIdFromSeawareClient(client);
                if (!foundMatch || existingContact.Client_ID__c != clientId) {
                    result.add(createContactFromSeawareClient(client));
                }
            }
        }
        return result;
    }

    private List<Contact> handleScenario7(SObject seawareClient, List<Contact> existingContacts) {
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        
        Contact matchingContact = null;
        for (Contact contact : existingContacts) {
            if (!String.isBlank(contact.Client_ID__c) && contact.Client_ID__c == seawareClientId) {
                matchingContact = contact;
                break;
            }
        }
        
        if (matchingContact != null) {
            updateContactFromSeawareClient(matchingContact, seawareClient);
            result.add(matchingContact);
        } else {
            Contact contactWithoutId = null;
            for (Contact contact : existingContacts) {
                if (String.isBlank(contact.Client_ID__c)) {
                    if (contactWithoutId == null || contact.LastModifiedDate > contactWithoutId.LastModifiedDate) {
                        contactWithoutId = contact;
                    }
                }
            }
            
            if (contactWithoutId != null) {
                updateContactFromSeawareClient(contactWithoutId, seawareClient);
                result.add(contactWithoutId);
            } else {
                result.add(createContactFromSeawareClient(seawareClient));
            }
        }
        return result;
    }

    private List<Contact> handleScenario8(List<SObject> seawareClients, List<Contact> existingContacts) {
        List<Contact> result = new List<Contact>();
        Set<String> matchedClientIds = new Set<String>();
        
        for (Contact contact : existingContacts) {
            if (!String.isBlank(contact.Client_ID__c)) {
                for (SObject client : seawareClients) {
                    String clientId = getClientIdFromSeawareClient(client);
                    if (contact.Client_ID__c == clientId) {
                        updateContactFromSeawareClient(contact, client);
                        result.add(contact);
                        matchedClientIds.add(clientId);
                        break;
                    }
                }
            }
        }
        
        for (SObject client : seawareClients) {
            String clientId = getClientIdFromSeawareClient(client);
            if (!matchedClientIds.contains(clientId)) {
                result.add(createContactFromSeawareClient(client));
            }
        }
        return result;
    }

    private void updateContactFromSeawareClient(Contact existingContact, SObject src) {
        String clientId = getClientIdFromSeawareClient(src);
        if (String.isBlank(existingContact.Client_ID__c)) {
            existingContact.put(CLIENT_EXTID, clientId);
        }

        // Apply field mappings
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue;
            
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                Object value = src.get(mapping.src);
                if (value != null) {
                    existingContact.put(mapping.tgt, value);
                }
            }
        }

        DC_RelationshipQueryUtil.applyRelationshipDataToContact(existingContact, src, DC_Mappings.CONTACT_CLIENT_MAP);
    }

    private String getClientIdFromSeawareClient(SObject src) {
        String clientId = (String)src.get('Client_ID__c');
        if (String.isBlank(clientId)) clientId = (String)src.get('ssot__Id__c');
        if (String.isBlank(clientId)) clientId = (String)src.get('ssot__PartyId__c');
        return clientId;
    }

    private SObject findMostRecentSeawareClient(List<SObject> clients) {
        SObject mostRecent = clients[0];
        DateTime mostRecentDate = (DateTime)mostRecent.get('ssot__LastModifiedDate__c');
        
        for (SObject client : clients) {
            DateTime clientDate = (DateTime)client.get('ssot__LastModifiedDate__c');
            if (clientDate != null && (mostRecentDate == null || clientDate > mostRecentDate)) {
                mostRecent = client;
                mostRecentDate = clientDate;
            }
        }
        return mostRecent;
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
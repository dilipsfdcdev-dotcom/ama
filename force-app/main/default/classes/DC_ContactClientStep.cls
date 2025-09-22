public with sharing class DC_ContactClientStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Individual__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String CLIENT_EXTID = 'Client_ID__c';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        return 'ssot__DataSourceObjectId__c = \'Seaware_Client_E1C50A05\' AND ssot__LastModifiedDate__c = TODAY';
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.CONTACT_CLIENT_MAP) {
            f.add(m.src);
        }
        f.add(ORDER_BY_SRC);
        f.add('ssot__PartyId__c'); // for joining to contact points
        f.add('ssot__LastModifiedDate__c'); // for determining most recent
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
            new Set<String>{'ssot__FormattedE164PhoneNumber__c', 'ssot__PartyId__c'},
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
        
        // Add passport/party identification
        sources.put('passport', new DC_JoinConfig(
            'PartyIdentification__dlm',
            new Set<String>{'ssot__IdentificationNumber__c', 'ssot__IssuedAtLocation__c', 'Issued_Date__c', 'Expiration_Date__c', 'ssot__PartyId__c'},
            'ssot__PartyId__c',
            'ssot__PartyId__c',
            'ssot__IdentificationType__c = \'Passport\''
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
        // Group Seaware clients by unified profile (ssot__PartyId__c)
        Map<String, List<SObject>> clientsByParty = new Map<String, List<SObject>>();
        for (SObject src : data.mainRecords) {
            String partyId = (String)src.get('ssot__PartyId__c');
            if (!String.isBlank(partyId)) {
                if (!clientsByParty.containsKey(partyId)) {
                    clientsByParty.put(partyId, new List<SObject>());
                }
                clientsByParty.get(partyId).add(src);
            }
        }

        // Get all unique party IDs to query for existing Salesforce contacts
        Set<String> allPartyIds = clientsByParty.keySet();
        
        // Query existing Salesforce contacts for these unified profiles
        Map<String, List<Contact>> existingContactsByParty = queryExistingContactsByParty(allPartyIds);
        
        List<SObject> contactsToUpsert = new List<SObject>();
        
        // Process each unified profile
        for (String partyId : clientsByParty.keySet()) {
            List<SObject> seawareClients = clientsByParty.get(partyId);
            List<Contact> existingContacts = existingContactsByParty.get(partyId);
            
            List<Contact> processedContacts = processUnifiedProfile(seawareClients, existingContacts, data, partyId);
            contactsToUpsert.addAll(processedContacts);
        }

        return new DC_UpsertBundle(contactsToUpsert, CLIENT_EXTID);
    }

    private Map<String, List<Contact>> queryExistingContactsByParty(Set<String> partyIds) {
        Map<String, List<Contact>> result = new Map<String, List<Contact>>();
        
        // Initialize map
        for (String partyId : partyIds) {
            result.put(partyId, new List<Contact>());
        }
        
        // First, get email addresses for these party IDs
        Map<String, String> emailToPartyMap = new Map<String, String>();
        for (ssot__ContactPointEmail__dlm emailCP : [
            SELECT ssot__EmailAddress__c, ssot__PartyId__c
            FROM ssot__ContactPointEmail__dlm
            WHERE ssot__PartyId__c IN :partyIds
        ]) {
            if (!String.isBlank(emailCP.ssot__EmailAddress__c)) {
                emailToPartyMap.put(emailCP.ssot__EmailAddress__c, emailCP.ssot__PartyId__c);
            }
        }
        
        // Then, get phone numbers for these party IDs
        Map<String, String> phoneToPartyMap = new Map<String, String>();
        for (ssot__ContactPointPhone__dlm phoneCP : [
            SELECT ssot__FormattedE164PhoneNumber__c, ssot__PartyId__c
            FROM ssot__ContactPointPhone__dlm
            WHERE ssot__PartyId__c IN :partyIds
        ]) {
            if (!String.isBlank(phoneCP.ssot__FormattedE164PhoneNumber__c)) {
                phoneToPartyMap.put(phoneCP.ssot__FormattedE164PhoneNumber__c, phoneCP.ssot__PartyId__c);
            }
        }
        
        // Get all emails and phones to search for
        Set<String> emailsToSearch = emailToPartyMap.keySet();
        Set<String> phonesToSearch = phoneToPartyMap.keySet();
        
        // Query contacts that might be part of these unified profiles
        List<Contact> existingContacts = new List<Contact>();
        Set<Id> processedContactIds = new Set<Id>();
        
        if (!emailsToSearch.isEmpty()) {
            List<Contact> emailMatches = [
                SELECT Id, Client_ID__c, Email, Phone, LastModifiedDate,
                       FirstName, LastName, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
                FROM Contact
                WHERE RecordType.Name = 'Client'
                AND Email IN :emailsToSearch
            ];
            existingContacts.addAll(emailMatches);
            for (Contact c : emailMatches) {
                processedContactIds.add(c.Id);
            }
        }
        
        if (!phonesToSearch.isEmpty()) {
            List<Contact> phoneMatches = [
                SELECT Id, Client_ID__c, Email, Phone, LastModifiedDate,
                       FirstName, LastName, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
                FROM Contact
                WHERE RecordType.Name = 'Client'
                AND Phone IN :phonesToSearch
            ];
            
            // Add only contacts not already processed by email match
            for (Contact c : phoneMatches) {
                if (!processedContactIds.contains(c.Id)) {
                    existingContacts.add(c);
                }
            }
        }
        
        // Map contacts back to party IDs based on email/phone matching
        for (Contact contact : existingContacts) {
            String matchedPartyId = null;
            
            // Try to match by email first
            if (!String.isBlank(contact.Email) && emailToPartyMap.containsKey(contact.Email)) {
                matchedPartyId = emailToPartyMap.get(contact.Email);
            }
            // If no email match, try phone
            else if (!String.isBlank(contact.Phone) && phoneToPartyMap.containsKey(contact.Phone)) {
                matchedPartyId = phoneToPartyMap.get(contact.Phone);
            }
            
            if (matchedPartyId != null && result.containsKey(matchedPartyId)) {
                result.get(matchedPartyId).add(contact);
            }
        }
        
        return result;
    }

    private List<Contact> processUnifiedProfile(List<SObject> seawareClients, List<Contact> existingContacts, 
                                               DC_MultiSourceData data, String partyId) {
        List<Contact> result = new List<Contact>();
        
        Integer seawareCount = seawareClients.size();
        Integer salesforceCount = existingContacts.size();
        
        if (seawareCount == 1 && salesforceCount == 0) {
            // Scenario 1: Only 1 Seaware Client
            result.add(createContactFromSeawareClient(seawareClients[0], data, partyId));
            
        } else if (seawareCount == 0 && salesforceCount == 1) {
            // Scenario 2: Only 1 Salesforce Contact - do nothing
            // No contacts to upsert
            
        } else if (seawareCount > 1 && salesforceCount == 0) {
            // Scenario 3: Multiple Seaware Clients, no Salesforce contacts
            for (SObject seawareClient : seawareClients) {
                result.add(createContactFromSeawareClient(seawareClient, data, partyId));
            }
            
        } else if (seawareCount == 0 && salesforceCount > 1) {
            // Scenario 4: Multiple Salesforce Contacts - do nothing
            // No contacts to upsert
            
        } else if (seawareCount == 1 && salesforceCount == 1) {
            // Scenario 5: 1 Salesforce Contact and 1 Seaware Client
            result.addAll(handleScenario5(seawareClients[0], existingContacts[0], data, partyId));
            
        } else if (seawareCount > 1 && salesforceCount == 1) {
            // Scenario 6: 1 Salesforce Contact and multiple Seaware Clients
            result.addAll(handleScenario6(seawareClients, existingContacts[0], data, partyId));
            
        } else if (seawareCount == 1 && salesforceCount > 1) {
            // Scenario 7: Multiple Salesforce Contacts and 1 Seaware Client
            result.addAll(handleScenario7(seawareClients[0], existingContacts, data, partyId));
            
        } else if (seawareCount > 1 && salesforceCount > 1) {
            // Scenario 8: Multiple Salesforce Contacts and multiple Seaware Clients
            result.addAll(handleScenario8(seawareClients, existingContacts, data, partyId));
        }
        
        return result;
    }

    private List<Contact> handleScenario5(SObject seawareClient, Contact existingContact, 
                                        DC_MultiSourceData data, String partyId) {
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        
        if (String.isBlank(existingContact.Client_ID__c)) {
            // Update existing contact
            updateContactFromSeawareClient(existingContact, seawareClient, data, partyId);
            result.add(existingContact);
        } else if (existingContact.Client_ID__c == seawareClientId) {
            // Update existing contact
            updateContactFromSeawareClient(existingContact, seawareClient, data, partyId);
            result.add(existingContact);
        } else {
            // Create new contact
            result.add(createContactFromSeawareClient(seawareClient, data, partyId));
        }
        
        return result;
    }

    private List<Contact> handleScenario6(List<SObject> seawareClients, Contact existingContact, 
                                        DC_MultiSourceData data, String partyId) {
        List<Contact> result = new List<Contact>();
        
        // Find most recently modified Seaware client
        SObject mostRecent = findMostRecentSeawareClient(seawareClients);
        String mostRecentClientId = getClientIdFromSeawareClient(mostRecent);
        
        if (String.isBlank(existingContact.Client_ID__c)) {
            // Update with most recent, create new for others
            updateContactFromSeawareClient(existingContact, mostRecent, data, partyId);
            result.add(existingContact);
            
            for (SObject client : seawareClients) {
                if (client != mostRecent) {
                    result.add(createContactFromSeawareClient(client, data, partyId));
                }
            }
        } else {
            // Check if existing contact matches any Seaware client
            boolean foundMatch = false;
            for (SObject client : seawareClients) {
                String clientId = getClientIdFromSeawareClient(client);
                if (existingContact.Client_ID__c == clientId) {
                    updateContactFromSeawareClient(existingContact, client, data, partyId);
                    result.add(existingContact);
                    foundMatch = true;
                    break;
                }
            }
            
            // Create new contacts for remaining clients
            for (SObject client : seawareClients) {
                String clientId = getClientIdFromSeawareClient(client);
                if (!foundMatch || existingContact.Client_ID__c != clientId) {
                    result.add(createContactFromSeawareClient(client, data, partyId));
                }
            }
        }
        
        return result;
    }

    private List<Contact> handleScenario7(SObject seawareClient, List<Contact> existingContacts, 
                                        DC_MultiSourceData data, String partyId) {
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        
        // Check if any existing contact has matching Client_ID
        Contact matchingContact = null;
        for (Contact contact : existingContacts) {
            if (!String.isBlank(contact.Client_ID__c) && contact.Client_ID__c == seawareClientId) {
                matchingContact = contact;
                break;
            }
        }
        
        if (matchingContact != null) {
            // Update the matching contact
            updateContactFromSeawareClient(matchingContact, seawareClient, data, partyId);
            result.add(matchingContact);
        } else {
            // Check if any contact doesn't have Client_ID
            Contact contactWithoutId = null;
            for (Contact contact : existingContacts) {
                if (String.isBlank(contact.Client_ID__c)) {
                    if (contactWithoutId == null || contact.LastModifiedDate > contactWithoutId.LastModifiedDate) {
                        contactWithoutId = contact;
                    }
                }
            }
            
            if (contactWithoutId != null) {
                // Update most recently modified contact without Client_ID
                updateContactFromSeawareClient(contactWithoutId, seawareClient, data, partyId);
                result.add(contactWithoutId);
            } else {
                // All contacts have different Client_IDs, create new
                result.add(createContactFromSeawareClient(seawareClient, data, partyId));
            }
        }
        
        return result;
    }

    private List<Contact> handleScenario8(List<SObject> seawareClients, List<Contact> existingContacts, 
                                        DC_MultiSourceData data, String partyId) {
        List<Contact> result = new List<Contact>();
        
        Set<String> matchedClientIds = new Set<String>();
        
        // Update existing contacts that have matching Client_IDs
        for (Contact contact : existingContacts) {
            if (!String.isBlank(contact.Client_ID__c)) {
                for (SObject client : seawareClients) {
                    String clientId = getClientIdFromSeawareClient(client);
                    if (contact.Client_ID__c == clientId) {
                        updateContactFromSeawareClient(contact, client, data, partyId);
                        result.add(contact);
                        matchedClientIds.add(clientId);
                        break;
                    }
                }
            }
        }
        
        // Create new contacts for unmatched Seaware clients
        for (SObject client : seawareClients) {
            String clientId = getClientIdFromSeawareClient(client);
            if (!matchedClientIds.contains(clientId)) {
                result.add(createContactFromSeawareClient(client, data, partyId));
            }
        }
        
        return result;
    }

    private Contact createContactFromSeawareClient(SObject src, DC_MultiSourceData data, String partyId) {
        Contact client = new Contact();
        
        // Set upsert key
        String clientId = getClientIdFromSeawareClient(src);
        client.put(CLIENT_EXTID, clientId);

        // Set RecordType for Client
        client.RecordTypeId = getContactRecordTypeId('Client');

        // Map main individual fields
        for (DC_FieldMap m : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (m.tgt == 'Client_ID__c') continue; // Skip, already set above
            
            Object value = src.get(m.src);
            if (value != null) {
                client.put(m.tgt, value);
            }
        }

        // Apply contact point data
        applyContactPointData(client, data, partyId);

        return client;
    }

    private void updateContactFromSeawareClient(Contact existingContact, SObject src, DC_MultiSourceData data, String partyId) {
        // Set Client_ID if not already set
        String clientId = getClientIdFromSeawareClient(src);
        if (String.isBlank(existingContact.Client_ID__c)) {
            existingContact.put(CLIENT_EXTID, clientId);
        }

        // Update fields from Seaware client
        for (DC_FieldMap m : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (m.tgt == 'Client_ID__c') continue; // Skip if already has value
            
            Object value = src.get(m.src);
            if (value != null) {
                existingContact.put(m.tgt, value);
            }
        }

        // Apply contact point data
        applyContactPointData(existingContact, data, partyId);
    }

    private void applyContactPointData(Contact contact, DC_MultiSourceData data, String partyId) {
        // Email
        SObject emailRec = getFirstAdditionalRecord(data, 'email', partyId);
        if (emailRec != null) {
            contact.Email = (String)emailRec.get('ssot__EmailAddress__c');
        }
        
        // Phone
        SObject phoneRec = getFirstAdditionalRecord(data, 'phone', partyId);
        if (phoneRec != null) {
            contact.Phone = (String)phoneRec.get('ssot__FormattedE164PhoneNumber__c');
        }
        
        // Address
        SObject addressRec = getFirstAdditionalRecord(data, 'address', partyId);
        if (addressRec != null) {
            contact.MailingStreet = (String)addressRec.get('ssot__AddressLine1__c');
            contact.MailingCity = (String)addressRec.get('ssot__CityId__c');
            contact.MailingState = (String)addressRec.get('ssot__StateProvinceId__c');
            contact.MailingCountry = (String)addressRec.get('ssot__CountryId__c');
            contact.MailingPostalCode = (String)addressRec.get('Zipcode__c');
        }
        
        // Passport
        SObject passportRec = getFirstAdditionalRecord(data, 'passport', partyId);
        if (passportRec != null) {
            contact.Passport_Number__c = (String)passportRec.get('ssot__IdentificationNumber__c');
            contact.Passport_Issue_Country__c = (String)passportRec.get('ssot__IssuedAtLocation__c');
            contact.Passport_Issue_Date__c = (Date)passportRec.get('Issued_Date__c');
            contact.Passport_Expire_Date__c = (Date)passportRec.get('Expiration_Date__c');
        }
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
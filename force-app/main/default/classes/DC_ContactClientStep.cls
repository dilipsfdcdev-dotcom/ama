public with sharing class DC_ContactClientStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Individual__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String CLIENT_EXTID = 'Client_ID__c';
    private static final String STEP_NAME = 'Client';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME, 'ssot__LastModifiedDate__c');
        return 'ssot__DataSourceObjectId__c = \'Seaware_Client_E1C50A05\' AND ssot__PartyId__c = \'30000004\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                f.add(mapping.src);
            }
        }
        
        f.add(ORDER_BY_SRC);
        f.add('ssot__PartyId__c');
        f.add('ssot__LastModifiedDate__c');
        
        return f;
    }

    public override Map<String, DC_JoinConfig> getAdditionalSources() {
        return new Map<String, DC_JoinConfig>();
    }

    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        
        System.debug(LoggingLevel.WARN, '=== CLIENT STEP START ===');
        
        // Group clients by unified profile (Party ID)
        Map<String, List<Object>> clientsByParty = new Map<String, List<Object>>();
        for (Object src : scope) {
            String partyId = (String) getFieldValue(src, 'ssot__PartyId__c');
            if (!String.isBlank(partyId)) {
                if (!clientsByParty.containsKey(partyId)) {
                    clientsByParty.put(partyId, new List<Object>());
                }
                clientsByParty.get(partyId).add(src);
            }
        }

        Set<String> allPartyIds = clientsByParty.keySet();
        Map<String, String> emailByParty = queryEmailContactPointsCDP(allPartyIds);
        Map<String, String> phoneByParty = queryPhoneContactPointsCDP(allPartyIds);
        Map<String, Map<String, Object>> addressByParty = queryAddressContactPointsCDP(allPartyIds);
        Map<String, Map<String, Object>> passportByParty = queryPassportDataCDP(allPartyIds);

        Map<String, List<Contact>> existingContactsByParty = queryExistingContactsByParty(
            clientsByParty.keySet(), emailByParty, phoneByParty);
        
        List<SObject> contactsToUpsert = new List<SObject>();
        
        for (String partyId : clientsByParty.keySet()) {
            List<Object> seawareClients = clientsByParty.get(partyId);
            List<Contact> existingContacts = existingContactsByParty.get(partyId);
            
            System.debug(LoggingLevel.WARN, 'Processing Party ID: ' + partyId);
            System.debug(LoggingLevel.WARN, '  Seaware Clients: ' + seawareClients.size());
            System.debug(LoggingLevel.WARN, '  Existing SF Contacts: ' + existingContacts.size());
            
            List<Contact> processedContacts = processUnifiedProfile(
                seawareClients, existingContacts, partyId, 
                emailByParty, phoneByParty, addressByParty, passportByParty);
            
            contactsToUpsert.addAll(processedContacts);
        }

        System.debug(LoggingLevel.WARN, 'Total contacts to upsert: ' + contactsToUpsert.size());
        System.debug(LoggingLevel.WARN, '=== CLIENT STEP END ===');
        
        return new DC_UpsertBundle(contactsToUpsert, CLIENT_EXTID);
    }

    /**
     * Process unified profile according to 8 scenarios
     */
    private List<Contact> processUnifiedProfile(
        List<Object> seawareClients, 
        List<Contact> existingContacts, 
        String partyId,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        
        Integer seawareCount = seawareClients.size();
        Integer salesforceCount = existingContacts.size();
        
        System.debug(LoggingLevel.WARN, '--- Scenario Detection ---');
        System.debug(LoggingLevel.WARN, 'Seaware: ' + seawareCount + ', Salesforce: ' + salesforceCount);
        
        // SCENARIO 1: Only 1 Seaware Client, no Salesforce contacts
        if (seawareCount == 1 && salesforceCount == 0) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 1: Create new contact from single Seaware client');
            result.add(createContactFromSeawareClient(
                seawareClients[0], partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        // SCENARIO 2: Only Salesforce contacts, no Seaware clients
        else if (seawareCount == 0 && salesforceCount > 0) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 2: No Seaware data - nothing to sync');
            // Do nothing - no Seaware data to sync
        }
        
        // SCENARIO 3: Multiple Seaware Clients, no Salesforce contacts
        else if (seawareCount > 1 && salesforceCount == 0) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 3: Create contact for each Seaware client');
            for (Object seawareClient : seawareClients) {
                result.add(createContactFromSeawareClient(
                    seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        }
        
        // SCENARIO 4: Multiple Salesforce Contacts, no Seaware clients
        else if (seawareCount == 0 && salesforceCount > 1) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 4: No Seaware data - nothing to sync');
            // Do nothing - no Seaware data to sync
        }
        
        // SCENARIO 5: 1 Salesforce Contact and 1 Seaware Client
        else if (seawareCount == 1 && salesforceCount == 1) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 5: Match single SF contact with single Seaware client');
            result.addAll(handleScenario5(
                seawareClients[0], existingContacts[0], partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        // SCENARIO 6: 1 Salesforce Contact and multiple Seaware Clients
        else if (seawareCount > 1 && salesforceCount == 1) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 6: Match single SF contact with multiple Seaware clients');
            result.addAll(handleScenario6(
                seawareClients, existingContacts[0], partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        // SCENARIO 7: Multiple Salesforce Contacts and 1 Seaware Client
        else if (seawareCount == 1 && salesforceCount > 1) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 7: Match single Seaware client with multiple SF contacts');
            result.addAll(handleScenario7(
                seawareClients[0], existingContacts, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        // SCENARIO 8: Multiple Salesforce Contacts and multiple Seaware Clients
        else if (seawareCount > 1 && salesforceCount > 1) {
            System.debug(LoggingLevel.WARN, 'SCENARIO 8: Match multiple SF contacts with multiple Seaware clients');
            result.addAll(handleScenario8(
                seawareClients, existingContacts, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        System.debug(LoggingLevel.WARN, 'Contacts to process: ' + result.size());
        return result;
    }

    /**
     * SCENARIO 5: 1 SF Contact + 1 Seaware Client
     * ACTUAL FIX: Ensure we return the contact with its SF Id populated for update
     */
    private List<Contact> handleScenario5(
        Object seawareClient,
        Contact existingContact,
        String partyId,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        String sfClientId = existingContact.Client_ID__c;
        
        System.debug(LoggingLevel.INFO, 'SCENARIO 5 - Seaware Client ID: ' + seawareClientId + ', SF Client ID: ' + sfClientId);
        System.debug(LoggingLevel.INFO, 'Existing SF Contact Id: ' + existingContact.Id);
        
        // CASE 5a: SF Contact has no Client_ID - UPDATE the existing contact
        if (String.isBlank(sfClientId)) {
            System.debug(LoggingLevel.INFO, 'SCENARIO 5a: SF Contact has no Client_ID - UPDATING existing contact');
            
            // Set the Client_ID on the existing contact
            existingContact.Client_ID__c = seawareClientId;
            
            // Update other fields
            updateContactFieldsFromSeaware(existingContact, seawareClient, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty);
            
            // Add to result - it has Id so upsert will update
            result.add(existingContact);
            
            System.debug(LoggingLevel.INFO, 'Will UPDATE Contact Id: ' + existingContact.Id + ' with Client_ID: ' + existingContact.Client_ID__c);
        }
        // CASE 5b: Client_IDs match - UPDATE the existing contact
        else if (sfClientId == seawareClientId) {
            System.debug(LoggingLevel.INFO, 'SCENARIO 5b: Client_IDs match - UPDATING SF contact');
            
            // Update fields (Client_ID already matches)
            updateContactFieldsFromSeaware(existingContact, seawareClient, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty);
            
            result.add(existingContact);
            
            System.debug(LoggingLevel.INFO, 'Will UPDATE Contact Id: ' + existingContact.Id);
        }
        // CASE 5c: Client_IDs differ - CREATE NEW contact
        else {
            System.debug(LoggingLevel.INFO, 'SCENARIO 5c: Client_IDs differ - CREATING new contact');
            result.add(createContactFromSeawareClient(seawareClient, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        return result;
    }

    /**
     * SCENARIO 6: 1 SF Contact + Multiple Seaware Clients
     */
    private List<Contact> handleScenario6(
        List<Object> seawareClients,
        Contact existingContact,
        String partyId,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        String sfClientId = existingContact.Client_ID__c;
        
        Object matchingSeawareClient = null;
        List<Object> unmatchedSeawareClients = new List<Object>();
        
        // Find matching Seaware client
        for (Object seawareClient : seawareClients) {
            String seawareClientId = getClientIdFromSeawareClient(seawareClient);
            if (!String.isBlank(sfClientId) && sfClientId == seawareClientId) {
                matchingSeawareClient = seawareClient;
            } else {
                unmatchedSeawareClients.add(seawareClient);
            }
        }
        
        // If SF Contact has no Client_ID or has matching Client_ID, update with most recent
        if (String.isBlank(sfClientId)) {
            System.debug(LoggingLevel.INFO, 'SCENARIO 6: SF Contact has no Client_ID - updating with most recent');
            Object mostRecent = findMostRecentSeawareClient(seawareClients);
            String mostRecentClientId = getClientIdFromSeawareClient(mostRecent);
            
            existingContact.Client_ID__c = mostRecentClientId;
            updateContactFieldsFromSeaware(existingContact, mostRecent, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(existingContact);
            
            // Create new for all others
            for (Object seawareClient : seawareClients) {
                if (seawareClient != mostRecent) {
                    result.add(createContactFromSeawareClient(seawareClient, partyId,
                        emailByParty, phoneByParty, addressByParty, passportByParty));
                }
            }
        }
        else if (matchingSeawareClient != null) {
            System.debug(LoggingLevel.INFO, 'SCENARIO 6: Found matching Client_ID - updating SF contact');
            updateContactFieldsFromSeaware(existingContact, matchingSeawareClient, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(existingContact);
            
            // Create new for unmatched
            for (Object seawareClient : unmatchedSeawareClients) {
                result.add(createContactFromSeawareClient(seawareClient, partyId,
                    emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        }
        else {
            System.debug(LoggingLevel.INFO, 'SCENARIO 6: No matching Client_ID - creating new for all Seaware clients');
            // Create new for all Seaware clients
            for (Object seawareClient : seawareClients) {
                result.add(createContactFromSeawareClient(seawareClient, partyId,
                    emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        }
        
        return result;
    }

    /**
     * SCENARIO 7: Multiple SF Contacts + 1 Seaware Client
     * ACTUAL FIX: Ensure we return the contact with its SF Id populated for update
     */
    private List<Contact> handleScenario7(
        Object seawareClient,
        List<Contact> existingContacts,
        String partyId,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        
        Contact matchingContact = null;
        Boolean hasContactWithoutClientId = false;
        Contact mostRecentContact = existingContacts[0];
        
        System.debug(LoggingLevel.INFO, 'SCENARIO 7 - Analyzing ' + existingContacts.size() + ' existing contacts');
        System.debug(LoggingLevel.INFO, 'Seaware Client ID: ' + seawareClientId);
        
        // Analyze existing contacts
        for (Contact existingContact : existingContacts) {
            System.debug(LoggingLevel.INFO, 'Contact Id: ' + existingContact.Id + 
                        ', Client_ID__c: ' + existingContact.Client_ID__c + 
                        ', LastModified: ' + existingContact.LastModifiedDate);
            
            // CASE 7a: Find exact match by Client_ID
            if (!String.isBlank(existingContact.Client_ID__c) && 
                existingContact.Client_ID__c == seawareClientId) {
                matchingContact = existingContact;
            }
            
            // CASE 7b: Check if any contact has no Client_ID
            if (String.isBlank(existingContact.Client_ID__c)) {
                hasContactWithoutClientId = true;
            }
            
            // Track most recent contact (for 7b)
            if (existingContact.LastModifiedDate > mostRecentContact.LastModifiedDate) {
                mostRecentContact = existingContact;
            }
        }
        
        System.debug(LoggingLevel.INFO, 'Most recent contact Id: ' + mostRecentContact.Id + 
                    ', Client_ID__c: ' + mostRecentContact.Client_ID__c);
        
        // CASE 7a: Exact match found - UPDATE that specific contact
        if (matchingContact != null) {
            System.debug(LoggingLevel.INFO, 'SCENARIO 7a: Found exact Client_ID match - UPDATING contact ' + matchingContact.Id);
            
            updateContactFieldsFromSeaware(matchingContact, seawareClient, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(matchingContact);
            
            System.debug(LoggingLevel.INFO, 'Will UPDATE Contact Id: ' + matchingContact.Id);
        }
        // CASE 7b: At least one has no Client_ID - UPDATE most recent contact
        else if (hasContactWithoutClientId) {
            System.debug(LoggingLevel.INFO, 'SCENARIO 7b: At least one contact has no Client_ID - UPDATING most recent contact ' + mostRecentContact.Id);
            
            // Set the Client_ID on the most recent contact
            mostRecentContact.Client_ID__c = seawareClientId;
            
            updateContactFieldsFromSeaware(mostRecentContact, seawareClient, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(mostRecentContact);
            
            System.debug(LoggingLevel.INFO, 'Will UPDATE Contact Id: ' + mostRecentContact.Id + ' with Client_ID: ' + mostRecentContact.Client_ID__c);
        }
        // CASE 7c: All have different Client_IDs - CREATE NEW contact
        else {
            System.debug(LoggingLevel.INFO, 'SCENARIO 7c: All SF contacts have different Client_IDs - CREATING new contact');
            result.add(createContactFromSeawareClient(seawareClient, partyId,
                emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        return result;
    }

    /**
     * SCENARIO 8: Multiple SF Contacts + Multiple Seaware Clients
     */
    private List<Contact> handleScenario8(
        List<Object> seawareClients,
        List<Contact> existingContacts,
        String partyId,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        
        // Build map of SF contacts by Client_ID
        Map<String, Contact> sfContactsByClientId = new Map<String, Contact>();
        for (Contact existingContact : existingContacts) {
            if (!String.isBlank(existingContact.Client_ID__c)) {
                sfContactsByClientId.put(existingContact.Client_ID__c, existingContact);
            }
        }
        
        // Process each Seaware client
        for (Object seawareClient : seawareClients) {
            String seawareClientId = getClientIdFromSeawareClient(seawareClient);
            
            // If matching SF contact exists, update it
            if (sfContactsByClientId.containsKey(seawareClientId)) {
                System.debug(LoggingLevel.INFO, 'SCENARIO 8: Found matching Client_ID: ' + seawareClientId + ' - updating');
                Contact matchingContact = sfContactsByClientId.get(seawareClientId);
                updateContactFieldsFromSeaware(matchingContact, seawareClient, partyId,
                    emailByParty, phoneByParty, addressByParty, passportByParty);
                result.add(matchingContact);
            }
            // Otherwise create new
            else {
                System.debug(LoggingLevel.INFO, 'SCENARIO 8: No match for Client_ID: ' + seawareClientId + ' - creating new');
                result.add(createContactFromSeawareClient(seawareClient, partyId,
                    emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        }
        
        return result;
    }

    // Query methods
    private Map<String, String> queryEmailContactPointsCDP(Set<String> partyIds) {
        Map<String, String> emailByParty = new Map<String, String>();
        if (partyIds.isEmpty()) return emailByParty;
        
        try {
            String sql = 'SELECT ssot__PartyId__c, ssot__EmailAddress__c ' +
                        'FROM ssot__ContactPointEmail__dlm ' +
                        'WHERE ssot__EmailAddress__c =\'writebackscenario5a@accelerize360.com\' AND ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            
            List<Map<String, Object>> emailRecords = DC_CdpQueryUtil.executeQuery(sql);
            
            for (Map<String, Object> emailRec : emailRecords) {
                String partyId = (String) emailRec.get('ssot__PartyId__c');
                String email = (String) emailRec.get('ssot__EmailAddress__c');
                if (!String.isBlank(partyId) && !String.isBlank(email)) {
                    if (!emailByParty.containsKey(partyId)) {
                        emailByParty.put(partyId, email);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying email: ' + e.getMessage());
        }
        
        return emailByParty;
    }

    private Map<String, String> queryPhoneContactPointsCDP(Set<String> partyIds) {
        Map<String, String> phoneByParty = new Map<String, String>();
        if (partyIds.isEmpty()) return phoneByParty;
        
        try {
            String sql = 'SELECT ssot__PartyId__c, ssot__FormattedE164PhoneNumber__c ' +
                        'FROM ssot__ContactPointPhone__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            
            List<Map<String, Object>> phoneRecords = DC_CdpQueryUtil.executeQuery(sql);
            
            for (Map<String, Object> phoneRec : phoneRecords) {
                String partyId = (String) phoneRec.get('ssot__PartyId__c');
                String phone = (String) phoneRec.get('ssot__FormattedE164PhoneNumber__c');
                if (!String.isBlank(partyId) && !String.isBlank(phone)) {
                    if (!phoneByParty.containsKey(partyId)) {
                        phoneByParty.put(partyId, phone);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying phone: ' + e.getMessage());
        }
        
        return phoneByParty;
    }

    private Map<String, Map<String, Object>> queryAddressContactPointsCDP(Set<String> partyIds) {
        Map<String, Map<String, Object>> addressByParty = new Map<String, Map<String, Object>>();
        if (partyIds.isEmpty()) return addressByParty;
        
        try {
            String sql = 'SELECT ssot__PartyId__c, ssot__AddressLine1__c, ssot__CityId__c, ' +
                        'ssot__StateProvinceId__c, ssot__CountryId__c, Zipcode__c ' +
                        'FROM ssot__ContactPointAddress__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            
            List<Map<String, Object>> addressRecords = DC_CdpQueryUtil.executeQuery(sql);
            
            for (Map<String, Object> addressRec : addressRecords) {
                String partyId = (String) addressRec.get('ssot__PartyId__c');
                if (!String.isBlank(partyId) && !addressByParty.containsKey(partyId)) {
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
            System.debug(LoggingLevel.ERROR, 'Error querying address: ' + e.getMessage());
        }
        
        return addressByParty;
    }

    private Map<String, Map<String, Object>> queryPassportDataCDP(Set<String> partyIds) {
        Map<String, Map<String, Object>> passportByParty = new Map<String, Map<String, Object>>();
        if (partyIds.isEmpty()) return passportByParty;
        
        try {
            String sql = 'SELECT ssot__PartyId__c, ssot__IdentificationNumber__c, ssot__IssuedAtLocation__c, ' +
                        'Issued_Date__c, Expiration_Date__c ' +
                        'FROM ssot__PartyIdentification__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            
            List<Map<String, Object>> passportRecords = DC_CdpQueryUtil.executeQuery(sql);
            
            for (Map<String, Object> passportRec : passportRecords) {
                String partyId = (String) passportRec.get('ssot__PartyId__c');
                if (!String.isBlank(partyId) && !passportByParty.containsKey(partyId)) {
                    Map<String, Object> passport = new Map<String, Object>();
                    passport.put('Passport_Number__c', passportRec.get('ssot__IdentificationNumber__c'));
                    passport.put('Passport_Issue_Country__c', passportRec.get('ssot__IssuedAtLocation__c'));
                    passport.put('Passport_Issue_Date__c', convertToDate(passportRec.get('Issued_Date__c')));
                    passport.put('Passport_Expire_Date__c', convertToDate(passportRec.get('Expiration_Date__c')));
                    passportByParty.put(partyId, passport);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying passport: ' + e.getMessage());
        }
        
        return passportByParty;
    }

    private Map<String, List<Contact>> queryExistingContactsByParty(
        Set<String> partyIds, 
        Map<String, String> emailToPartyMap, 
        Map<String, String> phoneToPartyMap) {
        
        Map<String, List<Contact>> result = new Map<String, List<Contact>>();
        
        for (String partyId : partyIds) {
            result.put(partyId, new List<Contact>());
        }
        
        Set<String> emailsToSearch = new Set<String>(emailToPartyMap.values());
        Set<String> phonesToSearch = new Set<String>(phoneToPartyMap.values());
        
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
        
        for (Contact contact : existingContacts) {
            String matchedPartyId = null;
            
            if (!String.isBlank(contact.Email)) {
                for (String partyId : emailToPartyMap.keySet()) {
                    if (emailToPartyMap.get(partyId) == contact.Email) {
                        matchedPartyId = partyId;
                        break;
                    }
                }
            }
            
            if (matchedPartyId == null && !String.isBlank(contact.Phone)) {
                for (String partyId : phoneToPartyMap.keySet()) {
                    if (phoneToPartyMap.get(partyId) == contact.Phone) {
                        matchedPartyId = partyId;
                        break;
                    }
                }
            }
            
            if (matchedPartyId != null && result.containsKey(matchedPartyId)) {
                result.get(matchedPartyId).add(contact);
            }
        }
        
        return result;
    }

    private Contact createContactFromSeawareClient(
        Object src, String partyId, 
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        Contact client = new Contact();
        
        String clientId = getClientIdFromSeawareClient(src);
        setFieldValue(client, CLIENT_EXTID, clientId);
        client.RecordTypeId = getClientRecordTypeId();

        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue;
            
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                Object value = getFieldValue(src, mapping.src);
                if (value != null) {
                    setFieldValue(client, mapping.tgt, value);
                }
            }
        }

        applyContactPointData(client, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
        return client;
    }

    /**
     * NEW HELPER: Update contact fields from Seaware without touching Client_ID
     * This is separated to handle the Client_ID assignment explicitly in each scenario
     */
    private void updateContactFieldsFromSeaware(
        Contact existingContact, Object src, String partyId,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        // Update all fields EXCEPT Client_ID (handled explicitly in scenarios)
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue; // Skip - handled in scenario logic
            
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                Object value = getFieldValue(src, mapping.src);
                if (value != null) {
                    setFieldValue(existingContact, mapping.tgt, value);
                }
            }
        }

        applyContactPointData(existingContact, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
    }

    private void applyContactPointData(
        Contact targetContact, String partyId,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty,
        Map<String, Map<String, Object>> passportByParty) {
        
        if (emailByParty.containsKey(partyId)) {
            targetContact.Email = emailByParty.get(partyId);
        }
        
        if (phoneByParty.containsKey(partyId)) {
            targetContact.Phone = phoneByParty.get(partyId);
        }
        
        if (addressByParty.containsKey(partyId)) {
            Map<String, Object> address = addressByParty.get(partyId);
            if (address.get('MailingStreet') != null) targetContact.MailingStreet = (String)address.get('MailingStreet');
            if (address.get('MailingCity') != null) targetContact.MailingCity = (String)address.get('MailingCity');
            if (address.get('MailingState') != null) targetContact.MailingState = (String)address.get('MailingState');
            if (address.get('MailingCountry') != null) targetContact.MailingCountry = (String)address.get('MailingCountry');
            if (address.get('MailingPostalCode') != null) targetContact.MailingPostalCode = (String)address.get('MailingPostalCode');
        }
        
        if (passportByParty.containsKey(partyId)) {
            Map<String, Object> passport = passportByParty.get(partyId);
            if (passport.get('Passport_Number__c') != null) targetContact.Passport_Number__c = (String)passport.get('Passport_Number__c');
            if (passport.get('Passport_Issue_Country__c') != null) targetContact.Passport_Issue_Country__c = (String)passport.get('Passport_Issue_Country__c');
            if (passport.get('Passport_Issue_Date__c') != null) targetContact.Passport_Issue_Date__c = (Date)passport.get('Passport_Issue_Date__c');
            if (passport.get('Passport_Expire_Date__c') != null) targetContact.Passport_Expire_Date__c = (Date)passport.get('Passport_Expire_Date__c');
        }
    }

    private String getClientIdFromSeawareClient(Object src) {
        String clientId = (String) getFieldValue(src, 'Client_ID__c');
        if (String.isBlank(clientId)) clientId = (String) getFieldValue(src, 'ssot__Id__c');
        if (String.isBlank(clientId)) clientId = (String) getFieldValue(src, 'ssot__PartyId__c');
        return clientId;
    }

    private Object findMostRecentSeawareClient(List<Object> clients) {
        Object mostRecent = clients[0];
        DateTime mostRecentDate = convertToDateTime(getFieldValue(mostRecent, 'ssot__LastModifiedDate__c'));
        
        for (Object client : clients) {
            DateTime clientDate = convertToDateTime(getFieldValue(client, 'ssot__LastModifiedDate__c'));
            if (clientDate != null && (mostRecentDate == null || clientDate > mostRecentDate)) {
                mostRecent = client;
                mostRecentDate = clientDate;
            }
        }
        return mostRecent;
    }

    private Id getClientRecordTypeId() {
        try {
            return Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Client').getRecordTypeId();
        } catch (Exception e) {
            System.debug('Client RecordType not found');
            return null;
        }
    }

    public override void afterUpsert(Object scopeObj, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
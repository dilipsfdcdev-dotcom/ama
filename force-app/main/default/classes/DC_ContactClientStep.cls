public with sharing class DC_ContactClientStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Individual__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String CLIENT_EXTID = 'Client_ID__c';
    private static final String STEP_NAME = 'Client';

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
            clientsByParty.keySet(), emailByParty, phoneByParty, clientsByParty);
        
        List<SObject> contactsToUpdate = new List<SObject>();
        List<SObject> contactsToInsert = new List<SObject>();
        
        for (String partyId : clientsByParty.keySet()) {
            List<Object> seawareClients = clientsByParty.get(partyId);
            List<Contact> existingContacts = existingContactsByParty.get(partyId);
            
            Map<String, List<Contact>> processedContacts = processUnifiedProfileWithSeparation(
                seawareClients, existingContacts, partyId, 
                emailByParty, phoneByParty, addressByParty, passportByParty);
            
            contactsToUpdate.addAll(processedContacts.get('update'));
            contactsToInsert.addAll(processedContacts.get('insert'));
        }

        System.debug(LoggingLevel.WARN, 'Total to UPDATE: ' + contactsToUpdate.size());
        System.debug(LoggingLevel.WARN, 'Total to INSERT: ' + contactsToInsert.size());
        System.debug(LoggingLevel.WARN, '=== CLIENT STEP END ===');
        
        return new DC_UpsertBundle(contactsToInsert, contactsToUpdate, CLIENT_EXTID);
    }

    private Map<String, List<Contact>> processUnifiedProfileWithSeparation(
        List<Object> seawareClients, List<Contact> existingContacts, String partyId,
        Map<String, String> emailByParty, Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty, Map<String, Map<String, Object>> passportByParty) {
        
        Map<String, List<Contact>> result = new Map<String, List<Contact>>{
            'update' => new List<Contact>(), 'insert' => new List<Contact>()
        };
        
        List<Contact> processedContacts = processUnifiedProfile(
            seawareClients, existingContacts, partyId,
            emailByParty, phoneByParty, addressByParty, passportByParty);
        
        for (Contact contact : processedContacts) {
            if (contact.Id != null) {
                result.get('update').add(contact);
            } else {
                result.get('insert').add(contact);
            }
        }
        return result;
    }

    private List<Contact> processUnifiedProfile(
        List<Object> seawareClients, List<Contact> existingContacts, String partyId,
        Map<String, String> emailByParty, Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty, Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        Integer seawareCount = seawareClients.size();
        Integer salesforceCount = existingContacts.size();
        
        System.debug(LoggingLevel.WARN, 'Processing Party ID: ' + partyId);
        System.debug(LoggingLevel.WARN, 'Seaware Clients: ' + seawareCount + ', Salesforce Contacts: ' + salesforceCount);
        
        if (seawareCount == 1 && salesforceCount == 0) {
            result.add(createContactFromSeawareClient(seawareClients[0], partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        else if (seawareCount > 1 && salesforceCount == 0) {
            for (Object seawareClient : seawareClients) {
                result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        }
        else if (seawareCount == 1 && salesforceCount == 1) {
            result.addAll(handleScenario5(seawareClients[0], existingContacts[0], partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        else if (seawareCount > 1 && salesforceCount == 1) {
            result.addAll(handleScenario6(seawareClients, existingContacts[0], partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        else if (seawareCount == 1 && salesforceCount > 1) {
            result.addAll(handleScenario7(seawareClients[0], existingContacts, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        else if (seawareCount > 1 && salesforceCount > 1) {
            result.addAll(handleScenario8(seawareClients, existingContacts, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        return result;
    }

    private List<Contact> handleScenario5(Object seawareClient, Contact existingContact, String partyId,
        Map<String, String> emailByParty, Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty, Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        String sfClientId = existingContact.Client_ID__c;
        
        if (String.isBlank(sfClientId)) {
            Contact contactToUpdate = new Contact(Id = existingContact.Id);
            contactToUpdate.Client_ID__c = seawareClientId;
            updateContactFieldsFromSeaware(contactToUpdate, seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(contactToUpdate);
        }
        else if (sfClientId == seawareClientId) {
            Contact contactToUpdate = new Contact(Id = existingContact.Id);
            contactToUpdate.Client_ID__c = sfClientId;
            updateContactFieldsFromSeaware(contactToUpdate, seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(contactToUpdate);
        }
        else {
            result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        return result;
    }

    /**
     * FIXED SCENARIO 6: Multiple Seaware Clients, 1 Salesforce Contact (without Client_ID)
     * Update SF contact with MOST RECENTLY MODIFIED Seaware Client, create new contacts for others
     */
    private List<Contact> handleScenario6(List<Object> seawareClients, Contact existingContact, String partyId,
        Map<String, String> emailByParty, Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty, Map<String, Map<String, Object>> passportByParty) {
        
        System.debug(LoggingLevel.WARN, '=== SCENARIO 6: Multiple Seaware (' + seawareClients.size() + '), 1 SF Contact ===');
        
        List<Contact> result = new List<Contact>();
        String sfClientId = existingContact.Client_ID__c;
        
        // Sort Seaware clients by last modified date to find the most recent one
        List<Object> sortedSeawareClients = new List<Object>(seawareClients);
        sortSeawareClientsByLastModified(sortedSeawareClients);
        
        Object mostRecentSeawareClient = sortedSeawareClients[0]; // First one after sorting is most recent
        DateTime mostRecentDate = convertToDateTime(getFieldValue(mostRecentSeawareClient, 'ssot__LastModifiedDate__c'));
        
        System.debug(LoggingLevel.WARN, 'Most recent Seaware Client ID: ' + getClientIdFromSeawareClient(mostRecentSeawareClient));
        System.debug(LoggingLevel.WARN, 'Most recent modified date: ' + mostRecentDate);
        System.debug(LoggingLevel.WARN, 'Existing SF Contact Client_ID: ' + sfClientId);
        
        // Case 1: SF Contact has no Client_ID - update with most recent Seaware Client
        if (String.isBlank(sfClientId)) {
            System.debug(LoggingLevel.WARN, 'Case: SF Contact has NO Client_ID - updating with most recent Seaware Client');
            
            Contact contactToUpdate = new Contact(Id = existingContact.Id);
            contactToUpdate.Client_ID__c = getClientIdFromSeawareClient(mostRecentSeawareClient);
            updateContactFieldsFromSeaware(contactToUpdate, mostRecentSeawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(contactToUpdate);
            
            System.debug(LoggingLevel.WARN, 'Updated Contact with ID: ' + existingContact.Id + ', new Client_ID: ' + contactToUpdate.Client_ID__c);
            
            // Create new contacts for all other Seaware Clients
            for (Integer i = 1; i < sortedSeawareClients.size(); i++) {
                Object seawareClient = sortedSeawareClients[i];
                String clientId = getClientIdFromSeawareClient(seawareClient);
                System.debug(LoggingLevel.WARN, 'Creating NEW contact for Seaware Client ID: ' + clientId);
                result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        }
        // Case 2: SF Contact has Client_ID - check for exact match
        else {
            System.debug(LoggingLevel.WARN, 'Case: SF Contact HAS Client_ID - checking for matches');
            
            Object matchingSeawareClient = null;
            List<Object> unmatchedSeawareClients = new List<Object>();
            
            for (Object seawareClient : sortedSeawareClients) {
                String seawareClientId = getClientIdFromSeawareClient(seawareClient);
                if (sfClientId == seawareClientId) {
                    matchingSeawareClient = seawareClient;
                    System.debug(LoggingLevel.WARN, 'Found MATCHING Seaware Client ID: ' + seawareClientId);
                } else {
                    unmatchedSeawareClients.add(seawareClient);
                }
            }
            
            if (matchingSeawareClient != null) {
                // Update existing contact with matching Seaware Client
                System.debug(LoggingLevel.WARN, 'Updating SF Contact with matching Seaware Client');
                Contact contactToUpdate = new Contact(Id = existingContact.Id);
                contactToUpdate.Client_ID__c = sfClientId;
                updateContactFieldsFromSeaware(contactToUpdate, matchingSeawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
                result.add(contactToUpdate);
                
                // Create new contacts for unmatched Seaware Clients
                for (Object seawareClient : unmatchedSeawareClients) {
                    System.debug(LoggingLevel.WARN, 'Creating NEW contact for unmatched Seaware Client ID: ' + getClientIdFromSeawareClient(seawareClient));
                    result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
                }
            } else {
                // No match found - create new contacts for ALL Seaware Clients
                System.debug(LoggingLevel.WARN, 'No matching Client_ID found - creating NEW contacts for all Seaware Clients');
                for (Object seawareClient : sortedSeawareClients) {
                    System.debug(LoggingLevel.WARN, 'Creating NEW contact for Seaware Client ID: ' + getClientIdFromSeawareClient(seawareClient));
                    result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
                }
            }
        }
        
        System.debug(LoggingLevel.WARN, 'Scenario 6 Result: ' + result.size() + ' contacts (updates + inserts)');
        return result;
    }

    /**
     * FIXED SCENARIO 7: 1 Seaware Client, Multiple Salesforce Contacts (without Client_IDs)
     * Update MOST RECENTLY MODIFIED Salesforce Contact, leave others unchanged
     */
    private List<Contact> handleScenario7(Object seawareClient, List<Contact> existingContacts, String partyId,
        Map<String, String> emailByParty, Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty, Map<String, Map<String, Object>> passportByParty) {
        
        System.debug(LoggingLevel.WARN, '=== SCENARIO 7: 1 Seaware Client, Multiple SF Contacts (' + existingContacts.size() + ') ===');
        
        List<Contact> result = new List<Contact>();
        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
        
        System.debug(LoggingLevel.WARN, 'Seaware Client ID: ' + seawareClientId);
        
        // Check for existing SF Contact with matching Client_ID
        Contact matchingContact = null;
        Contact mostRecentContactWithoutId = null;
        DateTime mostRecentDate = null;
        
        for (Contact existingContact : existingContacts) {
            System.debug(LoggingLevel.WARN, 'Checking SF Contact Id: ' + existingContact.Id + 
                        ', Client_ID: ' + existingContact.Client_ID__c + 
                        ', LastModifiedDate: ' + existingContact.LastModifiedDate);
            
            // Case 1: Found exact match by Client_ID
            if (!String.isBlank(existingContact.Client_ID__c) && existingContact.Client_ID__c == seawareClientId) {
                matchingContact = existingContact;
                System.debug(LoggingLevel.WARN, 'Found MATCHING Contact with Client_ID: ' + existingContact.Client_ID__c);
            }
            
            // Case 2: Track most recently modified contact WITHOUT Client_ID
            if (String.isBlank(existingContact.Client_ID__c)) {
                if (mostRecentContactWithoutId == null || existingContact.LastModifiedDate > mostRecentDate) {
                    mostRecentContactWithoutId = existingContact;
                    mostRecentDate = existingContact.LastModifiedDate;
                    System.debug(LoggingLevel.WARN, 'New most recent contact without Client_ID: ' + existingContact.Id + 
                                ', LastModified: ' + mostRecentDate);
                }
            }
        }
        
        // Decision logic:
        if (matchingContact != null) {
            // Update the contact that already has matching Client_ID
            System.debug(LoggingLevel.WARN, 'Case: Found matching Client_ID - updating Contact Id: ' + matchingContact.Id);
            Contact contactToUpdate = new Contact(Id = matchingContact.Id);
            contactToUpdate.Client_ID__c = seawareClientId;
            updateContactFieldsFromSeaware(contactToUpdate, seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(contactToUpdate);
        }
        else if (mostRecentContactWithoutId != null) {
            // Update most recently modified contact that has no Client_ID
            System.debug(LoggingLevel.WARN, 'Case: No matching Client_ID - updating MOST RECENT contact without Client_ID');
            System.debug(LoggingLevel.WARN, 'Updating Contact Id: ' + mostRecentContactWithoutId.Id + 
                        ', LastModified: ' + mostRecentDate);
            Contact contactToUpdate = new Contact(Id = mostRecentContactWithoutId.Id);
            contactToUpdate.Client_ID__c = seawareClientId;
            updateContactFieldsFromSeaware(contactToUpdate, seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(contactToUpdate);
        }
        else {
            // All contacts have Client_IDs that don't match - create new contact
            System.debug(LoggingLevel.WARN, 'Case: All SF Contacts have different Client_IDs - creating NEW contact');
            result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
        }
        
        System.debug(LoggingLevel.WARN, 'Scenario 7 Result: ' + result.size() + ' contact(s) to update/insert');
        return result;
    }

    private List<Contact> handleScenario8(List<Object> seawareClients, List<Contact> existingContacts, String partyId,
        Map<String, String> emailByParty, Map<String, String> phoneByParty,
        Map<String, Map<String, Object>> addressByParty, Map<String, Map<String, Object>> passportByParty) {
        
        List<Contact> result = new List<Contact>();
        Map<String, Contact> sfContactsByClientId = new Map<String, Contact>();
        for (Contact existingContact : existingContacts) {
            if (!String.isBlank(existingContact.Client_ID__c)) {
                sfContactsByClientId.put(existingContact.Client_ID__c, existingContact);
            }
        }
        
        for (Object seawareClient : seawareClients) {
            String seawareClientId = getClientIdFromSeawareClient(seawareClient);
            if (sfContactsByClientId.containsKey(seawareClientId)) {
                Contact contactToUpdate = new Contact(Id = sfContactsByClientId.get(seawareClientId).Id);
                contactToUpdate.Client_ID__c = seawareClientId;
                updateContactFieldsFromSeaware(contactToUpdate, seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
                result.add(contactToUpdate);
            }
            else {
                result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        }
        return result;
    }

    /**
     * NEW HELPER METHOD: Sort Seaware clients by LastModifiedDate (newest first)
     */
    private void sortSeawareClientsByLastModified(List<Object> seawareClients) {
        // Simple bubble sort by LastModifiedDate (newest first)
        for (Integer i = 0; i < seawareClients.size() - 1; i++) {
            for (Integer j = 0; j < seawareClients.size() - i - 1; j++) {
                DateTime date1 = convertToDateTime(getFieldValue(seawareClients[j], 'ssot__LastModifiedDate__c'));
                DateTime date2 = convertToDateTime(getFieldValue(seawareClients[j + 1], 'ssot__LastModifiedDate__c'));
                
                if (date1 == null || (date2 != null && date1 < date2)) {
                    // Swap
                    Object temp = seawareClients[j];
                    seawareClients[j] = seawareClients[j + 1];
                    seawareClients[j + 1] = temp;
                }
            }
        }
    }

    private Map<String, String> queryEmailContactPointsCDP(Set<String> partyIds) {
        Map<String, String> emailByParty = new Map<String, String>();
        if (partyIds.isEmpty()) return emailByParty;
        try {
            String sql = 'SELECT ssot__PartyId__c, ssot__EmailAddress__c FROM ssot__ContactPointEmail__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' +String.join(new List<String>(partyIds), '\', \'') + '\')';
            for (Map<String, Object> emailRec : DC_CdpQueryUtil.executeQuery(sql)) {
                String partyId = (String) emailRec.get('ssot__PartyId__c');
                String email = (String) emailRec.get('ssot__EmailAddress__c');
                if (!String.isBlank(partyId) && !String.isBlank(email) && !emailByParty.containsKey(partyId)) {
                    emailByParty.put(partyId, email);
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
            String sql = 'SELECT ssot__PartyId__c, ssot__FormattedE164PhoneNumber__c FROM ssot__ContactPointPhone__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            for (Map<String, Object> phoneRec : DC_CdpQueryUtil.executeQuery(sql)) {
                String partyId = (String) phoneRec.get('ssot__PartyId__c');
                String phone = (String) phoneRec.get('ssot__FormattedE164PhoneNumber__c');
                if (!String.isBlank(partyId) && !String.isBlank(phone) && !phoneByParty.containsKey(partyId)) {
                    phoneByParty.put(partyId, phone);
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
                        'ssot__StateProvinceId__c, ssot__CountryId__c, Zipcode__c FROM ssot__ContactPointAddress__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            for (Map<String, Object> addressRec : DC_CdpQueryUtil.executeQuery(sql)) {
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
                        'Issued_Date__c, Expiration_Date__c FROM ssot__PartyIdentification__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            for (Map<String, Object> passportRec : DC_CdpQueryUtil.executeQuery(sql)) {
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
        Set<String> partyIds, Map<String, String> emailToPartyMap, Map<String, String> phoneToPartyMap,
        Map<String, List<Object>> clientsByParty) {
        
        Map<String, List<Contact>> result = new Map<String, List<Contact>>();
        for (String partyId : partyIds) result.put(partyId, new List<Contact>());
        
        Set<String> emailsToSearch = new Set<String>(emailToPartyMap.values());
        Set<String> phonesToSearch = new Set<String>(phoneToPartyMap.values());
        List<Contact> existingContacts = new List<Contact>();
        Set<Id> processedContactIds = new Set<Id>();
        
        if (!emailsToSearch.isEmpty()) {
            for (Contact c : [SELECT Id, Client_ID__c, Email, Phone, LastModifiedDate FROM Contact
                             WHERE RecordType.Name = 'Client' AND Email IN :emailsToSearch
                             FOR UPDATE]) {
                existingContacts.add(c);
                processedContactIds.add(c.Id);
            }
        }

        if (!phonesToSearch.isEmpty()) {
            for (Contact c : [SELECT Id, Client_ID__c, Email, Phone, LastModifiedDate FROM Contact
                             WHERE RecordType.Name = 'Client' AND Phone IN :phonesToSearch AND Id NOT IN :processedContactIds
                             FOR UPDATE]) {
                existingContacts.add(c);
                processedContactIds.add(c.Id);
            }
        }

        // NEW: Query by Client_ID to find all existing contacts with matching Client IDs
        Set<String> clientIdsToSearch = new Set<String>();
        for (String partyId : clientsByParty.keySet()) {
            for (Object seawareClient : clientsByParty.get(partyId)) {
                String clientId = getClientIdFromSeawareClient(seawareClient);
                if (!String.isBlank(clientId)) {
                    clientIdsToSearch.add(clientId);
                }
            }
        }

        if (!clientIdsToSearch.isEmpty()) {
            for (Contact c : [SELECT Id, Client_ID__c, Email, Phone, LastModifiedDate FROM Contact
                             WHERE RecordType.Name = 'Client' AND Client_ID__c IN :clientIdsToSearch
                             AND Id NOT IN :processedContactIds
                             FOR UPDATE]) {
                existingContacts.add(c);
                processedContactIds.add(c.Id);
            }
        }

        for (Contact contact : existingContacts) {
            String matchedPartyId = null;

            // Priority 1: Match by Client_ID (most reliable)
            if (!String.isBlank(contact.Client_ID__c)) {
                for (String partyId : clientsByParty.keySet()) {
                    for (Object seawareClient : clientsByParty.get(partyId)) {
                        String seawareClientId = getClientIdFromSeawareClient(seawareClient);
                        if (!String.isBlank(seawareClientId) && seawareClientId == contact.Client_ID__c) {
                            matchedPartyId = partyId;
                            break;
                        }
                    }
                    if (matchedPartyId != null) break;
                }
            }

            // Priority 2: Match by Email (if not matched by Client_ID)
            if (matchedPartyId == null && !String.isBlank(contact.Email)) {
                for (String partyId : emailToPartyMap.keySet()) {
                    if (emailToPartyMap.get(partyId) == contact.Email) {
                        matchedPartyId = partyId;
                        break;
                    }
                }
            }

            // Priority 3: Match by Phone (if not matched by Client_ID or Email)
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

    private Contact createContactFromSeawareClient(Object src, String partyId, Map<String, String> emailByParty, 
        Map<String, String> phoneByParty, Map<String, Map<String, Object>> addressByParty, 
        Map<String, Map<String, Object>> passportByParty) {
        
        Contact client = new Contact();
        client.Client_ID__c = getClientIdFromSeawareClient(src);
        client.RecordTypeId = getClientRecordTypeId();
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue;
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                Object value = getFieldValue(src, mapping.src);
                if (value != null) setFieldValue(client, mapping.tgt, value);
            }
        }
        applyContactPointData(client, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
        return client;
    }

    private void updateContactFieldsFromSeaware(Contact existingContact, Object src, String partyId, 
        Map<String, String> emailByParty, Map<String, String> phoneByParty, 
        Map<String, Map<String, Object>> addressByParty, Map<String, Map<String, Object>> passportByParty) {
        
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue;
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                Object value = getFieldValue(src, mapping.src);
                if (value != null) setFieldValue(existingContact, mapping.tgt, value);
            }
        }
        applyContactPointData(existingContact, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
    }

    private void applyContactPointData(Contact targetContact, String partyId, Map<String, String> emailByParty, 
        Map<String, String> phoneByParty, Map<String, Map<String, Object>> addressByParty, 
        Map<String, Map<String, Object>> passportByParty) {
        
        if (emailByParty.containsKey(partyId)) targetContact.Email = emailByParty.get(partyId);
        if (phoneByParty.containsKey(partyId)) targetContact.Phone = phoneByParty.get(partyId);
        
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
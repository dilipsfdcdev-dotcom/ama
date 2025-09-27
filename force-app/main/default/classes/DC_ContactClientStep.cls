public with sharing class DC_ContactClientStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT = 'ssot__Individual__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String CLIENT_EXTID = 'Client_ID__c';
    private static final String STEP_NAME = 'Client';

    public override String sourceObjectApi() { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        // **FIX: Use CDP timestamp function for proper date filtering**
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME, 'ssot__LastModifiedDate__c');
        return 'ssot__DataSourceObjectId__c = \'Seaware_Client_E1C50A05\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        
        // Add only main Individual fields (no relationship fields for CDP)
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                f.add(mapping.src);
            }
        }
        
        // Add required fields
        f.add(ORDER_BY_SRC);
        f.add('ssot__PartyId__c');
        f.add('ssot__LastModifiedDate__c');
        
        return f;
    }

    // No additional sources - we'll query them separately via CDP
    public override Map<String, DC_JoinConfig> getAdditionalSources() {
        return new Map<String, DC_JoinConfig>();
    }

    public override DC_UpsertBundle mapScope(List<SObject> scope) {
        // Group clients by unified profile (ssot__PartyId__c)
        Map<String, List<SObject>> clientsByParty = new Map<String, List<SObject>>();
        for (SObject src : scope) {
            String partyId = (String) getFieldValue(src, 'ssot__PartyId__c');
            if (!String.isBlank(partyId)) {
                if (!clientsByParty.containsKey(partyId)) {
                    clientsByParty.put(partyId, new List<SObject>());
                }
                clientsByParty.get(partyId).add(src);
            }
        }

        // Query contact points for all parties using CDP with timestamp functions
        Set<String> allPartyIds = clientsByParty.keySet();
        Map<String, String> emailByParty = queryEmailContactPointsCDP(allPartyIds);
        Map<String, String> phoneByParty = queryPhoneContactPointsCDP(allPartyIds);
        Map<String, Map<String, Object>> addressByParty = queryAddressContactPointsCDP(allPartyIds);
        Map<String, Map<String, Object>> passportByParty = queryPassportDataCDP(allPartyIds);

        // Get existing contacts using contact point data for matching
        Map<String, List<Contact>> existingContactsByParty = queryExistingContactsByParty(clientsByParty.keySet(), emailByParty, phoneByParty);
        
        List<SObject> contactsToUpsert = new List<SObject>();
        
        // Process each unified profile
        for (String partyId : clientsByParty.keySet()) {
            List<SObject> seawareClients = clientsByParty.get(partyId);
            List<Contact> existingContacts = existingContactsByParty.get(partyId);
            
            List<Contact> processedContacts = processUnifiedProfile(seawareClients, existingContacts, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
            contactsToUpsert.addAll(processedContacts);
        }

        return new DC_UpsertBundle(contactsToUpsert, CLIENT_EXTID);
    }

    private Map<String, String> queryEmailContactPointsCDP(Set<String> partyIds) {
        Map<String, String> emailByParty = new Map<String, String>();
        
        if (partyIds.isEmpty()) return emailByParty;
        
        try {
            // Build CDP SQL query
            String sql = 'SELECT ssot__PartyId__c, ssot__EmailAddress__c ' +
                        'FROM ssot__ContactPointEmail__dlm ' +
                        'WHERE ssot__PartyId__c IN (\'' + String.join(new List<String>(partyIds), '\', \'') + '\')';
            
            List<Map<String, Object>> emailRecords = DC_CdpQueryUtil.executeQuery(sql);
            
            for (Map<String, Object> emailRec : emailRecords) {
                String partyId = (String) emailRec.get('ssot__PartyId__c');
                String email = (String) emailRec.get('ssot__EmailAddress__c');
                if (!String.isBlank(partyId) && !String.isBlank(email)) {
                    // Use first email found per party
                    if (!emailByParty.containsKey(partyId)) {
                        emailByParty.put(partyId, email);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error querying email contact points via CDP: ' + e.getMessage());
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
            System.debug(LoggingLevel.ERROR, 'Error querying phone contact points via CDP: ' + e.getMessage());
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
            System.debug(LoggingLevel.ERROR, 'Error querying address contact points via CDP: ' + e.getMessage());
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
            System.debug(LoggingLevel.ERROR, 'Error querying passport data via CDP: ' + e.getMessage());
        }
        
        return passportByParty;
    }

    private Map<String, List<Contact>> queryExistingContactsByParty(Set<String> partyIds, Map<String, String> emailToPartyMap, Map<String, String> phoneToPartyMap) {
        Map<String, List<Contact>> result = new Map<String, List<Contact>>();
        
        // Initialize map
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
        
        // Map contacts back to party IDs
        for (Contact contact : existingContacts) {
            String matchedPartyId = null;
            
            // Find party ID by email
            if (!String.isBlank(contact.Email)) {
                for (String partyId : emailToPartyMap.keySet()) {
                    if (emailToPartyMap.get(partyId) == contact.Email) {
                        matchedPartyId = partyId;
                        break;
                    }
                }
            }
            
            // Find party ID by phone if not found by email
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

    private List<Contact> processUnifiedProfile(List<SObject> seawareClients, List<Contact> existingContacts, 
                                              String partyId, Map<String, String> emailByParty, 
                                              Map<String, String> phoneByParty, Map<String, Map<String, Object>> addressByParty,
                                              Map<String, Map<String, Object>> passportByParty) {
        List<Contact> result = new List<Contact>();
        
        Integer seawareCount = seawareClients.size();
        Integer salesforceCount = existingContacts.size();
        
        // Simplified processing - just create/update contacts without complex scenarios
        if (seawareCount > 0 && salesforceCount == 0) {
            // Create new contacts for each Seaware client
            for (SObject seawareClient : seawareClients) {
                result.add(createContactFromSeawareClient(seawareClient, partyId, emailByParty, phoneByParty, addressByParty, passportByParty));
            }
        } else if (seawareCount > 0 && salesforceCount > 0) {
            // Update existing contact with most recent Seaware data
            SObject mostRecent = findMostRecentSeawareClient(seawareClients);
            Contact existingContact = existingContacts[0]; // Use first existing contact
            updateContactFromSeawareClient(existingContact, mostRecent, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
            result.add(existingContact);
        }
        
        return result;
    }

    private Contact createContactFromSeawareClient(SObject src, String partyId, Map<String, String> emailByParty, 
                                                  Map<String, String> phoneByParty, Map<String, Map<String, Object>> addressByParty,
                                                  Map<String, Map<String, Object>> passportByParty) {
        Contact client = new Contact();
        
        // Set upsert key
        String clientId = getClientIdFromSeawareClient(src);
        setFieldValue(client, CLIENT_EXTID, clientId);

        // Set RecordType for Client - USING LOCAL METHOD TO AVOID INHERITANCE ISSUES
        client.RecordTypeId = getClientRecordTypeId();

        // Apply direct field mappings (using helper methods for CDP compatibility)
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue;
            
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                Object value = getFieldValue(src, mapping.src);
                if (value != null) {
                    setFieldValue(client, mapping.tgt, value);
                }
            }
        }

        // Apply contact point data
        applyContactPointData(client, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);

        return client;
    }

    private void updateContactFromSeawareClient(Contact existingContact, SObject src, String partyId,
                                              Map<String, String> emailByParty, Map<String, String> phoneByParty, 
                                              Map<String, Map<String, Object>> addressByParty,
                                              Map<String, Map<String, Object>> passportByParty) {
        String clientId = getClientIdFromSeawareClient(src);
        if (String.isBlank(existingContact.Client_ID__c)) {
            setFieldValue(existingContact, CLIENT_EXTID, clientId);
        }

        // Apply field mappings
        for (DC_FieldMap mapping : DC_Mappings.CONTACT_CLIENT_MAP) {
            if (mapping.tgt == 'Client_ID__c') continue;
            
            if (!DC_RelationshipQueryUtil.isRelationshipField(mapping.src)) {
                Object value = getFieldValue(src, mapping.src);
                if (value != null) {
                    setFieldValue(existingContact, mapping.tgt, value);
                }
            }
        }

        // Apply contact point data
        applyContactPointData(existingContact, partyId, emailByParty, phoneByParty, addressByParty, passportByParty);
    }

    private void applyContactPointData(Contact targetContact, String partyId, Map<String, String> emailByParty, 
                                     Map<String, String> phoneByParty, Map<String, Map<String, Object>> addressByParty,
                                     Map<String, Map<String, Object>> passportByParty) {
        // Set email
        if (emailByParty.containsKey(partyId)) {
            targetContact.Email = emailByParty.get(partyId);
        }
        
        // Set phone
        if (phoneByParty.containsKey(partyId)) {
            targetContact.Phone = phoneByParty.get(partyId);
        }
        
        // Set address
        if (addressByParty.containsKey(partyId)) {
            Map<String, Object> address = addressByParty.get(partyId);
            if (address.get('MailingStreet') != null) targetContact.MailingStreet = (String)address.get('MailingStreet');
            if (address.get('MailingCity') != null) targetContact.MailingCity = (String)address.get('MailingCity');
            if (address.get('MailingState') != null) targetContact.MailingState = (String)address.get('MailingState');
            if (address.get('MailingCountry') != null) targetContact.MailingCountry = (String)address.get('MailingCountry');
            if (address.get('MailingPostalCode') != null) targetContact.MailingPostalCode = (String)address.get('MailingPostalCode');
        }
        
        // Set passport data
        if (passportByParty.containsKey(partyId)) {
            Map<String, Object> passport = passportByParty.get(partyId);
            if (passport.get('Passport_Number__c') != null) targetContact.Passport_Number__c = (String)passport.get('Passport_Number__c');
            if (passport.get('Passport_Issue_Country__c') != null) targetContact.Passport_Issue_Country__c = (String)passport.get('Passport_Issue_Country__c');
            if (passport.get('Passport_Issue_Date__c') != null) targetContact.Passport_Issue_Date__c = (Date)passport.get('Passport_Issue_Date__c');
            if (passport.get('Passport_Expire_Date__c') != null) targetContact.Passport_Expire_Date__c = (Date)passport.get('Passport_Expire_Date__c');
        }
    }

    private String getClientIdFromSeawareClient(SObject src) {
        String clientId = (String) getFieldValue(src, 'Client_ID__c');
        if (String.isBlank(clientId)) clientId = (String) getFieldValue(src, 'ssot__Id__c');
        if (String.isBlank(clientId)) clientId = (String) getFieldValue(src, 'ssot__PartyId__c');
        return clientId;
    }

    private SObject findMostRecentSeawareClient(List<SObject> clients) {
        SObject mostRecent = clients[0];
        DateTime mostRecentDate = convertToDateTime(getFieldValue(mostRecent, 'ssot__LastModifiedDate__c'));
        
        for (SObject client : clients) {
            DateTime clientDate = convertToDateTime(getFieldValue(client, 'ssot__LastModifiedDate__c'));
            if (clientDate != null && (mostRecentDate == null || clientDate > mostRecentDate)) {
                mostRecent = client;
                mostRecentDate = clientDate;
            }
        }
        return mostRecent;
    }

    // LOCAL METHOD TO AVOID INHERITANCE ISSUES
    private Id getClientRecordTypeId() {
        try {
            return Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Client').getRecordTypeId();
        } catch (Exception e) {
            System.debug('Client RecordType not found');
            return null;
        }
    }

    public override void afterUpsert(List<SObject> scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // no-op
    }
}
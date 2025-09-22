@IsTest
private class DC_ContactClientStep_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Client record type
        // Note: In actual implementation, ensure Client record type exists
        
        // Create existing contact for testing
        Contact existingClient = new Contact(
            FirstName = 'Existing',
            LastName = 'Client',
            Email = 'existing@test.com',
            Client_ID__c = 'EXISTING_CLIENT_001'
        );
        insert existingClient;
    }
    
    @IsTest
    static void testSourceObjectApi() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        System.assertEquals('ssot__Individual__dlm', step.sourceObjectApi());
    }
    
    @IsTest
    static void testOrderBySourceField() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        System.assertEquals('ssot__Id__c', step.orderBySourceField());
    }
    
    @IsTest
    static void testWhereClause() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        String whereClause = step.whereClause();
        System.assert(whereClause.contains('ssot__DataSourceObjectId__c = \'Seaware_Client_E1C50A05\''));
        System.assert(whereClause.contains('ssot__LastModifiedDate__c = TODAY'));
    }
    
    @IsTest
    static void testSourceFields() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        Set<String> fields = step.sourceFields();
        
        System.assert(fields.contains('ssot__Id__c'));
        System.assert(fields.contains('ssot__PartyId__c'));
        System.assert(fields.contains('ssot__FirstName__c'));
        System.assert(fields.contains('ssot__LastName__c'));
        System.assert(fields.contains('ssot__LastModifiedDate__c'));
    }
    
    @IsTest
    static void testGetAdditionalSources() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        Map<String, DC_JoinConfig> additionalSources = step.getAdditionalSources();
        
        System.assertEquals(4, additionalSources.size());
        System.assert(additionalSources.containsKey('email'));
        System.assert(additionalSources.containsKey('phone'));
        System.assert(additionalSources.containsKey('address'));
        System.assert(additionalSources.containsKey('passport'));
        
        DC_JoinConfig emailConfig = additionalSources.get('email');
        System.assertEquals('ssot__ContactPointEmail__dlm', emailConfig.sourceObject);
        System.assertEquals('ssot__PartyId__c', emailConfig.joinField);
        System.assertEquals('ssot__PartyId__c', emailConfig.parentField);
    }
    
    @IsTest
    static void testMapMultiSourceScope_NewContact() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Create mock main source data
        Map<String, Object> clientData = new Map<String, Object>{
            'ssot__Id__c' => 'NEW_CLIENT_001',
            'ssot__PartyId__c' => 'PARTY_001',
            'ssot__FirstName__c' => 'John',
            'ssot__LastName__c' => 'Doe',
            'Client_ID__c' => 'NEW_CLIENT_001',
            'Birthday__c' => Date.today().addYears(-30),
            'ssot__LastModifiedDate__c' => DateTime.now()
        };
        
        SObject mockClient = createMockSObject(clientData);
        DC_MultiSourceData data = new DC_MultiSourceData(new List<SObject>{ mockClient });
        
        // Add email contact point data
        Map<String, Object> emailData = new Map<String, Object>{
            'ssot__EmailAddress__c' => 'john.doe@test.com',
            'ssot__PartyId__c' => 'PARTY_001'
        };
        SObject mockEmail = createMockSObject(emailData);
        data.addAdditionalData('email', 'PARTY_001', new List<SObject>{ mockEmail });
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapMultiSourceScope(data);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Client_ID__c', bundle.externalIdField);
        
        Contact resultContact = (Contact) bundle.records[0];
        System.assertEquals('NEW_CLIENT_001', resultContact.Client_ID__c);
        System.assertEquals('John', resultContact.FirstName);
        System.assertEquals('Doe', resultContact.LastName);
        System.assertEquals('john.doe@test.com', resultContact.Email);
    }
    
    @IsTest
    static void testMapMultiSourceScope_WithContactPoints() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Create comprehensive test data
        Map<String, Object> clientData = new Map<String, Object>{
            'ssot__Id__c' => 'FULL_CLIENT_001',
            'ssot__PartyId__c' => 'PARTY_FULL_001',
            'ssot__FirstName__c' => 'Jane',
            'ssot__LastName__c' => 'Smith',
            'Client_ID__c' => 'FULL_CLIENT_001',
            'ssot__LastModifiedDate__c' => DateTime.now()
        };
        
        SObject mockClient = createMockSObject(clientData);
        DC_MultiSourceData data = new DC_MultiSourceData(new List<SObject>{ mockClient });
        
        // Add all contact point types
        addEmailData(data, 'PARTY_FULL_001', 'jane.smith@test.com');
        addPhoneData(data, 'PARTY_FULL_001', '+1-555-123-4567');
        addAddressData(data, 'PARTY_FULL_001');
        addPassportData(data, 'PARTY_FULL_001');
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapMultiSourceScope(data);
        Test.stopTest();
        
        Contact resultContact = (Contact) bundle.records[0];
        System.assertEquals('jane.smith@test.com', resultContact.Email);
        System.assertEquals('+1-555-123-4567', resultContact.Phone);
        System.assertEquals('123 Test Street', resultContact.MailingStreet);
        System.assertEquals('Test City', resultContact.MailingCity);
        System.assertEquals('PASSPORT123', resultContact.Passport_Number__c);
    }
    
    @IsTest
    static void testProcessUnifiedProfile_MultipleScenarios() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Test scenario with multiple Seaware clients
        List<SObject> seawareClients = new List<SObject>();
        for (Integer i = 1; i <= 3; i++) {
            Map<String, Object> clientData = new Map<String, Object>{
                'ssot__Id__c' => 'MULTI_CLIENT_00' + i,
                'ssot__PartyId__c' => 'PARTY_MULTI_001',
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Client' + i,
                'Client_ID__c' => 'MULTI_CLIENT_00' + i,
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-i)
            };
            seawareClients.add(createMockSObject(clientData));
        }
        
        DC_MultiSourceData data = new DC_MultiSourceData(seawareClients);
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapMultiSourceScope(data);
        Test.stopTest();
        
        // Should create contacts for all Seaware clients when no existing Salesforce contacts
        System.assertEquals(3, bundle.records.size());
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Should not throw exception
        Test.startTest();
        step.afterUpsert(new List<SObject>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Client_ID__c'), 
                        new Database.UpsertResult[0]);
        Test.stopTest();
    }
    
    // Helper methods
    private static void addEmailData(DC_MultiSourceData data, String partyId, String email) {
        Map<String, Object> emailData = new Map<String, Object>{
            'ssot__EmailAddress__c' => email,
            'ssot__PartyId__c' => partyId
        };
        SObject mockEmail = createMockSObject(emailData);
        data.addAdditionalData('email', partyId, new List<SObject>{ mockEmail });
    }
    
    private static void addPhoneData(DC_MultiSourceData data, String partyId, String phone) {
        Map<String, Object> phoneData = new Map<String, Object>{
            'ssot__FormattedE164PhoneNumber__c' => phone,
            'ssot__PartyId__c' => partyId
        };
        SObject mockPhone = createMockSObject(phoneData);
        data.addAdditionalData('phone', partyId, new List<SObject>{ mockPhone });
    }
    
    private static void addAddressData(DC_MultiSourceData data, String partyId) {
        Map<String, Object> addressData = new Map<String, Object>{
            'ssot__AddressLine1__c' => '123 Test Street',
            'ssot__CityId__c' => 'Test City',
            'ssot__StateProvinceId__c' => 'Test State',
            'ssot__CountryId__c' => 'Test Country',
            'Zipcode__c' => '12345',
            'ssot__PartyId__c' => partyId
        };
        SObject mockAddress = createMockSObject(addressData);
        data.addAdditionalData('address', partyId, new List<SObject>{ mockAddress });
    }
    
    private static void addPassportData(DC_MultiSourceData data, String partyId) {
        Map<String, Object> passportData = new Map<String, Object>{
            'ssot__IdentificationNumber__c' => 'PASSPORT123',
            'ssot__IssuedAtLocation__c' => 'US',
            'Issued_Date__c' => Date.today().addYears(-5),
            'Expiration_Date__c' => Date.today().addYears(5),
            'ssot__PartyId__c' => partyId
        };
        SObject mockPassport = createMockSObject(passportData);
        data.addAdditionalData('passport', partyId, new List<SObject>{ mockPassport });
    }
    
    private static SObject createMockSObject(Map<String, Object> fieldValues) {
        // Create a Contact for testing since we can't create arbitrary SObject types
        Contact obj = new Contact();
        for (String field : fieldValues.keySet()) {
            try {
                obj.put(field, fieldValues.get(field));
            } catch (Exception e) {
                // Skip fields that don't exist
                System.debug('Field not accessible in test: ' + field);
            }
        }
        return obj;
    }
}
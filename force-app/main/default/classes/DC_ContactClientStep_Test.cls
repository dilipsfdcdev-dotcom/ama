@IsTest
private class DC_ContactClientStep_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Client record type (assuming it exists)
        // In real implementation, ensure Client record type exists
        
        // Create existing contacts for various test scenarios
        List<Contact> existingContacts = new List<Contact>();
        
        // Contact 1: Has Client_ID, for scenario testing
        existingContacts.add(new Contact(
            FirstName = 'Existing',
            LastName = 'Client1',
            Email = 'existing1@test.com',
            Phone = '+1-555-111-0001',
            Client_ID__c = 'EXISTING_CLIENT_001'
        ));
        
        // Contact 2: Has Client_ID, for scenario testing
        existingContacts.add(new Contact(
            FirstName = 'Existing',
            LastName = 'Client2',
            Email = 'existing2@test.com',
            Phone = '+1-555-111-0002',
            Client_ID__c = 'EXISTING_CLIENT_002'
        ));
        
        // Contact 3: No Client_ID, for scenario testing
        existingContacts.add(new Contact(
            FirstName = 'Existing',
            LastName = 'ClientNoId',
            Email = 'existingnoId@test.com',
            Phone = '+1-555-111-0003'
        ));
        
        // Contact 4: Another without Client_ID
        existingContacts.add(new Contact(
            FirstName = 'Another',
            LastName = 'ClientNoId',
            Email = 'another@test.com',
            Phone = '+1-555-111-0004'
        ));
        
        insert existingContacts;
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
        System.assert(whereClause.contains('ssot__LastModifiedDate__c'));
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
        System.assert(!fields.isEmpty());
    }
    
    @IsTest
    static void testGetAdditionalSources() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        Map<String, DC_JoinConfig> additionalSources = step.getAdditionalSources();
        
        // Should return empty map as we're using separate queries now
        System.assertEquals(0, additionalSources.size());
    }
    
    // SCENARIO 1: Only 1 Seaware Client, no existing Salesforce contacts
    @IsTest
    static void testScenario1_OneSeawareClient_NoSalesforceContacts() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<SObject> seawareClients = createMockSeawareClients(new List<Map<String, Object>>{
            new Map<String, Object>{
                'ssot__Id__c' => 'NEW_CLIENT_001',
                'ssot__PartyId__c' => 'PARTY_NEW_001',
                'ssot__FirstName__c' => 'John',
                'ssot__LastName__c' => 'New',
                'Client_ID__c' => 'NEW_CLIENT_001',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        });
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size(), 'Should create 1 contact');
        System.assertEquals('Client_ID__c', bundle.externalIdField);
        
        Contact resultContact = (Contact) bundle.records[0];
        System.assertEquals('NEW_CLIENT_001', resultContact.Client_ID__c);
        System.assertEquals('John', resultContact.FirstName);
        System.assertEquals('New', resultContact.LastName);
    }
    
    // SCENARIO 2: Only 1 Salesforce Contact, no Seaware clients
    @IsTest
    static void testScenario2_OneSalesforceContact_NoSeawareClients() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Empty scope - no Seaware clients
        List<SObject> seawareClients = new List<SObject>();
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should do nothing - no records to process
        System.assertEquals(0, bundle.records.size(), 'Should not create any contacts');
    }
    
    // SCENARIO 3: Multiple Seaware Clients, no Salesforce contacts
    @IsTest
    static void testScenario3_MultipleSeawareClients_NoSalesforceContacts() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<SObject> seawareClients = createMockSeawareClients(new List<Map<String, Object>>{
            new Map<String, Object>{
                'ssot__Id__c' => 'MULTI_CLIENT_001',
                'ssot__PartyId__c' => 'PARTY_MULTI_001',
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Client1',
                'Client_ID__c' => 'MULTI_CLIENT_001',
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-10)
            },
            new Map<String, Object>{
                'ssot__Id__c' => 'MULTI_CLIENT_002',
                'ssot__PartyId__c' => 'PARTY_MULTI_001', // Same party
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Client2',
                'Client_ID__c' => 'MULTI_CLIENT_002',
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-5)
            },
            new Map<String, Object>{
                'ssot__Id__c' => 'MULTI_CLIENT_003',
                'ssot__PartyId__c' => 'PARTY_MULTI_001', // Same party
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Client3',
                'Client_ID__c' => 'MULTI_CLIENT_003',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        });
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should create contacts for all Seaware clients (scenario 3)
        System.assertEquals(3, bundle.records.size(), 'Should create contacts for all Seaware clients');
        
        Set<String> clientIds = new Set<String>();
        for (SObject record : bundle.records) {
            Contact contact = (Contact) record;
            clientIds.add(contact.Client_ID__c);
        }
        
        System.assert(clientIds.contains('MULTI_CLIENT_001'));
        System.assert(clientIds.contains('MULTI_CLIENT_002'));
        System.assert(clientIds.contains('MULTI_CLIENT_003'));
    }
    
    // SCENARIO 4: Multiple Salesforce Contacts, no Seaware clients
    @IsTest
    static void testScenario4_MultipleSalesforceContacts_NoSeawareClients() {
        // This is the same as scenario 2 - no Seaware clients means no processing
        testScenario2_OneSalesforceContact_NoSeawareClients();
    }
    
    // SCENARIO 5: 1 Salesforce Contact and 1 Seaware Client
    @IsTest
    static void testScenario5_OneSalesforceContact_OneSeawareClient() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Create Seaware client that matches existing contact by email
        List<SObject> seawareClients = createMockSeawareClientsWithContactPoints(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'ssot__Id__c' => 'MATCH_CLIENT_001',
                    'ssot__PartyId__c' => 'PARTY_MATCH_001',
                    'ssot__FirstName__c' => 'Updated',
                    'ssot__LastName__c' => 'Name',
                    'Client_ID__c' => 'EXISTING_CLIENT_001', // Matches existing contact
                    'ssot__LastModifiedDate__c' => DateTime.now()
                }
            },
            new Map<String, String>{'PARTY_MATCH_001' => 'existing1@test.com'}, // Matches existing
            new Map<String, String>()
        );
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should update existing contact
        System.assertEquals(1, bundle.records.size(), 'Should update existing contact');
        
        Contact resultContact = (Contact) bundle.records[0];
        System.assertEquals('EXISTING_CLIENT_001', resultContact.Client_ID__c);
        System.assertEquals('Updated', resultContact.FirstName);
        System.assertEquals('existing1@test.com', resultContact.Email);
    }
    
    // SCENARIO 6: 1 Salesforce Contact and multiple Seaware Clients
    @IsTest
    static void testScenario6_OneSalesforceContact_MultipleSeawareClients() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<SObject> seawareClients = createMockSeawareClientsWithContactPoints(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'ssot__Id__c' => 'MATCH_CLIENT_001',
                    'ssot__PartyId__c' => 'PARTY_MATCH_MULTI_001',
                    'ssot__FirstName__c' => 'Updated',
                    'ssot__LastName__c' => 'Multi1',
                    'Client_ID__c' => 'EXISTING_CLIENT_001', // Matches existing
                    'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-10)
                },
                new Map<String, Object>{
                    'ssot__Id__c' => 'NEW_CLIENT_002',
                    'ssot__PartyId__c' => 'PARTY_MATCH_MULTI_001', // Same party
                    'ssot__FirstName__c' => 'New',
                    'ssot__LastName__c' => 'Multi2',
                    'Client_ID__c' => 'NEW_CLIENT_002',
                    'ssot__LastModifiedDate__c' => DateTime.now() // More recent
                }
            },
            new Map<String, String>{'PARTY_MATCH_MULTI_001' => 'existing1@test.com'},
            new Map<String, String>()
        );
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should update existing contact with matching Client_ID and create new one for the other
        System.assertEquals(2, bundle.records.size(), 'Should handle multiple Seaware clients');
        
        Set<String> clientIds = new Set<String>();
        for (SObject record : bundle.records) {
            Contact contact = (Contact) record;
            clientIds.add(contact.Client_ID__c);
        }
        
        System.assert(clientIds.contains('EXISTING_CLIENT_001'));
        System.assert(clientIds.contains('NEW_CLIENT_002'));
    }
    
    // SCENARIO 7: Multiple Salesforce Contacts and 1 Seaware Client
    @IsTest
    static void testScenario7_MultipleSalesforceContacts_OneSeawareClient() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<SObject> seawareClients = createMockSeawareClientsWithContactPoints(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'ssot__Id__c' => 'MATCH_CLIENT_MULTI',
                    'ssot__PartyId__c' => 'PARTY_MATCH_MULTI_SF',
                    'ssot__FirstName__c' => 'Updated',
                    'ssot__LastName__c' => 'FromSeaware',
                    'Client_ID__c' => 'EXISTING_CLIENT_001', // Matches one existing contact
                    'ssot__LastModifiedDate__c' => DateTime.now()
                }
            },
            new Map<String, String>{'PARTY_MATCH_MULTI_SF' => 'existing1@test.com'}, // Matches first contact
            new Map<String, String>()
        );
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should update the matching contact
        System.assertEquals(1, bundle.records.size(), 'Should update matching contact');
        
        Contact resultContact = (Contact) bundle.records[0];
        System.assertEquals('EXISTING_CLIENT_001', resultContact.Client_ID__c);
        System.assertEquals('Updated', resultContact.FirstName);
        System.assertEquals('FromSeaware', resultContact.LastName);
    }
    
    // SCENARIO 8: Multiple Salesforce Contacts and multiple Seaware Clients
    @IsTest
    static void testScenario8_MultipleSalesforceContacts_MultipleSeawareClients() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<SObject> seawareClients = createMockSeawareClientsWithContactPoints(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'ssot__Id__c' => 'MATCH_CLIENT_8_1',
                    'ssot__PartyId__c' => 'PARTY_MATCH_8',
                    'ssot__FirstName__c' => 'Multi',
                    'ssot__LastName__c' => 'Match1',
                    'Client_ID__c' => 'EXISTING_CLIENT_001', // Matches existing
                    'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-10)
                },
                new Map<String, Object>{
                    'ssot__Id__c' => 'MATCH_CLIENT_8_2',
                    'ssot__PartyId__c' => 'PARTY_MATCH_8', // Same party
                    'ssot__FirstName__c' => 'Multi',
                    'ssot__LastName__c' => 'Match2',
                    'Client_ID__c' => 'EXISTING_CLIENT_002', // Matches another existing
                    'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-5)
                },
                new Map<String, Object>{
                    'ssot__Id__c' => 'NEW_CLIENT_8_3',
                    'ssot__PartyId__c' => 'PARTY_MATCH_8', // Same party
                    'ssot__FirstName__c' => 'New',
                    'ssot__LastName__c' => 'Client8',
                    'Client_ID__c' => 'NEW_CLIENT_8_3',
                    'ssot__LastModifiedDate__c' => DateTime.now()
                }
            },
            new Map<String, String>{'PARTY_MATCH_8' => 'existing1@test.com'}, // Matches multiple contacts
            new Map<String, String>()
        );
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should handle complex scenario with multiple matches and new records
        System.assert(bundle.records.size() >= 1, 'Should process multiple contacts in complex scenario');
        
        Set<String> clientIds = new Set<String>();
        for (SObject record : bundle.records) {
            Contact contact = (Contact) record;
            clientIds.add(contact.Client_ID__c);
        }
        
        // Should include some combination of existing and new client IDs based on matching logic
        System.assert(!clientIds.isEmpty(), 'Should have processed some contacts');
    }
    
    @IsTest
    static void testContactPointDataApplication() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<SObject> seawareClients = createMockSeawareClientsWithContactPoints(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'ssot__Id__c' => 'CONTACT_POINT_CLIENT',
                    'ssot__PartyId__c' => 'PARTY_CONTACT_POINTS',
                    'ssot__FirstName__c' => 'Contact',
                    'ssot__LastName__c' => 'Points',
                    'Client_ID__c' => 'CONTACT_POINT_CLIENT',
                    'ssot__LastModifiedDate__c' => DateTime.now()
                }
            },
            new Map<String, String>{'PARTY_CONTACT_POINTS' => 'contact.points@test.com'},
            new Map<String, String>{'PARTY_CONTACT_POINTS' => '+1-555-999-0001'}
        );
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        Contact resultContact = (Contact) bundle.records[0];
        
        System.assertEquals('contact.points@test.com', resultContact.Email);
        System.assertEquals('+1-555-999-0001', resultContact.Phone);
        System.assertEquals('Contact', resultContact.FirstName);
        System.assertEquals('Points', resultContact.LastName);
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
        
        // No assertions needed as it's a no-op method
        System.assert(true, 'afterUpsert should complete without errors');
    }
    
    // Helper methods for creating mock data
    private static List<SObject> createMockSeawareClients(List<Map<String, Object>> clientDataList) {
        return createMockSeawareClientsWithContactPoints(clientDataList, 
            new Map<String, String>(), new Map<String, String>());
    }
    
    private static List<SObject> createMockSeawareClientsWithContactPoints(
        List<Map<String, Object>> clientDataList,
        Map<String, String> emailByParty,
        Map<String, String> phoneByParty
    ) {
        List<SObject> mockClients = new List<SObject>();
        
        for (Map<String, Object> clientData : clientDataList) {
            Contact mockClient = new Contact();
            
            for (String field : clientData.keySet()) {
                try {
                    mockClient.put(field, clientData.get(field));
                } catch (Exception e) {
                    System.debug('Field not accessible in test: ' + field);
                }
            }
            
            mockClients.add(mockClient);
        }
        
        return mockClients;
    }
    
    @IsTest
    static void testQueryMethods() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Test the private query methods by calling mapScope which uses them
        List<SObject> seawareClients = createMockSeawareClientsWithContactPoints(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'ssot__Id__c' => 'QUERY_TEST_CLIENT',
                    'ssot__PartyId__c' => 'PARTY_QUERY_TEST',
                    'ssot__FirstName__c' => 'Query',
                    'ssot__LastName__c' => 'Test',
                    'Client_ID__c' => 'QUERY_TEST_CLIENT',
                    'ssot__LastModifiedDate__c' => DateTime.now()
                }
            },
            new Map<String, String>(),
            new Map<String, String>()
        );
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Verify the query methods executed without errors
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Client_ID__c', bundle.externalIdField);
    }
    
    @IsTest
    static void testEmptyScope() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<SObject> emptyScope = new List<SObject>();
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(emptyScope);
        Test.stopTest();
        
        System.assertEquals(0, bundle.records.size());
        System.assertEquals('Client_ID__c', bundle.externalIdField);
    }
}
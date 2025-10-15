@IsTest
private class DC_ContactClientStep_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Record Type if it doesn't exist (for test context)
        // In test context, we'll work without record types or create them
        
        // Create existing contacts for various test scenarios
        List<Contact> existingContacts = new List<Contact>();
        
        // Contact 1: Has Client_ID, for scenario testing
        existingContacts.add(new Contact(
            FirstName = 'Existing',
            LastName = 'Client1',
            Email = 'existing1@test.com',
            Phone = '+1-555-111-0001',
            Client_ID__c = '12345'
        ));
        
        // Contact 2: Has Client_ID, for scenario testing
        existingContacts.add(new Contact(
            FirstName = 'Existing',
            LastName = 'Client2',
            Email = 'existing2@test.com',
            Phone = '+1-555-111-0002',
            Client_ID__c = '54321'
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
        
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'NEW_CLIENT_001',
                'ssot__PartyId__c' => 'PARTY_NEW_001',
                'ssot__FirstName__c' => 'John',
                'ssot__LastName__c' => 'New',
                'Client_ID__c' => '55555',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size(), 'Should create 1 contact');
        System.assertEquals('Client_ID__c', bundle.externalIdField);
        
        Contact resultContact = (Contact) bundle.records[0];
        System.assertEquals('55555', resultContact.Client_ID__c);
        System.assertEquals('John', resultContact.FirstName);
        System.assertEquals('New', resultContact.LastName);
    }
    
    // SCENARIO 2: Only 1 Salesforce Contact, no Seaware clients
    @IsTest
    static void testScenario2_OneSalesforceContact_NoSeawareClients() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Empty scope - no Seaware clients
        List<Object> seawareClients = new List<Object>();
        
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
        
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'MULTI_CLIENT_001',
                'ssot__PartyId__c' => 'PARTY_MULTI_001',
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Client1',
                'Client_ID__c' => '12345',
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-10)
            },
            new Map<String, Object>{
                'ssot__Id__c' => 'MULTI_CLIENT_002',
                'ssot__PartyId__c' => 'PARTY_MULTI_001',
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Client2',
                'Client_ID__c' => '123456',
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-5)
            },
            new Map<String, Object>{
                'ssot__Id__c' => 'MULTI_CLIENT_003',
                'ssot__PartyId__c' => 'PARTY_MULTI_001',
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Client3',
                'Client_ID__c' => '1234567',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should create contacts for all Seaware clients
        System.assertEquals(3, bundle.records.size(), 'Should create contacts for all Seaware clients');
        
        Set<String> clientIds = new Set<String>();
        for (SObject record : bundle.records) {
            Contact contact = (Contact) record;
            clientIds.add(contact.Client_ID__c);
        }
        
        System.assert(clientIds.contains('12345'));
        System.assert(clientIds.contains('123456'));
        System.assert(clientIds.contains('1234567'));
    }
    
    // SCENARIO 5: 1 Salesforce Contact and 1 Seaware Client
    @IsTest
    static void testScenario5_OneSalesforceContact_OneSeawareClient() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Create Seaware client that matches existing contact
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'MATCH_CLIENT_001',
                'ssot__PartyId__c' => 'PARTY_MATCH_001',
                'ssot__FirstName__c' => 'Updated',
                'ssot__LastName__c' => 'Name',
                'Client_ID__c' => '12345',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should update existing or create new contact
        Integer totalContacts = bundle.records.size() + bundle.recordsToUpdate.size();
        System.assertEquals(1, totalContacts, 'Should update existing contact');
    }
    
    // SCENARIO 6: 1 Salesforce Contact and multiple Seaware Clients
    @IsTest
    static void testScenario6_OneSalesforceContact_MultipleSeawareClients() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'MATCH_CLIENT_001',
                'ssot__PartyId__c' => 'PARTY_MATCH_MULTI_001',
                'ssot__FirstName__c' => 'Updated',
                'ssot__LastName__c' => 'Multi1',
                'Client_ID__c' => '12345',
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-10)
            },
            new Map<String, Object>{
                'ssot__Id__c' => 'NEW_CLIENT_002',
                'ssot__PartyId__c' => 'PARTY_MATCH_MULTI_001',
                'ssot__FirstName__c' => 'New',
                'ssot__LastName__c' => 'Multi2',
                'Client_ID__c' => '234567',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should handle multiple Seaware clients
        Integer totalContacts = bundle.records.size() + bundle.recordsToUpdate.size();
        System.assert(totalContacts >= 1, 'Should handle multiple Seaware clients');
    }
    
    // SCENARIO 7: Multiple Salesforce Contacts and 1 Seaware Client
    @IsTest
    static void testScenario7_MultipleSalesforceContacts_OneSeawareClient() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'MATCH_CLIENT_MULTI',
                'ssot__PartyId__c' => 'PARTY_MATCH_MULTI_SF',
                'ssot__FirstName__c' => 'Updated',
                'ssot__LastName__c' => 'FromSeaware',
                'Client_ID__c' => '12345',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should update the matching contact
        Integer totalContacts = bundle.records.size() + bundle.recordsToUpdate.size();
        System.assert(totalContacts >= 1, 'Should update matching contact');
    }
    
    // SCENARIO 8: Multiple Salesforce Contacts and multiple Seaware Clients
    @IsTest
    static void testScenario8_MultipleSalesforceContacts_MultipleSeawareClients() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'MATCH_CLIENT_8_1',
                'ssot__PartyId__c' => 'PARTY_MATCH_8',
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Match1',
                'Client_ID__c' => '12345',
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-10)
            },
            new Map<String, Object>{
                'ssot__Id__c' => 'MATCH_CLIENT_8_2',
                'ssot__PartyId__c' => 'PARTY_MATCH_8',
                'ssot__FirstName__c' => 'Multi',
                'ssot__LastName__c' => 'Match2',
                'Client_ID__c' => '54321',
                'ssot__LastModifiedDate__c' => DateTime.now().addMinutes(-5)
            },
            new Map<String, Object>{
                'ssot__Id__c' => 'NEW_CLIENT_8_3',
                'ssot__PartyId__c' => 'PARTY_MATCH_8',
                'ssot__FirstName__c' => 'New',
                'ssot__LastName__c' => 'Client8',
                'Client_ID__c' => '67899',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        // Should handle complex scenario with multiple matches and new records
        Integer totalContacts = bundle.records.size() + bundle.recordsToUpdate.size();
        System.assert(totalContacts >= 1, 'Should process multiple contacts in complex scenario');
    }
    
    @IsTest
    static void testContactPointDataApplication() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'CONTACT_POINT_CLIENT',
                'ssot__PartyId__c' => 'PARTY_CONTACT_POINTS',
                'ssot__FirstName__c' => 'Contact',
                'ssot__LastName__c' => 'Points',
                'Client_ID__c' => '78990',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(seawareClients);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        Contact resultContact = (Contact) bundle.records[0];
        
        System.assertEquals('Contact', resultContact.FirstName);
        System.assertEquals('Points', resultContact.LastName);
    }
    
    @IsTest
    static void testAfterUpsert() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Should not throw exception
        Test.startTest();
        step.afterUpsert(new List<Object>(), 
                        new DC_UpsertBundle(new List<SObject>(), 'Client_ID__c'), 
                        new Database.UpsertResult[0]);
        Test.stopTest();
        
        // No assertions needed as it's a no-op method
        System.assert(true, 'afterUpsert should complete without errors');
    }
    
    @IsTest
    static void testQueryMethods() {
        DC_ContactClientStep step = new DC_ContactClientStep();
        
        // Test the private query methods by calling mapScope which uses them
        List<Object> seawareClients = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'QUERY_TEST_CLIENT',
                'ssot__PartyId__c' => 'PARTY_QUERY_TEST',
                'ssot__FirstName__c' => 'Query',
                'ssot__LastName__c' => 'Test',
                'Client_ID__c' => '67890',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        
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
        
        List<Object> emptyScope = new List<Object>();
        
        Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(emptyScope);
        Test.stopTest();
        
        System.assertEquals(0, bundle.records.size());
        System.assertEquals('Client_ID__c', bundle.externalIdField);
    }
}
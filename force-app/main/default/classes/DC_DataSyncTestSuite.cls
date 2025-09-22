/**
 * Comprehensive test suite for the Data Cloud sync framework
 * This class provides utilities for running all tests and validating the framework
 */
@IsTest
private class DC_DataSyncTestSuite {
    
    /**
     * Master test method that validates all core components
     */
    @IsTest
    static void testCompleteFrameworkIntegration() {
        System.debug('=== Starting Data Sync Framework Integration Test ===');
        
        // Test all step factories
        testAllStepFactories();
        
        // Test all field mappings
        testAllFieldMappings();
        
        // Test core utilities
        testCoreUtilities();
        
        // Test orchestration components
        testOrchestrationComponents();
        
        System.debug('=== Data Sync Framework Integration Test Complete ===');
    }
    
    /**
     * Test that all step factories work correctly
     */
    private static void testAllStepFactories() {
        System.debug('Testing Step Factories...');
        
        // Test each step type
        Map<String, Type> expectedTypes = new Map<String, Type>{
            'Account' => DC_AccountStep.class,
            'Commission' => DC_CommissionStep.class,
            'ContactAgent' => DC_ContactAgentStep.class,
            'ContactClient' => DC_ContactClientStep.class,
            'Ship' => DC_ShipStep.class,
            'Sailing' => DC_SailingStep.class,
            'Opportunity' => DC_OpportunityStep.class,
            'Booking' => DC_BookingStep.class,
            'Reservation' => DC_ReservationStep.class
        };
        
        for (String stepName : expectedTypes.keySet()) {
            DC_IStep step = DC_StepFactory.make(stepName);
            System.assertNotEquals(null, step, 'Step should be created for: ' + stepName);
            
            // Verify step implements the interface by checking it has required methods
            System.assertNotEquals(null, step.sourceObjectApi(), stepName + ' should have source object');
            System.assertNotEquals(null, step.orderBySourceField(), stepName + ' should have order field');
            System.assertNotEquals(null, step.sourceFields(), stepName + ' should have source fields');
        }
        
        // Test invalid step
        DC_IStep invalidStep = DC_StepFactory.make('InvalidStep');
        System.assertEquals(null, invalidStep, 'Invalid step should return null');
        
        System.debug('Step Factories test completed successfully');
    }
    
    /**
     * Test all field mappings are properly configured
     */
    private static void testAllFieldMappings() {
        System.debug('Testing Field Mappings...');
        
        // Test that all mapping lists exist and are not empty
        System.assert(!DC_Mappings.ACCOUNT_MAP.isEmpty(), 'Account map should not be empty');
        System.assert(!DC_Mappings.COMMISSION_MAP.isEmpty(), 'Commission map should not be empty');
        System.assert(!DC_Mappings.CONTACT_AGENT_MAP.isEmpty(), 'Contact Agent map should not be empty');
        System.assert(!DC_Mappings.CONTACT_CLIENT_MAP.isEmpty(), 'Contact Client map should not be empty');
        System.assert(!DC_Mappings.SHIP_MAP.isEmpty(), 'Ship map should not be empty');
        System.assert(!DC_Mappings.SAILING_MAP.isEmpty(), 'Sailing map should not be empty');
        System.assert(!DC_Mappings.OPPORTUNITY_MAP.isEmpty(), 'Opportunity map should not be empty');
        System.assert(!DC_Mappings.BOOKING_MAP.isEmpty(), 'Booking map should not be empty');
        System.assert(!DC_Mappings.RESERVATION_MAP.isEmpty(), 'Reservation map should not be empty');
        
        // Test that each mapping has valid source and target fields
        validateFieldMappings('ACCOUNT_MAP', DC_Mappings.ACCOUNT_MAP);
        validateFieldMappings('COMMISSION_MAP', DC_Mappings.COMMISSION_MAP);
        validateFieldMappings('CONTACT_AGENT_MAP', DC_Mappings.CONTACT_AGENT_MAP);
        validateFieldMappings('CONTACT_CLIENT_MAP', DC_Mappings.CONTACT_CLIENT_MAP);
        validateFieldMappings('SHIP_MAP', DC_Mappings.SHIP_MAP);
        validateFieldMappings('SAILING_MAP', DC_Mappings.SAILING_MAP);
        validateFieldMappings('OPPORTUNITY_MAP', DC_Mappings.OPPORTUNITY_MAP);
        validateFieldMappings('BOOKING_MAP', DC_Mappings.BOOKING_MAP);
        validateFieldMappings('RESERVATION_MAP', DC_Mappings.RESERVATION_MAP);
        
        System.debug('Field Mappings test completed successfully');
    }
    
    /**
     * Validate individual field mapping list
     */
    private static void validateFieldMappings(String mapName, List<DC_FieldMap> mappings) {
        for (DC_FieldMap mapping : mappings) {
            System.assert(!String.isBlank(mapping.src), mapName + ' should have valid source field');
            System.assert(!String.isBlank(mapping.tgt), mapName + ' should have valid target field');
        }
    }
    
    /**
     * Test core utility classes
     */
    private static void testCoreUtilities() {
        System.debug('Testing Core Utilities...');
        
        // Test DC_UpsertBundle
        List<SObject> testRecords = new List<SObject>{ new Account(Name = 'Test') };
        DC_UpsertBundle bundle = new DC_UpsertBundle(testRecords, 'External_Id__c');
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('External_Id__c', bundle.externalIdField);
        
        // Test DC_MultiSourceData
        DC_MultiSourceData multiData = new DC_MultiSourceData(testRecords);
        System.assertEquals(1, multiData.mainRecords.size());
        
        // Add additional data
        List<SObject> additionalData = new List<SObject>{ new Contact(FirstName = 'Test') };
        multiData.addAdditionalData('contacts', 'key1', additionalData);
        List<SObject> retrieved = multiData.getAdditionalData('contacts', 'key1');
        System.assertEquals(1, retrieved.size());
        
        // Test DC_JoinConfig
        DC_JoinConfig joinConfig = new DC_JoinConfig(
            'TestObject__c',
            new Set<String>{'Field1__c'},
            'JoinField__c',
            'ParentField__c',
            'Status__c = \'Active\''
        );
        System.assertEquals('TestObject__c', joinConfig.sourceObject);
        System.assertEquals('Status__c = \'Active\'', joinConfig.whereClause);
        
        // Test DC_FieldMap
        DC_FieldMap fieldMap = new DC_FieldMap('Source__c', 'Target__c');
        System.assertEquals('Source__c', fieldMap.src);
        System.assertEquals('Target__c', fieldMap.tgt);
        
        System.debug('Core Utilities test completed successfully');
    }
    
    /**
     * Test orchestration components
     */
    private static void testOrchestrationComponents() {
        System.debug('Testing Orchestration Components...');
        
        // Test StepRunner constructor
        List<String> stepNames = new List<String>{'Account', 'Ship'};
        DC_StepRunner runner = new DC_StepRunner(stepNames, 0, null, 100);
        System.assertNotEquals(null, runner);
        
        // Test default page size
        System.assertEquals(200, DC_StepRunner.DEFAULT_PAGE_SIZE);
        
        // Test StepStarter
        DC_Orchestrator.StepStarter starter = new DC_Orchestrator.StepStarter(stepNames, 0, 100);
        System.assertNotEquals(null, starter);
        
        // Test NightlyScheduler
        DC_NightlyScheduler scheduler = new DC_NightlyScheduler();
        System.assertNotEquals(null, scheduler);
        
        System.debug('Orchestration Components test completed successfully');
    }
    
    /**
     * Test step execution with mock data
     */
    @IsTest
    static void testStepExecutionFlow() {
        System.debug('=== Testing Step Execution Flow ===');
        
        // Create test data for dependencies
        setupTestDataForSteps();
        
        // Test single-source step (Account)
        testSingleSourceStepExecution();
        
        // Test multi-source step (ContactAgent)  
        testMultiSourceStepExecution();
        
        System.debug('=== Step Execution Flow Test Complete ===');
    }
    
    /**
     * Setup test data needed for step execution tests
     */
    private static void setupTestDataForSteps() {
        // Create parent account for Account step
        Account parentAccount = new Account(
            Name = 'Parent Account',
            SEAWARE_Agency_ID__c = 'PARENT123'
        );
        insert parentAccount;
        
        // Create test ship for various steps
        Ship__c testShip = new Ship__c(
            Name = 'Test Ship',
            Ship_Code__c = 'SHIP123'
        );
        insert testShip;
        
        // Create test account for agent lookup
        Account agencyAccount = new Account(
            Name = 'Test Agency',
            SEAWARE_Agency_ID__c = 'AGENCY123'
        );
        insert agencyAccount;
    }
    
    /**
     * Test single-source step execution
     */
    private static void testSingleSourceStepExecution() {
        DC_AccountStep accountStep = new DC_AccountStep();
        
        // Create mock source data
        Map<String, Object> sourceData = new Map<String, Object>{
            'ssot__Id__c' => 'TEST_ACCOUNT_001',
            'Address_City__c' => 'Test City',
            'ssot__Name__c' => 'Test Account Name',
            'Phone__c' => '555-0123',
            'Parent_ID__c' => 'PARENT123'
        };
        
        Account mockSource = new Account();
        for (String field : sourceData.keySet()) {
            try {
                mockSource.put(field, sourceData.get(field));
            } catch (Exception e) {
                // Skip fields that don't exist on Account
                System.debug('Skipping field in test: ' + field);
            }
        }
        
        List<SObject> scope = new List<SObject>{ mockSource };
        
        Test.startTest();
        DC_UpsertBundle bundle = accountStep.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('SEAWARE_Agency_ID__c', bundle.externalIdField);
        
        Account resultAccount = (Account) bundle.records[0];
        System.assertEquals('TEST_ACCOUNT_001', resultAccount.SEAWARE_Agency_ID__c);
    }
    
    /**
     * Test multi-source step execution
     */
    private static void testMultiSourceStepExecution() {
        DC_ContactAgentStep agentStep = new DC_ContactAgentStep();
        
        // Verify it's a multi-source step
        Map<String, DC_JoinConfig> additionalSources = agentStep.getAdditionalSources();
        System.assert(!additionalSources.isEmpty(), 'ContactAgent should be multi-source step');
        
        // Create mock main source data
        Map<String, Object> agentData = new Map<String, Object>{
            'Agent_ID__c' => 'AGENT001',
            'ssot__PartyId__c' => 'PARTY001',
            'ssot__FirstName__c' => 'Test',
            'ssot__LastName__c' => 'Agent',
            'Agency_ID__c' => 'AGENCY123'
        };
        
        Contact mockAgent = new Contact();
        for (String field : agentData.keySet()) {
            try {
                mockAgent.put(field, agentData.get(field));
            } catch (Exception e) {
                System.debug('Skipping field in test: ' + field);
            }
        }
        
        DC_MultiSourceData multiData = new DC_MultiSourceData(new List<SObject>{ mockAgent });
        
        // Add mock email data
        Contact mockEmail = new Contact();
        mockEmail.put('ssot__EmailAddress__c', 'test.agent@example.com');
        mockEmail.put('ssot__PartyId__c', 'PARTY001');
        multiData.addAdditionalData('email', 'PARTY001', new List<SObject>{ mockEmail });
        
        Test.startTest();
        DC_UpsertBundle bundle = agentStep.mapMultiSourceScope(multiData);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Agent_ID__c', bundle.externalIdField);
    }
    
    /**
     * Test error handling and edge cases
     */
    @IsTest
    static void testErrorHandlingAndEdgeCases() {
        System.debug('=== Testing Error Handling and Edge Cases ===');
        
        // Test DML utility with invalid external ID field
        testDmlUtilErrorHandling();
        
        // Test step factory with null/invalid inputs
        testStepFactoryEdgeCases();
        
        // Test bundle creation with null data
        testBundleEdgeCases();
        
        System.debug('=== Error Handling Test Complete ===');
    }
    
    /**
     * Test DML utility error handling
     */
    private static void testDmlUtilErrorHandling() {
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'Test') };
        
        Test.startTest();
        try {
            DC_DmlUtil.upsertByExtId(accounts, 'NonExistentField__c', false);
            System.assert(false, 'Should have thrown DC_SyncException');
        } catch (DC_SyncException e) {
            System.assert(e.getMessage().contains('External Id field not found'));
        }
        Test.stopTest();
    }
    
    /**
     * Test step factory edge cases
     */
    private static void testStepFactoryEdgeCases() {
        // Test null input
        DC_IStep nullStep = DC_StepFactory.make(null);
        System.assertEquals(null, nullStep);
        
        // Test empty string
        DC_IStep emptyStep = DC_StepFactory.make('');
        System.assertEquals(null, emptyStep);
        
        // Test invalid step name
        DC_IStep invalidStep = DC_StepFactory.make('NonExistentStep');
        System.assertEquals(null, invalidStep);
    }
    
    /**
     * Test bundle creation edge cases
     */
    private static void testBundleEdgeCases() {
        // Test with null records
        DC_UpsertBundle nullBundle = new DC_UpsertBundle(null, 'ExtId__c');
        System.assertEquals(0, nullBundle.records.size());
        System.assertEquals('ExtId__c', nullBundle.externalIdField);
        
        // Test with empty list
        DC_UpsertBundle emptyBundle = new DC_UpsertBundle(new List<SObject>(), 'ExtId__c');
        System.assertEquals(0, emptyBundle.records.size());
    }
    
    /**
     * Performance test for framework components
     */
    @IsTest
    static void testPerformanceAndScalability() {
        System.debug('=== Testing Performance and Scalability ===');
        
        // Test with larger data sets (within test limits)
        testLargeDataSetProcessing();
        
        // Test memory usage with multiple steps
        testMemoryUsageWithMultipleSteps();
        
        System.debug('=== Performance Test Complete ===');
    }
    
    /**
     * Test processing of larger data sets
     */
    private static void testLargeDataSetProcessing() {
        DC_ShipStep shipStep = new DC_ShipStep();
        
        // Create a larger batch of test data (within governor limits)
        List<SObject> largeBatch = new List<SObject>();
        for (Integer i = 1; i <= 100; i++) {
            Account mockShip = new Account();
            mockShip.put('Ship_ID__c', 'SHIP_' + String.valueOf(i).leftPad(3, '0'));
            mockShip.put('Ship_Code__c', 'CODE_' + String.valueOf(i).leftPad(3, '0'));
            mockShip.put('Ship_Name__c', 'Test Ship ' + i);
            largeBatch.add(mockShip);
        }
        
        Test.startTest();
        DC_UpsertBundle bundle = shipStep.mapScope(largeBatch);
        Test.stopTest();
        
        System.assertEquals(100, bundle.records.size());
        System.assertEquals('Ship_Code__c', bundle.externalIdField);
    }
    
    /**
     * Test memory usage with multiple step instances
     */
    private static void testMemoryUsageWithMultipleSteps() {
        // Create multiple step instances to test memory usage
        List<DC_IStep> steps = new List<DC_IStep>{
            new DC_AccountStep(),
            new DC_CommissionStep(),
            new DC_ShipStep(),
            new DC_SailingStep()
        };
        
        // Verify all steps are properly instantiated
        for (DC_IStep step : steps) {
            System.assertNotEquals(null, step.sourceObjectApi());
            System.assertNotEquals(null, step.sourceFields());
        }
        
        System.debug('Successfully created and validated ' + steps.size() + ' step instances');
    }
}
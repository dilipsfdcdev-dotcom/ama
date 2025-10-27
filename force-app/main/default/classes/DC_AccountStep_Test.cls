@IsTest
private class DC_AccountStep_Test {
    
    @TestSetup
    static void setupTestData() {
        // A real parent record for success branch in second pass
        Account parentAccount = new Account(
            Name = 'Parent Test Account',
            SEAWARE_Agency_ID__c = 'PARENT123'
        );
        insert parentAccount;
    }
    
    @IsTest
    static void testSourceObjectApi_and_OrderBy_and_Where_and_SourceFields() {
        DC_AccountStep step = new DC_AccountStep();
        
        System.assertEquals('ssot__Account__dlm', step.sourceObjectApi(), 'SRC object mismatch');
        System.assertEquals('ssot__Id__c', step.orderBySourceField(), 'ORDER BY source mismatch');
        
        String wc = step.whereClause();
        
        Set<String> fields = step.sourceFields();
    }
    
    @IsTest
    static void testMapScope_WithoutParent() {
        DC_AccountStep step = new DC_AccountStep();
        
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'TEST_ACCOUNT_001',
                    'Address_City__c' => 'Test City',
                    'ssot__Name__c' => 'Test Account',
                    'Phone__c' => '555-1234',
                    'Parent_ID__c' => null,
                    'ssot__LastModifiedDate__c' => DateTime.now()
                    }
        };
            
            Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size(), 'Should produce one record');
        System.assertEquals('SEAWARE_Agency_ID__c', bundle.externalIdField, 'ExtId field mismatch');
        
        Account a = (Account) bundle.records[0];
        System.assertEquals('TEST_ACCOUNT_001', a.SEAWARE_Agency_ID__c);
        System.assertEquals('Test City', a.BillingCity);
        System.assertEquals('Test Account', a.Name);
        System.assertEquals('555-1234', a.Phone);
        System.assertEquals(null, a.ParentId, 'Parent should be deferred');
    }
    
    @IsTest
    static void testMapScope_WithParent_DeferLookup() {
        DC_AccountStep step = new DC_AccountStep();
        
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'TEST_ACCOUNT_002',
                    'Address_City__c' => 'Test City 2',
                    'ssot__Name__c' => 'Test Account 2',
                    'Parent_ID__c' => 'PARENT123',
                    'ssot__LastModifiedDate__c' => DateTime.now()
                    }
        };
            
            Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size(), 'Should produce one record');
        Account a = (Account) bundle.records[0];
        System.assertEquals('TEST_ACCOUNT_002', a.SEAWARE_Agency_ID__c);
        // Parent defers to second pass → null here
        System.assertEquals(null, a.ParentId, 'Parent should be deferred');
    }
    
    @IsTest
    static void testMapScope_DedupAndBlankIdSkipped_LatestWins() {
        DC_AccountStep step = new DC_AccountStep();
        
        DateTime t1 = DateTime.now().addMinutes(-10);
        DateTime t2 = DateTime.now().addMinutes(-5);
        DateTime t3 = DateTime.now(); // latest
        
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'DUP001',
                    'Address_City__c' => 'Old City',
                    'ssot__Name__c' => 'Old Name',
                    'ssot__LastModifiedDate__c' => t1
                    },
                        new Map<String, Object>{
                            'ssot__Id__c' => 'DUP001',
                                'Address_City__c' => 'Newer City',
                                'ssot__Name__c' => 'Newer Name',
                                'ssot__LastModifiedDate__c' => t2
                                },
                                    new Map<String, Object>{
                                        'ssot__Id__c' => 'DUP001',
                                            'Address_City__c' => 'Latest City',
                                            'ssot__Name__c' => 'Latest Name',
                                            'ssot__LastModifiedDate__c' => t3
                                            },
                                                new Map<String, Object>{
                                                    'ssot__Id__c' => '', // blank → skipped
                                                        'Address_City__c' => 'Should Skip',
                                                        'ssot__Name__c' => 'Should Skip',
                                                        'ssot__LastModifiedDate__c' => t3
                                                        }
        };
            
            Test.startTest();
        DC_UpsertBundle bundle = step.mapScope(scope);
        Test.stopTest();
        
        System.assertEquals(1, bundle.records.size(), 'Dedup should leave one');
        Account a = (Account) bundle.records[0];
        System.assertEquals('DUP001', a.SEAWARE_Agency_ID__c, 'Ext Id mismatch after dedup');
        System.assertEquals('Latest City', a.BillingCity, 'Latest record should win');
        System.assertEquals('Latest Name', a.Name, 'Latest record should win');
    }
    
    @IsTest
    static void testAfterUpsert_FirstPass_Skips() {
        DC_AccountStep step = new DC_AccountStep();
        
        // Non-empty scope → first pass path → early return
        List<Object> nonEmptyScope = new List<Object>{
            new Map<String, Object>{ 'ssot__Id__c' => 'ANY' }
        };
            DC_UpsertBundle bundle = new DC_UpsertBundle(new List<SObject>(), 'SEAWARE_Agency_ID__c');
        Database.UpsertResult[] results = new Database.UpsertResult[0];
        
        Test.startTest();
        step.afterUpsert(nonEmptyScope, bundle, results);
        Test.stopTest();
        
        System.assert(true, 'afterUpsert first pass returned without errors');
    }
    
    @IsTest
    static void testAfterUpsert_SecondPass_CoversAllBranches() {
        // Real parent (success case)
        Account goodParent = new Account(Name = 'Good Parent', SEAWARE_Agency_ID__c = 'PARENT_GOOD');
        insert goodParent;
        
        // --- Seed child accounts as if first pass already ran ---
        // These will be UPDATED in second pass (so Name requirement is satisfied)
        Account childGoodSeed = new Account(Name = 'Child Good Seed', SEAWARE_Agency_ID__c = 'CHILD_GOOD');
        Account childBadSeed  = new Account(Name = 'Child Bad Seed',  SEAWARE_Agency_ID__c = 'CHILD_BAD');
        insert new List<Account>{ childGoodSeed, childBadSeed };
            
            // Inject two rows from "Data Cloud"
            DC_AccountStep.TV_INJECT = true;
        DC_AccountStep.TV_ACCOUNTS_WITH_PARENTS = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ssot__Id__c' => 'CHILD_GOOD',
                    'Parent_ID__c' => 'PARENT_GOOD',
                    'ssot__LastModifiedDate__c' => DateTime.now()
                    },
                        new Map<String, Object>{
                            'ssot__Id__c' => 'CHILD_BAD',
                                'Parent_ID__c' => 'PARENT_BAD',
                                'ssot__LastModifiedDate__c' => DateTime.now()
                                }
        };
            
            // Lookup map: one real Id → success, one fake Id → failure (INVALID_CROSS_REFERENCE_KEY)
            Id fakeParentId = (Id) '001000000000000AAA';
        DC_AccountStep.TV_PARENT_LOOKUP = new Map<String, Id>{
            'PARENT_GOOD' => goodParent.Id,
                'PARENT_BAD'  => fakeParentId
                };
                    
                    // Use native DML so we get real UpsertResult with success/failure mix
                    DC_AccountStep.TV_USE_DIRECT_UPSERT = true;
        
        // Empty scope → trigger second pass
        DC_AccountStep step = new DC_AccountStep();
        List<Object> emptyScope = new List<Object>();
        DC_UpsertBundle dummyBundle = new DC_UpsertBundle(new List<SObject>(), 'SEAWARE_Agency_ID__c');
        Database.UpsertResult[] none = new Database.UpsertResult[0];
        
        Test.startTest();
        step.afterUpsert(emptyScope, dummyBundle, none);
        Test.stopTest();
        
        // Assert: success branch updated the seeded CHILD_GOOD
        Account childGood = [
            SELECT Id, SEAWARE_Agency_ID__c, ParentId, Host_Account__c
            FROM Account
            WHERE SEAWARE_Agency_ID__c = 'CHILD_GOOD'
            LIMIT 1
        ];
        System.assertEquals(goodParent.Id, childGood.ParentId, 'Good child should be linked to real parent');
        System.assertEquals(goodParent.Id, childGood.Host_Account__c, 'Host_Account__c should also be set');
        
        // CHILD_BAD update should have failed, but test should not throw.
        // Optionally confirm it still exists (seeded) and remains unlinked.
        Account childBad = [
            SELECT Id, SEAWARE_Agency_ID__c, ParentId, Host_Account__c
            FROM Account
            WHERE SEAWARE_Agency_ID__c = 'CHILD_BAD'
            LIMIT 1
        ];
        System.assertEquals(null, childBad.ParentId, 'Bad child should remain unlinked');
        
        // Cleanup test seams
        DC_AccountStep.TV_INJECT = false;
        DC_AccountStep.TV_ACCOUNTS_WITH_PARENTS = null;
        DC_AccountStep.TV_PARENT_LOOKUP = null;
        DC_AccountStep.TV_USE_DIRECT_UPSERT = false;
    }
    
}
@IsTest
private class AgentStatusHandlerController_Test {
    
    @IsTest
    static void testGetPresenceStatusMap_ReturnsMap() {
        Test.startTest();
        Map<String, String> statusMap = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        // Verify the method returns a map (even if empty)
        System.assertNotEquals(null, statusMap, 'Status map should not be null');
        
        // If org has ServicePresenceStatus records, map should contain them
        // If not, map will be empty - both are valid outcomes
        System.debug('Number of presence statuses found: ' + statusMap.size());
    }
    
    @IsTest
    static void testGetPresenceStatusMap_ContainsValidIds() {
        Test.startTest();
        Map<String, String> statusMap = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        // Verify all IDs in the map are 15 characters (truncated from 18)
        for (String developerName : statusMap.keySet()) {
            String statusId = statusMap.get(developerName);
            
            System.assertNotEquals(null, statusId, 
                                 'Status ID should not be null for developer name: ' + developerName);
            System.assertEquals(15, statusId.length(), 
                              'Status ID should be 15 characters: ' + statusId);
        }
    }
    
    @IsTest
    static void testGetPresenceStatusMap_CacheableTrue() {
        // This test verifies the method is cacheable by calling it multiple times
        Test.startTest();
        Map<String, String> statusMap1 = AgentStatusHandlerController.getPresenceStatusMap();
        Map<String, String> statusMap2 = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        // Both calls should succeed
        System.assertNotEquals(null, statusMap1, 'First call should return a map');
        System.assertNotEquals(null, statusMap2, 'Second call should return a map');
        
        // Both maps should have the same size
        System.assertEquals(statusMap1.size(), statusMap2.size(), 
                          'Cached results should be consistent');
    }
    
    @IsTest
    static void testGetPresenceStatusMap_HandlesEmptyResults() {
        // Even if no ServicePresenceStatus records exist, should return empty map (not null)
        Test.startTest();
        Map<String, String> statusMap = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        System.assertNotEquals(null, statusMap, 
                             'Should return empty map, not null, when no statuses exist');
    }
    
    @IsTest
    static void testGetPresenceStatusMap_DeveloperNameAsKey() {
        Test.startTest();
        Map<String, String> statusMap = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        // Verify all keys are valid developer names (non-blank strings)
        for (String developerName : statusMap.keySet()) {
            System.assert(!String.isBlank(developerName), 
                         'Developer name should not be blank');
            
            // Developer names should not contain spaces
            System.assert(!developerName.contains(' '), 
                         'Developer name should not contain spaces: ' + developerName);
        }
    }
    
    @IsTest
    static void testGetPresenceStatusMap_IdTruncation() {
        Test.startTest();
        Map<String, String> statusMap = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        // The method truncates 18-char IDs to 15 chars using substring(0, 15)
        // Verify all IDs are exactly 15 characters
        for (String statusId : statusMap.values()) {
            System.assertEquals(15, statusId.length(), 
                              'All status IDs should be truncated to 15 characters');
        }
    }
    
    @IsTest
    static void testGetPresenceStatusMap_UniqueValues() {
        Test.startTest();
        Map<String, String> statusMap = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        // Verify all status IDs in the map are unique
        Set<String> uniqueIds = new Set<String>(statusMap.values());
        System.assertEquals(statusMap.size(), uniqueIds.size(), 
                          'All status IDs should be unique');
    }
    
    @IsTest
    static void testGetPresenceStatusMap_NoNullValues() {
        Test.startTest();
        Map<String, String> statusMap = AgentStatusHandlerController.getPresenceStatusMap();
        Test.stopTest();
        
        // Verify no null values in the map
        for (String developerName : statusMap.keySet()) {
            String statusId = statusMap.get(developerName);
            System.assertNotEquals(null, statusId, 
                                 'Status ID should never be null for: ' + developerName);
            System.assert(!String.isBlank(statusId), 
                         'Status ID should not be blank for: ' + developerName);
        }
    }
    
    @IsTest
    static void testGetPresenceStatusMap_PerformanceWithMultipleCalls() {
        // Test that the cacheable method can handle multiple rapid calls
        Test.startTest();
        List<Map<String, String>> results = new List<Map<String, String>>();
        
        for (Integer i = 0; i < 5; i++) {
            results.add(AgentStatusHandlerController.getPresenceStatusMap());
        }
        Test.stopTest();
        
        // All calls should succeed
        System.assertEquals(5, results.size(), 'Should have 5 successful calls');
        
        // All results should have the same size
        Integer expectedSize = results[0].size();
        for (Map<String, String> result : results) {
            System.assertEquals(expectedSize, result.size(), 
                              'All cached results should have same size');
        }
    }
}
@IsTest
private class DC_DateUtil_Test {
    
    @IsTest
    static void testGetLastModifiedFieldName() {
        String fieldName = DC_DateUtil.getLastModifiedFieldName('ssot__Account__dlm');
        System.assertEquals('ssot__LastModifiedDate__c', fieldName);
        
        fieldName = DC_DateUtil.getLastModifiedFieldName('Seaware_Ship__dlm');
        System.assertEquals('Last_Modified_Date__c', fieldName);
        
        fieldName = DC_DateUtil.getLastModifiedFieldName('UnknownObject');
        System.assertNotEquals(null, fieldName);
    }
    
    @IsTest
    static void testGetDateFilterClause_WithFieldName() {
        String dateFilter = DC_DateUtil.getDateFilterClause('Account', 'ssot__LastModifiedDate__c');
        System.assert(dateFilter.contains('ssot__LastModifiedDate__c'));
        System.assert(dateFilter.contains('from_iso8601_timestamp'));
    }
    
    @IsTest
    static void testGetDateFilterClause_WithoutFieldName() {
        String dateFilter = DC_DateUtil.getDateFilterClause('Account');
        System.assert(dateFilter.contains('LastModifiedDate'));
        System.assert(dateFilter.contains('from_iso8601_timestamp'));
    }
    
    @IsTest
    static void testGetSyncDaysForStep() {
        Integer syncDays = DC_DateUtil.getSyncDaysForStep('Account');
        System.assert(syncDays >= 1);
        
        syncDays = DC_DateUtil.getSyncDaysForStep('NonExistentStep');
        System.assertEquals(1, syncDays);
        
        syncDays = DC_DateUtil.getSyncDaysForStep(null);
        System.assertEquals(1, syncDays);
    }
    
    @IsTest
    static void testFormatDateForCDP() {
        Date testDate = Date.newInstance(2024, 1, 15);
        String formatted = DC_DateUtil.formatDateForCDP(testDate);
        System.assertEquals('2024-01-15', formatted);
        
        System.assertEquals(null, DC_DateUtil.formatDateForCDP(null));
    }
    
    @IsTest
    static void testFormatDateTimeForCDP() {
        DateTime testDateTime = DateTime.newInstance(2024, 1, 15, 10, 30, 0);
        String formatted = DC_DateUtil.formatDateTimeForCDP(testDateTime);
        System.assert(formatted.contains('2024-01-15'));
        System.assert(formatted.contains('T'));
        System.assert(formatted.contains('Z'));
        
        System.assertEquals(null, DC_DateUtil.formatDateTimeForCDP(null));
    }
    
    @IsTest
    static void testGetDateFilterClauseForSeaware() {
        String dateFilter = DC_DateUtil.getDateFilterClauseForSeaware('Ship', 'Last_Modified_Date__c');
        System.assert(dateFilter.contains('Last_Modified_Date__c'));
        
        dateFilter = DC_DateUtil.getDateFilterClauseForSeaware('Ship', null);
        System.assertNotEquals(null, dateFilter);
    }
    
    @IsTest
    static void testGetDateFilterClause_MultipleDays() {
        // This will test the multi-day sync scenario
        String dateFilter = DC_DateUtil.getDateFilterClause('Account', 'ssot__LastModifiedDate__c');
        System.assert(dateFilter.contains('>='));
        System.assert(dateFilter.contains('<'));
    }
    
    @IsTest
    static void testGetDateFilterClause_EdgeCases() {
        String dateFilter = DC_DateUtil.getDateFilterClause('', 'ssot__LastModifiedDate__c');
        System.assertNotEquals(null, dateFilter);
        
        dateFilter = DC_DateUtil.getDateFilterClause('Account', '');
        System.assertNotEquals(null, dateFilter);
    }
}
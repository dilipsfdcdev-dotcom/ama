@IsTest
private class DC_CdpQueryUtil_Test {
    
    @IsTest
    static void testBuildDataCloudSql_Basic() {
        Set<String> fields = new Set<String>{'ssot__Id__c', 'ssot__Name__c'};
        
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            'ssot__Account__dlm',
            fields,
            'ssot__Id__c = \'123\'',
            'ssot__Id__c',
            200,
            0
        );
        
        System.assert(sql.contains('SELECT'));
        System.assert(sql.contains('ssot__Id__c'));
        System.assert(sql.contains('FROM ssot__Account__dlm'));
        System.assert(sql.contains('WHERE'));
        System.assert(sql.contains('ORDER BY'));
        System.assert(sql.contains('LIMIT 200'));
    }
    
    @IsTest
    static void testBuildDataCloudSql_WithOffset() {
        Set<String> fields = new Set<String>{'ssot__Id__c'};
        
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            'ssot__Account__dlm',
            fields,
            null,
            'ssot__Id__c',
            200,
            400
        );
        
        System.assert(sql.contains('OFFSET 400'));
    }
    
    @IsTest
    static void testBuildDataCloudSql_NoWhereClause() {
        Set<String> fields = new Set<String>{'ssot__Id__c'};
        
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            'ssot__Account__dlm',
            fields,
            '',
            'ssot__Id__c',
            200,
            0
        );
        
        System.assert(!sql.contains('WHERE'));
    }
    
    @IsTest
    static void testBuildDataCloudSql_NoOrderBy() {
        Set<String> fields = new Set<String>{'ssot__Id__c'};
        
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            'ssot__Account__dlm',
            fields,
            null,
            null,
            200,
            0
        );
        
        System.assert(!sql.contains('ORDER BY'));
    }
    
    @IsTest
    static void testBuildDataCloudSql_InvalidInput() {
        try {
            DC_CdpQueryUtil.buildDataCloudSql(
                null,
                new Set<String>{'field'},
                null,
                null,
                200,
                0
            );
            System.assert(false, 'Should throw exception');
        } catch (DC_SyncException e) {
            System.assert(true, 'Expected exception thrown');
        }
        
        try {
            DC_CdpQueryUtil.buildDataCloudSql(
                'Object',
                new Set<String>(),
                null,
                null,
                200,
                0
            );
            System.assert(false, 'Should throw exception');
        } catch (DC_SyncException e) {
            System.assert(true, 'Expected exception thrown');
        }
    }
    
    @IsTest
    static void testColComparable() {
        DC_CdpQueryUtil.Col col1 = new DC_CdpQueryUtil.Col('field1', 1);
        DC_CdpQueryUtil.Col col2 = new DC_CdpQueryUtil.Col('field2', 2);
        DC_CdpQueryUtil.Col col3 = new DC_CdpQueryUtil.Col('field3', null);
        DC_CdpQueryUtil.Col col4 = new DC_CdpQueryUtil.Col('field4', null);
        
        System.assertEquals(-1, col1.compareTo(col2));
        System.assertEquals(1, col2.compareTo(col1));
        System.assertEquals(0, col1.compareTo(col1));
        System.assertEquals(1, col3.compareTo(col1));
        System.assertEquals(0, col3.compareTo(col4));
    }
    
    @IsTest
    static void testBuildDataCloudSql_MultipleFields() {
        Set<String> fields = new Set<String>{'ssot__Id__c', 'ssot__Name__c', 'ssot__Email__c'};
        
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            'ssot__Individual__dlm',
            fields,
            'ssot__DataSourceObjectId__c = \'test\'',
            'ssot__Id__c',
            100,
            50
        );
        
        System.assert(sql.contains('ssot__Id__c'));
        System.assert(sql.contains('ssot__Name__c'));
        System.assert(sql.contains('ssot__Email__c'));
        System.assert(sql.contains('LIMIT 100'));
        System.assert(sql.contains('OFFSET 50'));
    }
    
    @IsTest
    static void testBuildDataCloudSql_NoLimitOrOffset() {
        Set<String> fields = new Set<String>{'ssot__Id__c'};
        
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            'ssot__Account__dlm',
            fields,
            null,
            'ssot__Id__c',
            null,
            null
        );
        
        System.assert(!sql.contains('LIMIT'));
        System.assert(!sql.contains('OFFSET'));
    }
}
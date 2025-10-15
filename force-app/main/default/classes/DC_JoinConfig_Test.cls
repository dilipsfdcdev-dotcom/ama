@IsTest
private class DC_JoinConfig_Test {
    
    @IsTest
    static void testConstructorWithoutWhereClause() {
        Set<String> fields = new Set<String>{'field1', 'field2'};
        
        DC_JoinConfig config = new DC_JoinConfig(
            'ssot__ContactPointEmail__dlm',
            fields,
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        );
        
        System.assertEquals('ssot__ContactPointEmail__dlm', config.sourceObject);
        System.assertEquals(2, config.sourceFields.size());
        System.assertEquals('ssot__PartyId__c', config.joinField);
        System.assertEquals('ssot__PartyId__c', config.parentField);
        System.assertEquals(null, config.whereClause);
    }
    
    @IsTest
    static void testConstructorWithWhereClause() {
        Set<String> fields = new Set<String>{'field1', 'field2'};
        
        DC_JoinConfig config = new DC_JoinConfig(
            'ssot__ContactPointEmail__dlm',
            fields,
            'ssot__PartyId__c',
            'ssot__PartyId__c',
            'ssot__IsPrimary__c = true'
        );
        
        System.assertEquals('ssot__ContactPointEmail__dlm', config.sourceObject);
        System.assertEquals(2, config.sourceFields.size());
        System.assertEquals('ssot__PartyId__c', config.joinField);
        System.assertEquals('ssot__PartyId__c', config.parentField);
        System.assertEquals('ssot__IsPrimary__c = true', config.whereClause);
    }
    
    @IsTest
    static void testConstructorWithNullFields() {
        DC_JoinConfig config = new DC_JoinConfig(
            'ssot__ContactPointEmail__dlm',
            null,
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        );
        
        System.assertNotEquals(null, config.sourceFields);
        System.assertEquals(0, config.sourceFields.size());
    }
    
    @IsTest
    static void testConstructorWithEmptyFields() {
        Set<String> fields = new Set<String>();
        
        DC_JoinConfig config = new DC_JoinConfig(
            'ssot__ContactPointEmail__dlm',
            fields,
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        );
        
        System.assertNotEquals(null, config.sourceFields);
        System.assertEquals(0, config.sourceFields.size());
    }
    
    @IsTest
    static void testMultipleConfigs() {
        DC_JoinConfig emailConfig = new DC_JoinConfig(
            'ssot__ContactPointEmail__dlm',
            new Set<String>{'ssot__EmailAddress__c'},
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        );
        
        DC_JoinConfig phoneConfig = new DC_JoinConfig(
            'ssot__ContactPointPhone__dlm',
            new Set<String>{'ssot__PhoneNumber__c'},
            'ssot__PartyId__c',
            'ssot__PartyId__c'
        );
        
        System.assertEquals('ssot__ContactPointEmail__dlm', emailConfig.sourceObject);
        System.assertEquals('ssot__ContactPointPhone__dlm', phoneConfig.sourceObject);
    }
}
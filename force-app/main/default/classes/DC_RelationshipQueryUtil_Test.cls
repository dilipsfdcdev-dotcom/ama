@IsTest
private class DC_RelationshipQueryUtil_Test {
    
    @IsTest
    static void testIsRelationshipField() {
        System.assertEquals(true, DC_RelationshipQueryUtil.isRelationshipField('EMAIL:ssot__EmailAddress__c'));
        System.assertEquals(false, DC_RelationshipQueryUtil.isRelationshipField('ssot__EmailAddress__c'));
        System.assertEquals(false, DC_RelationshipQueryUtil.isRelationshipField(null));
    }
    
    @IsTest
    static void testBuildSubqueriesFromMappings() {
        List<DC_FieldMap> mappings = new List<DC_FieldMap>{
            new DC_FieldMap('EMAIL:ssot__EmailAddress__c', 'Email'),
            new DC_FieldMap('PHONE:ssot__FormattedE164PhoneNumber__c', 'Phone'),
            new DC_FieldMap('ssot__FirstName__c', 'FirstName')
        };
        
        Set<String> subqueries = DC_RelationshipQueryUtil.buildSubqueriesFromMappings(mappings);
        
        System.assertNotEquals(null, subqueries);
        System.assert(subqueries.size() > 0);
    }
    
    @IsTest
    static void testBuildSubqueriesFromMappings_NoRelationships() {
        List<DC_FieldMap> mappings = new List<DC_FieldMap>{
            new DC_FieldMap('ssot__FirstName__c', 'FirstName'),
            new DC_FieldMap('ssot__LastName__c', 'LastName')
        };
        
        Set<String> subqueries = DC_RelationshipQueryUtil.buildSubqueriesFromMappings(mappings);
        
        System.assertEquals(0, subqueries.size());
    }
    
    @IsTest
    static void testConstants() {
        System.assertEquals('ssot__rel_1697761162380_end__r', DC_RelationshipQueryUtil.EMAIL_RELATIONSHIP);
        System.assertEquals('ssot__rel_1697761164176_end__r', DC_RelationshipQueryUtil.PHONE_RELATIONSHIP);
        System.assertEquals('ssot__rel_1697761159567_end__r', DC_RelationshipQueryUtil.ADDRESS_RELATIONSHIP);
        System.assertEquals('ssot__rel_1697761176956_end__r', DC_RelationshipQueryUtil.PASSPORT_RELATIONSHIP);
    }
    
    @IsTest
    static void testBuildSubqueriesFromMappings_AllTypes() {
        List<DC_FieldMap> mappings = new List<DC_FieldMap>{
            new DC_FieldMap('EMAIL:ssot__EmailAddress__c', 'Email'),
            new DC_FieldMap('PHONE:ssot__FormattedE164PhoneNumber__c', 'Phone'),
            new DC_FieldMap('ADDRESS:ssot__AddressLine1__c', 'MailingStreet'),
            new DC_FieldMap('PASSPORT:ssot__IdentificationNumber__c', 'Passport_Number__c')
        };
        
        Set<String> subqueries = DC_RelationshipQueryUtil.buildSubqueriesFromMappings(mappings);
        
        System.assert(subqueries.size() >= 4);
    }
    
    @IsTest
    static void testBuildSubqueriesFromMappings_EmptyList() {
        List<DC_FieldMap> mappings = new List<DC_FieldMap>();
        
        Set<String> subqueries = DC_RelationshipQueryUtil.buildSubqueriesFromMappings(mappings);
        
        System.assertEquals(0, subqueries.size());
    }
    
    @IsTest
    static void testBuildSubqueriesFromMappings_MultipleFieldsSameRelationship() {
        List<DC_FieldMap> mappings = new List<DC_FieldMap>{
            new DC_FieldMap('ADDRESS:ssot__AddressLine1__c', 'MailingStreet'),
            new DC_FieldMap('ADDRESS:ssot__CityId__c', 'MailingCity'),
            new DC_FieldMap('ADDRESS:ssot__StateProvinceId__c', 'MailingState')
        };
        
        Set<String> subqueries = DC_RelationshipQueryUtil.buildSubqueriesFromMappings(mappings);
        
        System.assert(subqueries.size() > 0);
    }
}
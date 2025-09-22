public with sharing class DC_RelationshipQueryUtil {
    
    /**
     * Build subqueries based on field mappings for a given contact type
     */
    public static Set<String> buildSubqueriesFromMappings(List<DC_FieldMap> mappings) {
        Map<String, Set<String>> fieldsByRelationship = new Map<String, Set<String>>();
        
        // Group fields by relationship type
        for (DC_FieldMap mapping : mappings) {
            if (mapping.src.contains(':')) {
                String[] parts = mapping.src.split(':');
                String relationshipType = parts[0];
                String fieldName = parts[1];
                
                if (!fieldsByRelationship.containsKey(relationshipType)) {
                    fieldsByRelationship.put(relationshipType, new Set<String>());
                }
                fieldsByRelationship.get(relationshipType).add(fieldName);
            }
        }
        
        // Build subqueries for each relationship
        Set<String> subqueries = new Set<String>();
        for (String relationshipType : fieldsByRelationship.keySet()) {
            String relationshipName = DC_Mappings.RELATIONSHIP_MAPPINGS.get(relationshipType);
            Set<String> fields = fieldsByRelationship.get(relationshipType);
            
            if (relationshipName != null && !fields.isEmpty()) {
                String subquery = '(SELECT ' + String.join(new List<String>(fields), ', ') + 
                                ' FROM ' + relationshipName;
                
                // Add WHERE clause for PASSPORT
                // if (relationshipType == 'PASSPORT') {
                //     subquery += ' WHERE ssot__IdentificationType__c = \'Passport\'';
                // }
                
                subquery += ' LIMIT 1)';
                subqueries.add(subquery);
            }
        }
        
        return subqueries;
    }
    
    /**
     * Apply relationship data to contact using field mappings
     */
    public static void applyRelationshipDataToContact(Contact targetContact, SObject sourceRecord, List<DC_FieldMap> mappings) {
        for (DC_FieldMap mapping : mappings) {
            if (mapping.src.contains(':')) {
                String[] parts = mapping.src.split(':');
                String relationshipType = parts[0];
                String fieldName = parts[1];
                String relationshipName = DC_Mappings.RELATIONSHIP_MAPPINGS.get(relationshipType);
                
                if (relationshipName != null) {
                    try {
                        List<SObject> relatedRecords = sourceRecord.getSObjects(relationshipName);
                        if (relatedRecords != null && !relatedRecords.isEmpty()) {
                            Object value = relatedRecords[0].get(fieldName);
                            if (value != null) {
                                targetContact.put(mapping.tgt, value);
                            }
                        }
                    } catch (Exception e) {
                        System.debug('Error applying relationship field ' + mapping.src + ': ' + e.getMessage());
                    }
                }
            }
        }
    }
    
    /**
     * Extract contact points for matching using field mappings
     */
    public static Map<String, Map<String, String>> extractContactPointsFromMappings(List<SObject> sourceRecords, List<DC_FieldMap> mappings) {
        Map<String, String> emailToPartyMap = new Map<String, String>();
        Map<String, String> phoneToPartyMap = new Map<String, String>();
        
        // Find email and phone field mappings
        String emailField = null;
        String phoneField = null;
        
        for (DC_FieldMap mapping : mappings) {
            if (mapping.src.startsWith('EMAIL:') && mapping.tgt == 'Email') {
                emailField = mapping.src.split(':')[1];
            } else if (mapping.src.startsWith('PHONE:') && mapping.tgt == 'Phone') {
                phoneField = mapping.src.split(':')[1];
            }
        }
        
        // Extract data using the field mappings
        for (SObject src : sourceRecords) {
            String partyId = (String)src.get('ssot__PartyId__c');
            if (String.isBlank(partyId)) continue;
            
            // Extract email
            if (emailField != null) {
                try {
                    List<SObject> emailRecords = src.getSObjects(DC_Mappings.RELATIONSHIP_MAPPINGS.get('EMAIL'));
                    if (emailRecords != null && !emailRecords.isEmpty()) {
                        String email = (String)emailRecords[0].get(emailField);
                        if (!String.isBlank(email)) {
                            emailToPartyMap.put(email, partyId);
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error extracting email: ' + e.getMessage());
                }
            }
            
            // Extract phone
            if (phoneField != null) {
                try {
                    List<SObject> phoneRecords = src.getSObjects(DC_Mappings.RELATIONSHIP_MAPPINGS.get('PHONE'));
                    if (phoneRecords != null && !phoneRecords.isEmpty()) {
                        String phone = (String)phoneRecords[0].get(phoneField);
                        if (!String.isBlank(phone)) {
                            phoneToPartyMap.put(phone, partyId);
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error extracting phone: ' + e.getMessage());
                }
            }
        }
        
        return new Map<String, Map<String, String>>{
            'email' => emailToPartyMap,
            'phone' => phoneToPartyMap
        };
    }
    
    /**
     * Check if a field is from a relationship (contains colon)
     */
    public static Boolean isRelationshipField(String fieldName) {
        return fieldName != null && fieldName.contains(':');
    }
    
    /**
     * Extract email from relationship data using mappings
     */
    public static String getEmailFromRelationship(SObject sourceRecord, List<DC_FieldMap> mappings) {
        String emailField = null;
        for (DC_FieldMap mapping : mappings) {
            if (mapping.src.startsWith('EMAIL:') && mapping.tgt == 'Email') {
                emailField = mapping.src.split(':')[1];
                break;
            }
        }
        
        if (emailField != null) {
            try {
                List<SObject> emailRecords = sourceRecord.getSObjects(DC_Mappings.RELATIONSHIP_MAPPINGS.get('EMAIL'));
                if (emailRecords != null && !emailRecords.isEmpty()) {
                    return (String)emailRecords[0].get(emailField);
                }
            } catch (Exception e) {
                System.debug('Error extracting email from relationship: ' + e.getMessage());
            }
        }
        return null;
    }
    
    /**
     * Extract phone from relationship data using mappings
     */
    public static String getPhoneFromRelationship(SObject sourceRecord, List<DC_FieldMap> mappings) {
        String phoneField = null;
        for (DC_FieldMap mapping : mappings) {
            if (mapping.src.startsWith('PHONE:') && mapping.tgt == 'Phone') {
                phoneField = mapping.src.split(':')[1];
                break;
            }
        }
        
        if (phoneField != null) {
            try {
                List<SObject> phoneRecords = sourceRecord.getSObjects(DC_Mappings.RELATIONSHIP_MAPPINGS.get('PHONE'));
                if (phoneRecords != null && !phoneRecords.isEmpty()) {
                    return (String)phoneRecords[0].get(phoneField);
                }
            } catch (Exception e) {
                System.debug('Error extracting phone from relationship: ' + e.getMessage());
            }
        }
        return null;
    }
    
    /**
     * Extract address components from relationship data using mappings
     */
    public static Map<String, Object> getAddressFromRelationship(SObject sourceRecord, List<DC_FieldMap> mappings) {
        Map<String, Object> addressData = new Map<String, Object>();
        Map<String, String> addressFieldMap = new Map<String, String>();
        
        // Build mapping of target fields to source fields for address
        for (DC_FieldMap mapping : mappings) {
            if (mapping.src.startsWith('ADDRESS:')) {
                String sourceField = mapping.src.split(':')[1];
                addressFieldMap.put(mapping.tgt, sourceField);
            }
        }
        
        if (!addressFieldMap.isEmpty()) {
            try {
                List<SObject> addressRecords = sourceRecord.getSObjects(DC_Mappings.RELATIONSHIP_MAPPINGS.get('ADDRESS'));
                if (addressRecords != null && !addressRecords.isEmpty()) {
                    SObject addressRec = addressRecords[0];
                    for (String targetField : addressFieldMap.keySet()) {
                        String sourceField = addressFieldMap.get(targetField);
                        Object value = addressRec.get(sourceField);
                        if (value != null) {
                            addressData.put(targetField, value);
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Error extracting address from relationship: ' + e.getMessage());
            }
        }
        
        return addressData;
    }
    
    /**
     * Extract passport data from relationship data using mappings
     */
    public static Map<String, Object> getPassportFromRelationship(SObject sourceRecord, List<DC_FieldMap> mappings) {
        Map<String, Object> passportData = new Map<String, Object>();
        Map<String, String> passportFieldMap = new Map<String, String>();
        
        // Build mapping of target fields to source fields for passport
        for (DC_FieldMap mapping : mappings) {
            if (mapping.src.startsWith('PASSPORT:')) {
                String sourceField = mapping.src.split(':')[1];
                passportFieldMap.put(mapping.tgt, sourceField);
            }
        }
        
        if (!passportFieldMap.isEmpty()) {
            try {
                List<SObject> passportRecords = sourceRecord.getSObjects(DC_Mappings.RELATIONSHIP_MAPPINGS.get('PASSPORT'));
                if (passportRecords != null && !passportRecords.isEmpty()) {
                    SObject passportRec = passportRecords[0];
                    for (String targetField : passportFieldMap.keySet()) {
                        String sourceField = passportFieldMap.get(targetField);
                        Object value = passportRec.get(sourceField);
                        if (value != null) {
                            passportData.put(targetField, value);
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Error extracting passport from relationship: ' + e.getMessage());
            }
        }
        
        return passportData;
    }
    
    /**
     * Constants for relationship names - matches your Data Cloud schema
     */
    public static final String EMAIL_RELATIONSHIP = 'ssot__rel_1697761162380_end__r';
    public static final String PHONE_RELATIONSHIP = 'ssot__rel_1697761164176_end__r';
    public static final String ADDRESS_RELATIONSHIP = 'ssot__rel_1697761159567_end__r';
    public static final String PASSPORT_RELATIONSHIP = 'ssot__rel_1697761176956_end__r';
}
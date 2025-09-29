/**
 * Centralized utility for converting Data Cloud string values to proper Salesforce field types
 * All steps should use this class for type conversions
 */
public with sharing class DC_TypeConverter {
    
    /**
     * Convert source value to appropriate target field type based on schema
     * @param targetRecord The target SObject (used to get field schema)
     * @param targetFieldName The field name to convert for
     * @param sourceValue The value from Data Cloud (typically a string or null)
     * @return Object The properly typed value for the field
     */
    public static Object convertToTargetFieldType(SObject targetRecord, String targetFieldName, Object sourceValue) {
        if (sourceValue == null) return null;
        
        try {
            // Get target field type from schema
            Schema.SObjectType targetType = targetRecord.getSObjectType();
            Schema.DescribeSObjectResult describe = targetType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
            
            Schema.SObjectField targetField = fieldMap.get(targetFieldName);
            if (targetField == null) {
                System.debug(LoggingLevel.WARN, 'Field not found in schema: ' + targetFieldName + '. Returning as-is.');
                return sourceValue;
            }
            
            Schema.DescribeFieldResult fieldDescribe = targetField.getDescribe();
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            // Convert based on target field type
            return convertByDisplayType(fieldType, sourceValue, targetFieldName);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error converting field ' + targetFieldName + ': ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Source value: ' + sourceValue + ' (Type: ' + getValueType(sourceValue) + ')');
            return null; // Return null to skip this field assignment
        }
    }
    
    /**
     * Convert value based on Salesforce field type
     */
    private static Object convertByDisplayType(Schema.DisplayType fieldType, Object value, String fieldName) {
        switch on fieldType {
            when STRING, TEXTAREA, EMAIL, PHONE, URL {
                return convertToString(value);
            }
            when PICKLIST, MULTIPICKLIST {
                return convertToString(value);
            }
            when INTEGER {
                return convertToInteger(value);
            }
            when DOUBLE, CURRENCY, PERCENT {
                return convertToDecimal(value);
            }
            when BOOLEAN {
                return convertToBoolean(value);
            }
            when DATE {
                return convertToDate(value);
            }
            when DATETIME {
                return convertToDateTime(value);
            }
            when TIME {
                return convertToTime(value);
            }
            when ID, REFERENCE {
                // For lookup fields, return as-is if already an Id, otherwise try to convert
                return convertToId(value);
            }
            when else {
                System.debug(LoggingLevel.WARN, 'Unknown field type for ' + fieldName + ': ' + fieldType + '. Returning as-is.');
                return value;
            }
        }
    }
    
    /**
     * Convert to String
     */
    public static String convertToString(Object value) {
        if (value == null) return null;
        if (value instanceof String) return (String) value;
        return String.valueOf(value);
    }
    
    /**
     * Convert to Integer
     */
    public static Integer convertToInteger(Object value) {
        if (value == null) return null;
        
        if (value instanceof Integer) {
            return (Integer) value;
        }
        
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        
        if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (String.isBlank(strValue)) return null;
            
            try {
                // Handle decimal strings by converting to Decimal first
                if (strValue.contains('.')) {
                    return Decimal.valueOf(strValue).intValue();
                }
                return Integer.valueOf(strValue);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Cannot convert string to integer: ' + value);
                return null;
            }
        }
        
        if (value instanceof Long) {
            return ((Long) value).intValue();
        }
        
        System.debug(LoggingLevel.ERROR, 'Unsupported type for integer conversion: ' + getValueType(value));
        return null;
    }
    
    /**
     * Convert to Decimal
     */
    public static Decimal convertToDecimal(Object value) {
        if (value == null) return null;
        
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        
        if (value instanceof Integer) {
            return Decimal.valueOf((Integer) value);
        }
        
        if (value instanceof Long) {
            return Decimal.valueOf((Long) value);
        }
        
        if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (String.isBlank(strValue)) return null;
            
            try {
                // Remove currency symbols and commas
                strValue = strValue.replaceAll('[,$€£¥]', '');
                return Decimal.valueOf(strValue);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Cannot convert string to decimal: ' + value);
                return null;
            }
        }
        
        if (value instanceof Double) {
            return Decimal.valueOf((Double) value);
        }
        
        System.debug(LoggingLevel.ERROR, 'Unsupported type for decimal conversion: ' + getValueType(value));
        return null;
    }
    
    /**
     * Convert to Boolean
     */
    public static Boolean convertToBoolean(Object value) {
        if (value == null) return null;
        
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        
        if (value instanceof String) {
            String strValue = ((String) value).toLowerCase().trim();
            if (String.isBlank(strValue)) return null;
            
            if (strValue == 'true' || strValue == '1' || strValue == 'yes' || strValue == 'y') {
                return true;
            }
            if (strValue == 'false' || strValue == '0' || strValue == 'no' || strValue == 'n') {
                return false;
            }
            
            System.debug(LoggingLevel.ERROR, 'Cannot convert string to boolean: ' + value);
            return null;
        }
        
        if (value instanceof Integer) {
            return ((Integer) value) != 0;
        }
        
        if (value instanceof Decimal) {
            return ((Decimal) value) != 0;
        }
        
        System.debug(LoggingLevel.ERROR, 'Unsupported type for boolean conversion: ' + getValueType(value));
        return null;
    }
    
    /**
     * Convert to Date
     * Handles various date formats from Data Cloud
     */
    public static Date convertToDate(Object value) {
        if (value == null) return null;
        
        if (value instanceof Date) {
            return (Date) value;
        }
        
        if (value instanceof DateTime) {
            return ((DateTime) value).date();
        }
        
        if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (String.isBlank(strValue)) return null;
            
            try {
                // Try ISO format with 'T' separator: 2024-01-15T00:00:00
                if (strValue.contains('T')) {
                    String datePart = strValue.substring(0, strValue.indexOf('T'));
                    return Date.valueOf(datePart);
                }
                
                // Try standard date format: 2024-01-15
                if (strValue.contains('-') && strValue.length() >= 10) {
                    return Date.valueOf(strValue.substring(0, 10));
                }
                
                // Try direct parse
                return Date.valueOf(strValue);
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Cannot convert string to date: ' + value);
                return null;
            }
        }
        
        System.debug(LoggingLevel.ERROR, 'Unsupported type for date conversion: ' + getValueType(value));
        return null;
    }
    
    /**
     * Convert to DateTime
     * Handles various datetime formats from Data Cloud
     */
    public static DateTime convertToDateTime(Object value) {
        if (value == null) return null;
        
        if (value instanceof DateTime) {
            return (DateTime) value;
        }
        
        if (value instanceof Date) {
            return DateTime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0));
        }
        
        if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (String.isBlank(strValue)) return null;
            
            try {
                // Try ISO format: 2024-01-15T10:30:00.000Z or 2024-01-15T10:30:00Z
                if (strValue.contains('T')) {
                    // Remove milliseconds and Z if present
                    String cleanValue = strValue.replace('Z', '').replaceAll('\\.\\d+$', '');
                    
                    // Ensure we have a space instead of T for valueOf
                    cleanValue = cleanValue.replace('T', ' ');
                    
                    return DateTime.valueOf(cleanValue);
                }
                
                // Try standard datetime format: 2024-01-15 10:30:00
                if (strValue.contains(' ')) {
                    return DateTime.valueOf(strValue);
                }
                
                // If just a date, convert to datetime at midnight
                Date dateValue = convertToDate(strValue);
                if (dateValue != null) {
                    return DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
                }
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Cannot convert string to datetime: ' + value);
                return null;
            }
        }
        
        System.debug(LoggingLevel.ERROR, 'Unsupported type for datetime conversion: ' + getValueType(value));
        return null;
    }
    
    /**
     * Convert to Time
     */
    public static Time convertToTime(Object value) {
        if (value == null) return null;
        
        if (value instanceof Time) {
            return (Time) value;
        }
        
        if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (String.isBlank(strValue)) return null;
            
            try {
                // Parse time string HH:mm:ss
                String[] parts = strValue.split(':');
                if (parts.size() >= 2) {
                    Integer hour = Integer.valueOf(parts[0]);
                    Integer minute = Integer.valueOf(parts[1]);
                    Integer second = parts.size() >= 3 ? Integer.valueOf(parts[2]) : 0;
                    return Time.newInstance(hour, minute, second, 0);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Cannot convert string to time: ' + value);
                return null;
            }
        }
        
        System.debug(LoggingLevel.ERROR, 'Unsupported type for time conversion: ' + getValueType(value));
        return null;
    }
    
    /**
     * Convert to Id (for lookup fields)
     */
    public static Id convertToId(Object value) {
        if (value == null) return null;
        
        if (value instanceof Id) {
            return (Id) value;
        }
        
        if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (String.isBlank(strValue)) return null;
            
            try {
                // Validate it's a proper 15 or 18 character Salesforce Id
                if (strValue.length() == 15 || strValue.length() == 18) {
                    return Id.valueOf(strValue);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Cannot convert string to Id: ' + value);
                return null;
            }
        }
        
        System.debug(LoggingLevel.ERROR, 'Unsupported type for Id conversion: ' + getValueType(value));
        return null;
    }
    
    /**
     * Get the type name of a value for debugging
     */
    private static String getValueType(Object value) {
        if (value == null) return 'null';
        if (value instanceof String) return 'String';
        if (value instanceof Integer) return 'Integer';
        if (value instanceof Long) return 'Long';
        if (value instanceof Decimal) return 'Decimal';
        if (value instanceof Double) return 'Double';
        if (value instanceof Boolean) return 'Boolean';
        if (value instanceof Date) return 'Date';
        if (value instanceof DateTime) return 'DateTime';
        if (value instanceof Time) return 'Time';
        if (value instanceof Id) return 'Id';
        return String.valueOf(value).substringBefore(':');
    }
    
    /**
     * Convenience method to set a field with automatic type conversion
     * @param record The target record
     * @param fieldName The field to set
     * @param value The value to convert and set
     */
    public static void setFieldWithConversion(SObject record, String fieldName, Object value) {
        if (value == null) return;
        
        Object convertedValue = convertToTargetFieldType(record, fieldName, value);
        if (convertedValue != null) {
            try {
                record.put(fieldName, convertedValue);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error setting field ' + fieldName + ': ' + e.getMessage());
            }
        }
    }
    
    /**
     * Bulk convert and set multiple fields on a record
     * @param record The target record
     * @param fieldMappings Map of fieldName -> sourceValue
     */
    public static void setFieldsWithConversion(SObject record, Map<String, Object> fieldMappings) {
        if (fieldMappings == null || fieldMappings.isEmpty()) return;
        
        for (String fieldName : fieldMappings.keySet()) {
            setFieldWithConversion(record, fieldName, fieldMappings.get(fieldName));
        }
    }
}
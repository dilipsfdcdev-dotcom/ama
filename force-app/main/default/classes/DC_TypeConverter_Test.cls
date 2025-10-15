@IsTest
private class DC_TypeConverter_Test {
    
    @IsTest
    static void testConvertToString() {
        System.assertEquals('test', DC_TypeConverter.convertToString('test'));
        System.assertEquals('123', DC_TypeConverter.convertToString(123));
        System.assertEquals(null, DC_TypeConverter.convertToString(null));
    }
    
    @IsTest
    static void testConvertToInteger() {
        System.assertEquals(123, DC_TypeConverter.convertToInteger(123));
        System.assertEquals(123, DC_TypeConverter.convertToInteger('123'));
        System.assertEquals(123, DC_TypeConverter.convertToInteger(123.45));
        System.assertEquals(123, DC_TypeConverter.convertToInteger('123.45'));
        System.assertEquals(null, DC_TypeConverter.convertToInteger(null));
        System.assertEquals(null, DC_TypeConverter.convertToInteger('invalid'));
    }
    
    @IsTest
    static void testConvertToDecimal() {
        System.assertEquals(123.45, DC_TypeConverter.convertToDecimal(123.45));
        System.assertEquals(123.45, DC_TypeConverter.convertToDecimal('123.45'));
        System.assertEquals(123, DC_TypeConverter.convertToDecimal(123));
        System.assertEquals(null, DC_TypeConverter.convertToDecimal(null));
        System.assertEquals(null, DC_TypeConverter.convertToDecimal('invalid'));
    }
    
    @IsTest
    static void testConvertToBoolean() {
        System.assertEquals(true, DC_TypeConverter.convertToBoolean(true));
        System.assertEquals(true, DC_TypeConverter.convertToBoolean('true'));
        System.assertEquals(true, DC_TypeConverter.convertToBoolean('1'));
        System.assertEquals(true, DC_TypeConverter.convertToBoolean('yes'));
        System.assertEquals(false, DC_TypeConverter.convertToBoolean(false));
        System.assertEquals(false, DC_TypeConverter.convertToBoolean('false'));
        System.assertEquals(false, DC_TypeConverter.convertToBoolean('0'));
        System.assertEquals(null, DC_TypeConverter.convertToBoolean(null));
    }
    
    @IsTest
    static void testConvertToDate() {
        Date testDate = Date.today();
        
        // Test Date input
        System.assertEquals(testDate, DC_TypeConverter.convertToDate(testDate));
        
        // Test DateTime input
        DateTime testDateTime = DateTime.newInstance(testDate, Time.newInstance(0, 0, 0, 0));
        System.assertEquals(testDate, DC_TypeConverter.convertToDate(testDateTime));
        
        // Test String input in ISO format
        String isoDate = testDate.year() + '-' + 
                        String.valueOf(testDate.month()).leftPad(2, '0') + '-' + 
                        String.valueOf(testDate.day()).leftPad(2, '0');
        System.assertEquals(testDate, DC_TypeConverter.convertToDate(isoDate));
        
        // Test null
        System.assertEquals(null, DC_TypeConverter.convertToDate(null));
        
        // Test with T separator
        String isoDateTimeStr = isoDate + 'T00:00:00';
        System.assertEquals(testDate, DC_TypeConverter.convertToDate(isoDateTimeStr));
    }
    
    @IsTest
    static void testConvertToDateTime() {
        DateTime testDateTime = DateTime.now();
        System.assertNotEquals(null, DC_TypeConverter.convertToDateTime(testDateTime));
        System.assertNotEquals(null, DC_TypeConverter.convertToDateTime(Date.today()));
        System.assertNotEquals(null, DC_TypeConverter.convertToDateTime('2024-01-15T10:30:00Z'));
        System.assertEquals(null, DC_TypeConverter.convertToDateTime(null));
    }
    
    @IsTest
    static void testConvertToTime() {
        Time testTime = Time.newInstance(10, 30, 0, 0);
        System.assertEquals(testTime, DC_TypeConverter.convertToTime(testTime));
        System.assertNotEquals(null, DC_TypeConverter.convertToTime('10:30:00'));
        System.assertEquals(null, DC_TypeConverter.convertToTime(null));
    }
    
    @IsTest
    static void testConvertToId() {
        Account acc = new Account(Name = 'Test');
        insert acc;
        
        System.assertEquals(acc.Id, DC_TypeConverter.convertToId(acc.Id));
        System.assertEquals(acc.Id, DC_TypeConverter.convertToId(String.valueOf(acc.Id)));
        System.assertEquals(null, DC_TypeConverter.convertToId(null));
        System.assertEquals(null, DC_TypeConverter.convertToId('invalid'));
    }
    
    @IsTest
    static void testConvertToTargetFieldType() {
        Account acc = new Account(Name = 'Test');
        
        Object result = DC_TypeConverter.convertToTargetFieldType(acc, 'Name', 'TestValue');
        System.assertEquals('TestValue', result);
        
        result = DC_TypeConverter.convertToTargetFieldType(acc, 'NumberOfEmployees', '100');
        System.assertEquals(100, result);
        
        result = DC_TypeConverter.convertToTargetFieldType(acc, 'IsDeleted', 'true');
        System.assertEquals(true, result);
    }
    
    @IsTest
    static void testSetFieldWithConversion() {
        Account acc = new Account();
        
        DC_TypeConverter.setFieldWithConversion(acc, 'Name', 'Test Account');
        System.assertEquals('Test Account', acc.Name);
        
        DC_TypeConverter.setFieldWithConversion(acc, 'NumberOfEmployees', '100');
        System.assertEquals(100, acc.NumberOfEmployees);
    }
    
    @IsTest
    static void testSetFieldsWithConversion() {
        Account acc = new Account();
        Map<String, Object> fieldMappings = new Map<String, Object>{
            'Name' => 'Test Account',
            'NumberOfEmployees' => '100'
        };
        
        DC_TypeConverter.setFieldsWithConversion(acc, fieldMappings);
        System.assertEquals('Test Account', acc.Name);
        System.assertEquals(100, acc.NumberOfEmployees);
    }
    
    @IsTest
    static void testConvertToDate_EdgeCases() {
        // Test with blank string
        System.assertEquals(null, DC_TypeConverter.convertToDate(''));
        System.assertEquals(null, DC_TypeConverter.convertToDate('   '));
        
        // Test with invalid format
        System.assertEquals(null, DC_TypeConverter.convertToDate('invalid-date'));
    }
    
    @IsTest
    static void testConvertToDateTime_EdgeCases() {
        // Test with various ISO formats
        System.assertNotEquals(null, DC_TypeConverter.convertToDateTime('2024-01-15 10:30:00'));
        System.assertNotEquals(null, DC_TypeConverter.convertToDateTime('2024-01-15T10:30:00.000Z'));
        
        // Test with invalid format
        System.assertEquals(null, DC_TypeConverter.convertToDateTime('invalid'));
    }
}
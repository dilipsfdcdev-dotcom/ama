@IsTest
private class DC_MultiSourceData_Test {
    
    @IsTest
    static void testConstructor() {
        List<Object> mainRecords = new List<Object>{
            new Map<String, Object>{'Id' => '123'}
        };
        
        DC_MultiSourceData data = new DC_MultiSourceData(mainRecords);
        
        System.assertNotEquals(null, data);
        System.assertEquals(1, data.mainRecords.size());
        System.assertNotEquals(null, data.additionalData);
    }
    
    @IsTest
    static void testConstructorWithNull() {
        DC_MultiSourceData data = new DC_MultiSourceData(null);
        
        System.assertNotEquals(null, data);
        System.assertEquals(0, data.mainRecords.size());
    }
    
    @IsTest
    static void testAddAdditionalData() {
        DC_MultiSourceData data = new DC_MultiSourceData(new List<Object>());
        
        Account acc = new Account(Name = 'Test');
        List<SObject> records = new List<SObject>{acc};
        
        data.addAdditionalData('email', 'test@example.com', records);
        
        List<SObject> retrieved = data.getAdditionalData('email', 'test@example.com');
        System.assertEquals(1, retrieved.size());
    }
    
    @IsTest
    static void testGetAdditionalData_NotFound() {
        DC_MultiSourceData data = new DC_MultiSourceData(new List<Object>());
        
        List<SObject> retrieved = data.getAdditionalData('email', 'notfound@example.com');
        System.assertEquals(0, retrieved.size());
    }
    
    @IsTest
    static void testAddMultipleAdditionalData() {
        DC_MultiSourceData data = new DC_MultiSourceData(new List<Object>());
        
        Account acc1 = new Account(Name = 'Test1');
        Account acc2 = new Account(Name = 'Test2');
        
        data.addAdditionalData('email', 'test1@example.com', new List<SObject>{acc1});
        data.addAdditionalData('email', 'test2@example.com', new List<SObject>{acc2});
        
        List<SObject> retrieved1 = data.getAdditionalData('email', 'test1@example.com');
        List<SObject> retrieved2 = data.getAdditionalData('email', 'test2@example.com');
        
        System.assertEquals(1, retrieved1.size());
        System.assertEquals(1, retrieved2.size());
    }
    
    @IsTest
    static void testAddAdditionalData_MultipleSources() {
        DC_MultiSourceData data = new DC_MultiSourceData(new List<Object>());
        
        Account acc1 = new Account(Name = 'Test1');
        Account acc2 = new Account(Name = 'Test2');
        
        data.addAdditionalData('email', 'test@example.com', new List<SObject>{acc1});
        data.addAdditionalData('phone', '555-1234', new List<SObject>{acc2});
        
        List<SObject> emailRecords = data.getAdditionalData('email', 'test@example.com');
        List<SObject> phoneRecords = data.getAdditionalData('phone', '555-1234');
        
        System.assertEquals(1, emailRecords.size());
        System.assertEquals(1, phoneRecords.size());
    }
}
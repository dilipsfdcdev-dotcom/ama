@IsTest
private class DC_BaseStep_Test {

    // ---- Test-only subclass to surface protected utilities of DC_BaseStep ----
    private class TestableStep extends DC_BaseStep {
        public String srcObj = 'ssot__Account__dlm';
        public String orderByField = 'ssot__Id__c';
        public Set<String> srcFieldsSet = new Set<String>{ 'Name', 'SEAWARE_Agency_ID__c' };

        public override String sourceObjectApi() { return srcObj; }
        public override String orderBySourceField() { return orderByField; }
        public override Set<String> sourceFields() { return srcFieldsSet; }

        // Minimal mapScope that demonstrates mapping and returns a bundle
        public override DC_UpsertBundle mapScope(Object scope) {
            List<SObject> outs = new List<SObject>();
            if (scope instanceof List<Object>) {
                for (Object row : (List<Object>)scope) {
                    Account a = new Account();
                    // exercise applyFieldMapping(s)
                    DC_FieldMap m1 = new DC_FieldMap('srcName', 'Name');
                    DC_FieldMap m2 = new DC_FieldMap('srcExt',  'SEAWARE_Agency_ID__c');
                    applyFieldMapping(a, row, m1);
                    applyFieldMappings(a, row, new List<DC_FieldMap>{ m2 });

                    // also exercise setFieldValue direct path + conversion
                    setFieldValue(a, 'NumberOfEmployees', '123'); // string -> number

                    outs.add(a);
                }
            }
            return new DC_UpsertBundle(outs, 'SEAWARE_Agency_ID__c');
        }

        public override void afterUpsert(Object scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
            // no-op; we just want to cover method
        }

        // Expose protected helpers for direct testing
        public Object   callGetFieldValue(Object record, String fieldName) { return getFieldValue(record, fieldName); }
        public void     callSetFieldValue(SObject rec, String fieldName, Object v) { setFieldValue(rec, fieldName, v); }
        public Boolean  callIsDataCloudStep() { return isDataCloudStep(); }
        public Id       callGetRecordTypeId(Schema.SObjectType t, String rtName) { return getRecordTypeId(t, rtName); }
        public Map<String, Id> callBulkLookup(String obj, String extField, Set<String> ids) { return bulkLookupByExternalId(obj, extField, ids); }
        public Date     callConvertToDate(Object v) { return convertToDate(v); }
        public DateTime callConvertToDateTime(Object v) { return convertToDateTime(v); }
        public Decimal  callConvertToDecimal(Object v) { return convertToDecimal(v); }
        public Boolean  callConvertToBoolean(Object v) { return convertToBoolean(v); }
        public String   callFormatDateForCDP(Date d) { return formatDateForCDP(d); }
        public SObject  callFirstAdditional(DC_MultiSourceData d, String alias, String key) { return getFirstAdditionalRecord(d, alias, key); }
        public List<SObject> callAllAdditional(DC_MultiSourceData d, String alias, String key) { return getAllAdditionalRecords(d, alias, key); }
    }

    // ---- Seed Data ----
    @TestSetup
    static void setupData() {
        insert new Account(Name = 'Seed A', SEAWARE_Agency_ID__c = 'TEST123');
        insert new Account(Name = 'Seed B', SEAWARE_Agency_ID__c = 'TEST456');
    }

    // ---- Core DC_BaseStep utility & branches coverage ----
    @IsTest
    static void test_ProtectedHelpers_FieldAccess_TypeConversion() {
        TestableStep step = new TestableStep();

        // getFieldValue on Map and SObject
        Map<String,Object> m = new Map<String,Object>{ 'foo' => 'bar', 'num' => 10 };
        System.assertEquals('bar', step.callGetFieldValue(m, 'foo'));
        System.assertEquals(10, step.callGetFieldValue(m, 'num'));

        Account a = new Account(Name='X');
        System.assertEquals('X', step.callGetFieldValue(a, 'Name'));

        // Unknown record type branch
        System.assertEquals(null, step.callGetFieldValue(5, 'anything'));

        // setFieldValue via TypeConverter path
        step.callSetFieldValue(a, 'NumberOfEmployees', '100');
        System.assertEquals(100, a.NumberOfEmployees);

        step.callSetFieldValue(a, 'Name', 'Changed');
        System.assertEquals('Changed', a.Name);

        // setFieldValue ignores nulls
        step.callSetFieldValue(a, 'Name', null);
        System.assertEquals('Changed', a.Name);
    }

    @IsTest
    static void test_MappingHelpers_and_mapScope() {
        TestableStep step = new TestableStep();

        List<Object> scope = new List<Object>{
            new Map<String,Object>{
                'srcName' => 'Mapped Name',
                'srcExt'  => 'EXT-001'
            }
        };

        DC_UpsertBundle bundle = step.mapScope(scope);
        System.assertEquals('SEAWARE_Agency_ID__c', bundle.externalIdField);
        System.assertEquals(1, bundle.records.size());

        Account out = (Account)bundle.records[0];
        System.assertEquals('Mapped Name', out.Name);
        System.assertEquals('EXT-001', out.SEAWARE_Agency_ID__c);
        System.assertEquals(123, out.NumberOfEmployees);
    }

    @IsTest
    static void test_AdditionalDataHelpers_and_MapMultiSourceScope() {
        TestableStep step = new TestableStep();

        // DC_MultiSourceData with empty lists to cover null/empty branches
        DC_MultiSourceData data = new DC_MultiSourceData(new List<Object>());
        // first/all additional should be null/empty gracefully
        System.assertEquals(null, step.callFirstAdditional(data, 'alias1', 'key1'));
        System.assertEquals(0, step.callAllAdditional(data, 'alias1', 'key1').size());

        // MapMultiSourceScope just delegates to mapScope(mainRecords)
        DC_UpsertBundle bundle = step.mapMultiSourceScope(data);
        System.assertNotEquals(null, bundle);
        System.assertEquals(0, bundle.records.size());
    }

    @IsTest
    static void test_isDataCloudStep_true_false() {
        TestableStep step = new TestableStep();
        step.srcObj = 'ssot__Account__dlm';
        System.assertEquals(true, step.callIsDataCloudStep());

        step.srcObj = 'CustomObject__c'; // not ssot__/__dlm
        System.assertEquals(false, step.callIsDataCloudStep());
    }

    @IsTest
    static void test_formatDateAndConverters() {
        TestableStep step = new TestableStep();

        Date d = Date.newInstance(2025, 10, 21);
        System.assertEquals('2025-10-21', step.callFormatDateForCDP(d));

        // Conversion wrappers (delegate to DC_TypeConverter)
        System.assertEquals(Date.newInstance(2025,10,21), step.callConvertToDate('2025-10-21'));
        System.assertNotEquals(null, step.callConvertToDateTime('2025-10-21T11:12:13Z'));
        System.assertEquals(12.34, step.callConvertToDecimal('12.34'));
        System.assertEquals(true, step.callConvertToBoolean('true'));
    }

    @IsTest
    static void test_getRecordTypeId_and_bulkLookup_success_and_error() {
        TestableStep step = new TestableStep();

        // ---- getRecordTypeId using describe (no metadata DML) ----
        Schema.DescribeSObjectResult d = Schema.Account.SObjectType.getDescribe();
        Id expectedRtId = null;
        String expectedRtName = null;

        for (Schema.RecordTypeInfo rti : d.getRecordTypeInfos()) {
            if (!rti.isMaster() && rti.isAvailable()) {
                expectedRtId = rti.getRecordTypeId();
                expectedRtName = rti.getName();
                break;
            }
        }

        if (expectedRtName != null) {
            // Positive path: found a real RT in this org
            Id rtId = step.callGetRecordTypeId(Schema.Account.SObjectType, expectedRtName);
            System.assertEquals(expectedRtId, rtId, 'Should return the actual RecordType Id');
        } else {
            // Fallback: no custom RTs in this org; cover null branch
            Id rtId = step.callGetRecordTypeId(Schema.Account.SObjectType, 'NonExistentRT');
            System.assertEquals(null, rtId, 'Should return null when RT name is not found');
        }

        // ---- bulk lookup success ----
        Map<String, Id> ok = step.callBulkLookup(
            'Account', 'SEAWARE_Agency_ID__c', new Set<String>{ 'TEST123', 'NOPE' }
        );
        System.assertEquals(true, ok.containsKey('TEST123'));
        System.assertEquals(false, ok.containsKey('NOPE'));

        // ---- bulk lookup empty set (early return) ----
        Map<String, Id> empty = step.callBulkLookup('Account', 'SEAWARE_Agency_ID__c', new Set<String>());
        System.assertEquals(0, empty.size());

        // ---- bulk lookup error path (bad sObject) ----
        Map<String, Id> bad = step.callBulkLookup('DoesNotExist__c', 'ExtId__c', new Set<String>{ 'X' });
        System.assertEquals(0, bad.size());
    }

    // ---- Keep concrete step sanity tests to touch real implementations ----

    @IsTest
    static void test_AccountStep_MapScope_Sanity() {
        DC_AccountStep step = new DC_AccountStep();
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'ssot__Id__c' => 'ACC001',
                'ssot__Name__c' => 'Test Account',
                'Address_City__c' => 'Test City',
                'ssot__LastModifiedDate__c' => DateTime.now()
            }
        };
        DC_UpsertBundle bundle = step.mapScope(scope);
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('SEAWARE_Agency_ID__c', bundle.externalIdField);
    }

    @IsTest
    static void test_ShipStep_MapScope_Sanity() {
        DC_ShipStep step = new DC_ShipStep();
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Ship_ID__c' => 'SHIP001',
                'Ship_Name__c' => 'Test Ship',
                'Passengers__c' => 1000
            }
        };
        DC_UpsertBundle bundle = step.mapScope(scope);
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('Ship_ID__c', bundle.externalIdField);
    }

    @IsTest
    static void test_GetAdditionalSources_and_MapMultiSource_on_AccountStep() {
        DC_AccountStep step = new DC_AccountStep();
        System.assertNotEquals(null, step.getAdditionalSources());
        DC_MultiSourceData data = new DC_MultiSourceData(new List<Object>());
        System.assertNotEquals(null, step.mapMultiSourceScope(data));
    }

    @IsTest
    static void test_SourceObject_and_OrderBy_fields() {
        System.assertEquals('ssot__Account__dlm', new DC_AccountStep().sourceObjectApi());
        System.assertEquals('ssot__Id__c', new DC_AccountStep().orderBySourceField());
        System.assertEquals('Seaware_Ship__dlm', new DC_ShipStep().sourceObjectApi());
        System.assertEquals('Ship_ID__c', new DC_ShipStep().orderBySourceField());
    }

    @IsTest
    static void test_SourceFields_present() {
        Set<String> fields = new DC_AccountStep().sourceFields();
        System.assertNotEquals(null, fields);
        System.assert(fields.size() > 0);
    }

    @IsTest
    static void test_AfterUpsert_noErrors() {
        DC_AccountStep step = new DC_AccountStep();
        step.afterUpsert(new List<Object>(), new DC_UpsertBundle(new List<SObject>(), 'Id'), new Database.UpsertResult[0]);
        System.assert(true, 'afterUpsert should complete ok');
    }

    @IsTest
    static void test_CommissionStep_MapScope_Sanity() {
        // Ensure the seed Account with SEAWARE_Agency_ID__c = TEST123 exists
        Account acc = [SELECT Id FROM Account WHERE SEAWARE_Agency_ID__c = 'TEST123' LIMIT 1];

        DC_CommissionStep step = new DC_CommissionStep();
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Agency_ID__c' => 'TEST123',
                'Commission_Code__c' => 'COMM001',
                'Commission_Name__c' => 'Test Commission',
                'Last_Modified_Date__c' => DateTime.now()
            }
        };
        DC_UpsertBundle bundle = step.mapScope(scope);
        System.assertEquals(1, bundle.records.size());
        System.assertEquals('AgencyID__c', bundle.externalIdField);
    }

    @IsTest
    static void test_DC_TypeConverter_direct() {
        Account a = new Account();
        DC_TypeConverter.setFieldWithConversion(a, 'Name', 'Converted');
        System.assertEquals('Converted', a.Name);
        DC_TypeConverter.setFieldWithConversion(a, 'NumberOfEmployees', '100');
        System.assertEquals(100, a.NumberOfEmployees);
    }

    @IsTest
    static void test_MapScope_withNulls_onShipStep() {
        DC_ShipStep step = new DC_ShipStep();
        List<Object> scope = new List<Object>{
            new Map<String, Object>{
                'Ship_ID__c' => 'SHIP002',
                'Ship_Name__c' => null,
                'Passengers__c' => null
            }
        };
        DC_UpsertBundle bundle = step.mapScope(scope);
        System.assertEquals(1, bundle.records.size());
    }
}
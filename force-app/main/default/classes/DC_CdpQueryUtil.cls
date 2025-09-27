public with sharing class DC_CdpQueryUtil {
    
    /**
     * Execute CDP query and return parsed results
     * @param sql ANSI SQL query string
     * @return List of SObject-like records
     */
    public static List<Map<String, Object>> executeQuery(String sql) {
        try {
            ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
            input.sql = sql;
            
            // ENHANCED LOGGING - Log the exact SQL being executed
            System.debug(LoggingLevel.ERROR, '=== CDP QUERY EXECUTION START ===');
            System.debug(LoggingLevel.ERROR, 'SQL Query: ' + sql);
            System.debug(LoggingLevel.ERROR, 'SQL Length: ' + sql.length());
            System.debug(LoggingLevel.ERROR, '=== CDP QUERY EXECUTION ===');
            
            ConnectApi.CdpQueryOutputV2 page = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
            
            List<Map<String, Object>> results = toKeyValue(page);
            System.debug(LoggingLevel.WARN, 'CDP Query returned: ' + results.size() + ' rows');
            
            return results;
        } catch (Exception e) {
            // ENHANCED ERROR LOGGING
            System.debug(LoggingLevel.ERROR, '=== CDP QUERY ERROR ===');
            System.debug(LoggingLevel.ERROR, 'Error Message: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Error Type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            System.debug(LoggingLevel.ERROR, 'Failed SQL: ' + sql);
            System.debug(LoggingLevel.ERROR, '=== END CDP QUERY ERROR ===');
            
            // **FIX: Parse the error message to provide more specific guidance**
            String errorMessage = e.getMessage();
            String enhancedMessage = 'CDP Query execution failed: ' + errorMessage;
            
            if (errorMessage.contains('TYPE_MISMATCH')) {
                enhancedMessage += '. HINT: Check date/datetime field formats and data types in WHERE clause.';
            } else if (errorMessage.contains('BAD_REQUEST')) {
                enhancedMessage += '. HINT: Verify field names, object names, and SQL syntax.';
            } else if (errorMessage.contains('FIELD_NOT_FOUND')) {
                enhancedMessage += '. HINT: One or more fields in SELECT or WHERE clause do not exist.';
            }
            
            throw new DC_SyncException(enhancedMessage);
        }
    }
    
    /**
     * Convert CDP V2 response to key-value maps using metadata.placeInOrder
     */
    private static List<Map<String, Object>> toKeyValue(ConnectApi.CdpQueryOutputV2 page) {
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(page));
        
        // 1) Build ordered columns from metadata
        Map<String, Object> metaMap = (Map<String, Object>) root.get('metadata');
        List<Col> colsOrdered = new List<Col>();
        
        if (metaMap != null) {
            for (String colName : metaMap.keySet()) {
                Map<String, Object> md = (Map<String, Object>) metaMap.get(colName);
                Integer pos = md != null && md.containsKey('placeInOrder')
                    ? Integer.valueOf(String.valueOf(md.get('placeInOrder')))
                    : 0;
                colsOrdered.add(new Col(colName, pos));
            }
            colsOrdered.sort();
        }
        
        // 2) Data rows: array of arrays
        List<Object> dataRows = (List<Object>) root.get('data');
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        
        if (dataRows == null || dataRows.isEmpty()) {
            return out;
        }
        
        for (Object rowObj : dataRows) {
            List<Object> vals = (List<Object>) rowObj;
            Map<String, Object> rec = new Map<String, Object>();
            
            for (Integer i = 0; i < colsOrdered.size(); i++) {
                Col c = colsOrdered[i];
                Object v = (vals != null && i < vals.size()) ? vals[i] : null;
                rec.put(c.name, v);
            }
            out.add(rec);
        }
        
        return out;
    }
    
    /**
     * Convert Map<String, Object> to SObject for compatibility with existing code
     * Uses Account as container and stores CDP data in a static map for retrieval
     */
    public static List<SObject> convertToSObjects(List<Map<String, Object>> mapRecords, String targetSObjectType) {
        List<SObject> sobjectRecords = new List<SObject>();
        
        if (mapRecords == null || mapRecords.isEmpty()) {
            return sobjectRecords;
        }
        
        for (Map<String, Object> mapRec : mapRecords) {
            // Create an Account SObject as container
            Account container = new Account();
            sobjectRecords.add(container);
            
            // Store the CDP data in a static map keyed by the SObject
            CDP_DATA_MAP.put(container, mapRec);
        }
        
        return sobjectRecords;
    }
    
    /**
     * Get CDP data for a given SObject (if it was created from CDP query)
     */
    public static Map<String, Object> getCdpData(SObject record) {
        return CDP_DATA_MAP.get(record);
    }
    
    /**
     * Check if an SObject has CDP data associated with it
     */
    public static Boolean hasCdpData(SObject record) {
        return CDP_DATA_MAP.containsKey(record);
    }
    
    /**
     * Build SQL for Data Cloud object with WHERE clause and pagination
     */
    public static String buildDataCloudSql(String objectName, Set<String> fields, String whereClause, 
                                          String orderByField, Integer limitSize, Integer offsetValue) {
        
        // ENHANCED LOGGING - Log SQL building process
        System.debug(LoggingLevel.ERROR, '=== BUILDING CDP SQL ===');
        System.debug(LoggingLevel.ERROR, 'Object: ' + objectName);
        System.debug(LoggingLevel.ERROR, 'Fields: ' + fields);
        System.debug(LoggingLevel.ERROR, 'Where Clause: ' + whereClause);
        System.debug(LoggingLevel.ERROR, 'Order By: ' + orderByField);
        System.debug(LoggingLevel.ERROR, 'Limit: ' + limitSize);
        System.debug(LoggingLevel.ERROR, 'Offset: ' + offsetValue);
        
        // **FIX: Validate inputs to prevent SQL injection and malformed queries**
        if (String.isBlank(objectName)) {
            throw new DC_SyncException('Object name cannot be blank for CDP query');
        }
        
        if (fields == null || fields.isEmpty()) {
            throw new DC_SyncException('Field list cannot be empty for CDP query');
        }
        
        // **FIX: Ensure field names are properly escaped and valid**
        List<String> validatedFields = new List<String>();
        for (String field : fields) {
            if (!String.isBlank(field)) {
                // Basic field name validation - alphanumeric plus underscores and double underscores
                String fieldPattern = '^[a-zA-Z][a-zA-Z0-9_]*(__[a-zA-Z0-9_]+)*$';
                if (Pattern.matches(fieldPattern, field)) {
                    validatedFields.add(field);
                } else {
                    System.debug(LoggingLevel.WARN, 'Skipping potentially invalid field name: ' + field);
                }
            }
        }
        
        if (validatedFields.isEmpty()) {
            throw new DC_SyncException('No valid fields found for CDP query after validation');
        }
        
        String sql = 'SELECT ' + String.join(validatedFields, ', ') + 
                    ' FROM ' + objectName;
        
        if (!String.isBlank(whereClause)) {
            sql += ' WHERE ' + whereClause;
        }
        
        if (!String.isBlank(orderByField)) {
            sql += ' ORDER BY ' + orderByField + ' ASC';
        }
        
        if (limitSize != null && limitSize > 0) {
            sql += ' LIMIT ' + limitSize;
        }
        
        if (offsetValue != null && offsetValue > 0) {
            sql += ' OFFSET ' + offsetValue;
        }
        
        System.debug(LoggingLevel.ERROR, 'Built SQL: ' + sql);
        System.debug(LoggingLevel.ERROR, '=== END BUILDING CDP SQL ===');
        
        return sql;
    }
    
    /**
     * Sortable column holder for metadata ordering
     */
    public class Col implements Comparable {
        public String name;
        public Integer pos;
        
        public Col(String n, Integer p) { 
            name = n; 
            pos = p; 
        }
        
        public Integer compareTo(Object other) {
            Col o = (Col) other;
            if (this.pos == null && o.pos == null) return 0;
            if (this.pos == null) return 1;
            if (o.pos == null) return -1;
            if (this.pos == o.pos) return 0;
            return (this.pos > o.pos) ? 1 : -1;
        }
    }
    
    // Static map to store CDP data for SObjects
    private static Map<SObject, Map<String, Object>> CDP_DATA_MAP = new Map<SObject, Map<String, Object>>();
}
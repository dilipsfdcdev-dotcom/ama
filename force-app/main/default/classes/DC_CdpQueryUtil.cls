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
            
            System.debug(LoggingLevel.WARN, 'Executing CDP Query: ' + sql);
            ConnectApi.CdpQueryOutputV2 page = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
            
            List<Map<String, Object>> results = toKeyValue(page);
            System.debug(LoggingLevel.WARN, 'CDP Query returned: ' + results.size() + ' rows');
            
            return results;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CDP Query failed: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'SQL: ' + sql);
            throw new DC_SyncException('CDP Query execution failed: ' + e.getMessage());
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
     */
    public static List<SObject> convertToSObjects(List<Map<String, Object>> mapRecords, String targetSObjectType) {
        List<SObject> sobjectRecords = new List<SObject>();
        
        if (mapRecords == null || mapRecords.isEmpty()) {
            return sobjectRecords;
        }
        
        // Use a generic SObject type for Data Cloud records
        Schema.SObjectType sType = Schema.getGlobalDescribe().get('Account'); // Use Account as generic container
        
        for (Map<String, Object> mapRec : mapRecords) {
            SObject sObj = sType.newSObject();
            
            // Copy all fields from map to SObject
            for (String fieldName : mapRec.keySet()) {
                Object value = mapRec.get(fieldName);
                if (value != null) {
                    try {
                        sObj.put(fieldName, value);
                    } catch (Exception e) {
                        // Field might not exist on Account, but we'll store it anyway for processing
                        System.debug('Warning: Could not set field ' + fieldName + ' on SObject: ' + e.getMessage());
                    }
                }
            }
            sobjectRecords.add(sObj);
        }
        
        return sobjectRecords;
    }
    
    /**
     * Build SQL for Data Cloud object with WHERE clause and pagination
     */
    public static String buildDataCloudSql(String objectName, Set<String> fields, String whereClause, 
                                          String orderByField, Integer limitSize, Integer offsetValue) {
        String sql = 'SELECT ' + String.join(new List<String>(fields), ', ') + 
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
}
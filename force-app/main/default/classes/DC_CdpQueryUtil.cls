public with sharing class DC_CdpQueryUtil {
    
    public static List<Map<String, Object>> executeQuery(String sql) {
        try {
            ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
            input.sql = sql;
            
            System.debug(LoggingLevel.ERROR, '=== CDP QUERY EXECUTION START ===');
            System.debug(LoggingLevel.ERROR, 'SQL Query: ' + sql);
            
            ConnectApi.CdpQueryOutputV2 page = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
            
            List<Map<String, Object>> results = toKeyValue(page);
            System.debug(LoggingLevel.WARN, 'CDP Query returned: ' + results.size() + ' rows');
            
            return results;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '=== CDP QUERY ERROR ===');
            System.debug(LoggingLevel.ERROR, 'Error: ' + e.getMessage());
            throw new DC_SyncException('CDP Query failed: ' + e.getMessage());
        }
    }
    
    private static List<Map<String, Object>> toKeyValue(ConnectApi.CdpQueryOutputV2 page) {
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(page));
        
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
    
    public static String buildDataCloudSql(String objectName, Set<String> fields, String whereClause, 
                                          String orderByField, Integer limitSize, Integer offsetValue) {
        
        if (String.isBlank(objectName)) {
            throw new DC_SyncException('Object name cannot be blank');
        }
        
        if (fields == null || fields.isEmpty()) {
            throw new DC_SyncException('Field list cannot be empty');
        }
        
        List<String> validatedFields = new List<String>();
        for (String field : fields) {
            if (!String.isBlank(field)) {
                validatedFields.add(field);
            }
        }
        
        if (validatedFields.isEmpty()) {
            throw new DC_SyncException('No valid fields found');
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
        
        return sql;
    }
    
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
public with sharing class DC_AccountStep extends DC_BaseStep implements DC_IWhere {

    private static final String SRC_OBJECT   = 'ssot__Account__dlm';
    private static final String ORDER_BY_SRC = 'ssot__Id__c';
    private static final String ACCOUNT_EXTID = 'SEAWARE_Agency_ID__c';
    private static final String STEP_NAME = 'Account';
    private static final Set<String> ACCOUNT_LOOKUPS = new Set<String>{ 'Host_Account__c', 'ParentId' };

    public override String sourceObjectApi()    { return SRC_OBJECT; }
    public override String orderBySourceField() { return ORDER_BY_SRC; }

    public String whereClause() {
        String dateFilter = DC_DateUtil.getDateFilterClause(STEP_NAME, 'ssot__LastModifiedDate__c');
        return 'ssot__DataSourceObjectId__c = \'Seaware_Account_E1C509FE\' AND ' + dateFilter;
    }

    public override Set<String> sourceFields() {
        Set<String> f = new Set<String>();
        for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) f.add(m.src);
        f.add(ORDER_BY_SRC);
        f.add('Parent_ID__c');
        f.add('ssot__LastModifiedDate__c');
        return f;
    }

    /**
     * FIRST PASS: Insert/Update all accounts WITHOUT parent lookups
     * Parent lookups will be handled in the second pass
     */
    public override DC_UpsertBundle mapScope(Object scopeObj) {
        List<Object> scope = (List<Object>)scopeObj;
        
        System.debug(LoggingLevel.WARN, '=== ACCOUNT STEP - FIRST PASS START ===');
        System.debug(LoggingLevel.WARN, 'Input scope size: ' + scope.size());
        
        // Deduplicate by external ID
        Map<String, Object> deduplicatedRecords = new Map<String, Object>();
        Map<String, DateTime> latestTimestamp = new Map<String, DateTime>();
        
        for (Object srcObj : scope) {
            String accountId = (String) getFieldValue(srcObj, ORDER_BY_SRC);
            if (String.isBlank(accountId)) {
                System.debug(LoggingLevel.WARN, 'Skipping record with blank external ID');
                continue;
            }

            DateTime lastModified = convertToDateTime(getFieldValue(srcObj, 'ssot__LastModifiedDate__c'));
            if (lastModified == null) lastModified = DateTime.now();

            if (!deduplicatedRecords.containsKey(accountId) || 
                lastModified > latestTimestamp.get(accountId)) {
                deduplicatedRecords.put(accountId, srcObj);
                latestTimestamp.put(accountId, lastModified);
            }
        }

        Integer duplicatesRemoved = scope.size() - deduplicatedRecords.size();
        if (duplicatesRemoved > 0) {
            System.debug(LoggingLevel.WARN, 'Removed ' + duplicatesRemoved + ' duplicate records');
        }

        List<SObject> out = new List<SObject>();

        // Process each unique account
        for (String accountId : deduplicatedRecords.keySet()) {
            Object srcObj = deduplicatedRecords.get(accountId);
            
            Account acc = new Account();
            acc.put(ACCOUNT_EXTID, accountId);

            for (DC_FieldMap m : DC_Mappings.ACCOUNT_MAP) {
                if (m.tgt == ACCOUNT_EXTID) continue;
                
                // **SKIP parent lookups in first pass - they'll be handled in second pass**
                if (ACCOUNT_LOOKUPS.contains(m.tgt)) {
                    String parentKey = (String) getFieldValue(srcObj, 'Parent_ID__c');
                    if (!String.isBlank(parentKey)) {
                        System.debug(LoggingLevel.INFO, 'Deferring parent lookup for Account ' + accountId + 
                                    ' (Parent_ID: ' + parentKey + ') to second pass');
                    }
                    continue;
                }
                
                Object value = getFieldValue(srcObj, m.src);
                if (value != null) {
                    setFieldValue(acc, m.tgt, value);
                }
            }
            out.add(acc);
        }

        System.debug(LoggingLevel.WARN, 'First pass output size: ' + out.size());
        System.debug(LoggingLevel.WARN, '=== ACCOUNT STEP - FIRST PASS END ===');
        
        return new DC_UpsertBundle(out, ACCOUNT_EXTID);
    }

    /**
     * SECOND PASS: After all accounts are inserted/updated, update parent lookups
     * This is called when isSecondPass = true in StepRunner
     * During normal batch processing (first pass), scope is not empty and we skip
     * During second pass execution, scope is empty and we run the parent resolution
     */
    public override void afterUpsert(Object scope, DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        // Check if this is being called during normal batch processing (first pass)
        List<Object> scopeList = (List<Object>)scope;
        if (scopeList != null && !scopeList.isEmpty()) {
            // This is being called during normal batch processing (first pass)
            // Do nothing - we'll run second pass after all batches complete
            System.debug(LoggingLevel.INFO, 'afterUpsert called during first pass batch - skipping');
            return;
        }
        
        // **This is the actual second pass - scope is empty**
        System.debug(LoggingLevel.WARN, '=== ACCOUNT STEP - SECOND PASS START ===');
        System.debug(LoggingLevel.WARN, 'Running parent lookup resolution for accounts with Parent_ID');
        
        try {
            // Query Data Cloud for all accounts that have a Parent_ID
            String baseWhereClause = whereClause();
            String whereClauseWithParent =
                baseWhereClause + ' AND COALESCE(TRIM(Parent_ID__c), \'\') <> \'\'';
            
            String sql = DC_CdpQueryUtil.buildDataCloudSql(
                SRC_OBJECT,
                sourceFields(),
                whereClauseWithParent,
                ORDER_BY_SRC,
                10000, // Large limit for second pass
                0
            );
            
            System.debug(LoggingLevel.WARN, 'Querying Data Cloud for accounts with Parent_ID');
            System.debug(LoggingLevel.INFO, 'Second pass SQL: ' + sql);
            
            List<Map<String, Object>> accountsWithParents = DC_CdpQueryUtil.executeQuery(sql);
            System.debug(LoggingLevel.WARN, 'Found ' + accountsWithParents.size() + ' accounts with Parent_ID');
            
            if (accountsWithParents.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No accounts with Parent_ID found - second pass complete');
                return;
            }
            
            // Build lookup map for all parent IDs
            Set<String> parentKeys = new Set<String>();
            Map<String, String> accountToParentMap = new Map<String, String>();
            
            for (Map<String, Object> srcObj : accountsWithParents) {
                String accountExtId = (String) srcObj.get('ssot__Id__c');
                String parentKey = (String) srcObj.get('Parent_ID__c');
                
                if (!String.isBlank(accountExtId) && !String.isBlank(parentKey)) {
                    parentKeys.add(parentKey);
                    accountToParentMap.put(accountExtId, parentKey);
                }
            }
            
            System.debug(LoggingLevel.WARN, 'Resolving ' + parentKeys.size() + ' unique parent IDs');
            Map<String, Id> hostByExt = bulkLookupByExternalId('Account', ACCOUNT_EXTID, parentKeys);
            System.debug(LoggingLevel.WARN, 'Found ' + hostByExt.size() + ' matching parent accounts');
            
            // Build update list - only update accounts where parent was found
            List<Account> accountsToUpdate = new List<Account>();
            Integer successCount = 0;
            Integer failureCount = 0;
            
            for (String accountExtId : accountToParentMap.keySet()) {
                String parentKey = accountToParentMap.get(accountExtId);
                Id parentId = hostByExt.get(parentKey);
                
                if (parentId != null) {
                    Account acc = new Account(
                        SEAWARE_Agency_ID__c = accountExtId,
                        Host_Account__c = parentId,      // Custom lookup
                        ParentId = parentId                // Standard lookup
                    );
                    accountsToUpdate.add(acc);
                    successCount++;
                    
                    System.debug(LoggingLevel.INFO, 'Updating Account ' + accountExtId + 
                                ' with Parent: ' + parentKey + ' (Id: ' + parentId + ')');
                } else {
                    failureCount++;
                    System.debug(LoggingLevel.WARN, 'Parent account not found for Account ' + accountExtId + 
                                ' (Parent_ID: ' + parentKey + ')');
                }
            }
            
            System.debug(LoggingLevel.WARN, 'Accounts to update with parents: ' + accountsToUpdate.size());
            System.debug(LoggingLevel.WARN, 'Successfully resolved: ' + successCount);
            System.debug(LoggingLevel.WARN, 'Failed to resolve: ' + failureCount);
            
            // Update accounts with parent lookups
            if (!accountsToUpdate.isEmpty()) {
                Database.UpsertResult[] updateResults = DC_DmlUtil.upsertByExtId(
                    accountsToUpdate, 
                    ACCOUNT_EXTID, 
                    false
                );
                
                // Log results
                Integer updateSuccessCount = 0;
                Integer updateFailureCount = 0;
                
                for (Database.UpsertResult result : updateResults) {
                    if (result.isSuccess()) {
                        updateSuccessCount++;
                    } else {
                        updateFailureCount++;
                        for (Database.Error err : result.getErrors()) {
                            System.debug(LoggingLevel.ERROR, 'Parent update failed: ' + err.getMessage());
                        }
                    }
                }
                
                System.debug(LoggingLevel.WARN, 'Parent update results - Success: ' + updateSuccessCount + 
                            ', Failed: ' + updateFailureCount);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in second pass: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
        
        System.debug(LoggingLevel.WARN, '=== ACCOUNT STEP - SECOND PASS END ===');
    }
}
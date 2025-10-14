public with sharing class DC_StepRunner implements Queueable, Database.AllowsCallouts {

    private final List<String> stepNames;
    private final Integer index;
    private final String lastKey;
    private final Integer pageSize;
    private final Integer offsetValue;
    private final Date chunkStartDate;
    private final Date chunkEndDate;
    private final Boolean isSecondPass; // **NEW: Track if this is second pass**

    public static final Integer DEFAULT_PAGE_SIZE = 200;
    public static final Integer MAX_CDP_OFFSET = 50000;

    // Constructor for cursor-based pagination (backward compatibility)
    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize) {
        this(stepNames, index, lastKey, pageSize, 0, null, null, false);
    }

    // Constructor with offset support
    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize, Integer offsetValue) {
        this(stepNames, index, lastKey, pageSize, offsetValue, null, null, false);
    }

    // Constructor with date chunking support
    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize, 
                        Integer offsetValue, Date chunkStartDate, Date chunkEndDate) {
        this(stepNames, index, lastKey, pageSize, offsetValue, chunkStartDate, chunkEndDate, false);
    }

    // **NEW: Full constructor with second pass flag**
    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize, 
                        Integer offsetValue, Date chunkStartDate, Date chunkEndDate, Boolean isSecondPass) {
        this.stepNames = stepNames;
        this.index = index;
        this.lastKey = lastKey;
        this.pageSize = (pageSize != null && pageSize > 0) ? pageSize :
                         (DC_Debug.ENABLE && DC_Debug.MAX_ROWS > 0 ? DC_Debug.MAX_ROWS : DEFAULT_PAGE_SIZE);
        this.offsetValue = offsetValue != null ? offsetValue : 0;
        this.chunkStartDate = chunkStartDate;
        this.chunkEndDate = chunkEndDate;
        this.isSecondPass = isSecondPass;
    }

    public void execute(QueueableContext qc) {
        System.debug(LoggingLevel.WARN, '=== DC_StepRunner START ===');
        System.debug(LoggingLevel.WARN, 'Step Index: ' + index + ', StepNames: ' + stepNames + 
                    ', lastKey: ' + lastKey + ', offset: ' + offsetValue + 
                    ', chunkStart: ' + chunkStartDate + ', chunkEnd: ' + chunkEndDate +
                    ', isSecondPass: ' + isSecondPass);

        if (index == null || index >= stepNames.size()) {
            System.debug(LoggingLevel.WARN, 'No more steps to execute. Exiting.');
            return;
        }

        String stepName = stepNames[index];
        DC_IStep step = DC_StepFactory.make(stepName);
        if (step == null) {
            System.debug(LoggingLevel.ERROR, 'No step registered for: ' + stepName);
            enqueueNextStep();
            return;
        }

        // **NEW: Handle second pass specially**
        if (isSecondPass) {
            executeSecondPass(step, stepName);
            return;
        }

        Map<String, DC_JoinConfig> additionalSources = step.getAdditionalSources();
        
        if (additionalSources != null && !additionalSources.isEmpty()) {
            processMultiSourceStep(step, stepName);
        } else {
            processSingleSourceStep(step, stepName);
        }
    }

    /**
     * **NEW METHOD: Execute second pass for steps that need it**
     */
    private void executeSecondPass(DC_IStep step, String stepName) {
        System.debug(LoggingLevel.WARN, '=== EXECUTING SECOND PASS FOR: ' + stepName + ' ===');
        
        try {
            // Call afterUpsert with empty parameters to trigger second pass logic
            step.afterUpsert(
                new List<Object>(), 
                new DC_UpsertBundle(new List<SObject>(), ''), 
                new Database.UpsertResult[0]
            );
            
            System.debug(LoggingLevel.WARN, 'Second pass completed successfully for: ' + stepName);
            
            // After second pass completes, move to next step
            enqueueNextStep();
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in second pass for ' + stepName + ': ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            // Still move to next step even if second pass fails
            enqueueNextStep();
        }
    }

    private void processSingleSourceStep(DC_IStep step, String stepName) {
        Set<String> srcFields = step.sourceFields();
        String srcObject = step.sourceObjectApi();
        String orderField = step.orderBySourceField();

        Boolean isDataCloudObject = srcObject.contains('__dlm') || srcObject.startsWith('ssot__');
        
        List<Object> page;
        
        if (isDataCloudObject) {
            page = queryDataCloudObject(step, stepName, srcFields, srcObject, orderField);
        } else {
            page = queryRegularSalesforceObject(step, stepName, srcFields, srcObject, orderField);
        }

        System.debug(LoggingLevel.WARN, 'Fetched rows: ' + page.size());

        if (page.isEmpty()) {
            if (isDataCloudObject && chunkEndDate != null && chunkEndDate < Date.today()) {
                processNextDateChunk(step, stepName);
            } else {
                System.debug(LoggingLevel.WARN, 'No rows found for step: ' + stepName + '. Moving to next step.');
                enqueueNextStep();
            }
            return;
        }

        DC_UpsertBundle bundle = step.mapScope(page);
        processUpsertAndContinue(step, stepName, page, bundle, isDataCloudObject);
    }

    private List<Object> queryDataCloudObject(DC_IStep step, String stepName, Set<String> srcFields, 
                                              String srcObject, String orderField) {
        
        System.debug(LoggingLevel.ERROR, '=== QUERY DATA CLOUD OBJECT START ===');
        System.debug(LoggingLevel.ERROR, 'Step Name: ' + stepName);
        System.debug(LoggingLevel.ERROR, 'Source Object: ' + srcObject);
        
        String whereClause = '';
        
        if (step instanceof DC_IWhere) {
            String wc = ((DC_IWhere)step).whereClause();
            System.debug(LoggingLevel.ERROR, 'Original WHERE clause from step: ' + wc);
            
            if (!String.isBlank(wc)) {
                if (chunkStartDate != null || chunkEndDate != null) {
                    String modifiedWc = replaceDateFilterWithChunk(wc, chunkStartDate, chunkEndDate, stepName);
                    System.debug(LoggingLevel.ERROR, 'Modified WHERE clause: ' + modifiedWc);
                    whereClause = modifiedWc;
                } else {
                    whereClause = wc;
                }
            }
        }
        
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            srcObject, 
            srcFields, 
            whereClause, 
            orderField, 
            pageSize, 
            offsetValue
        );
        
        System.debug(LoggingLevel.ERROR, 'Executing CDP SQL: ' + sql);
        
        List<Map<String, Object>> mapResults = DC_CdpQueryUtil.executeQuery(sql);
        
        System.debug(LoggingLevel.ERROR, 'CDP Query returned ' + mapResults.size() + ' records');
        System.debug(LoggingLevel.ERROR, '=== QUERY DATA CLOUD OBJECT END ===');
        
        List<Object> results = new List<Object>();
        results.addAll(mapResults);
        return results;
    }

    private List<Object> queryRegularSalesforceObject(DC_IStep step, String stepName, Set<String> srcFields, 
                                                      String srcObject, String orderField) {
        String selectList = String.join(new List<String>(srcFields), ',');
        String soql = 'SELECT ' + selectList + ' FROM ' + srcObject;

        List<String> predicates = new List<String>();
        
        if (step instanceof DC_IWhere) {
            String wc = ((DC_IWhere)step).whereClause();
            if (!String.isBlank(wc)) {
                predicates.add(wc);
            }
        }
        
        if (!String.isBlank(lastKey)) {
            predicates.add(orderField + ' > \'' + String.escapeSingleQuotes(lastKey) + '\'');
        }
        
        if (!predicates.isEmpty()) {
            soql += ' WHERE ' + String.join(predicates, ' AND ');
        }
        
        soql += ' ORDER BY ' + orderField + ' ASC';
        soql += ' LIMIT ' + pageSize;

        System.debug(LoggingLevel.WARN, 'SOQL to execute: ' + soql);
        
        List<SObject> sobjectResults = Database.query(soql);
        List<Object> results = new List<Object>();
        results.addAll(sobjectResults);
        return results;
    }

    private void processMultiSourceStep(DC_IStep step, String stepName) {
        Set<String> srcFields = step.sourceFields();
        String srcObject = step.sourceObjectApi();
        String orderField = step.orderBySourceField();

        Boolean isDataCloudObject = srcObject.contains('__dlm') || srcObject.startsWith('ssot__');
        
        List<Object> mainPage;
        
        if (isDataCloudObject) {
            mainPage = queryDataCloudObject(step, stepName, srcFields, srcObject, orderField);
        } else {
            mainPage = queryRegularSalesforceObject(step, stepName, srcFields, srcObject, orderField);
        }

        System.debug(LoggingLevel.WARN, 'Fetched main rows: ' + mainPage.size());

        if (mainPage.isEmpty()) {
            if (isDataCloudObject && chunkEndDate != null && chunkEndDate < Date.today()) {
                processNextDateChunk(step, stepName);
            } else {
                enqueueNextStep();
            }
            return;
        }

        DC_MultiSourceData multiData = new DC_MultiSourceData(mainPage);

        Map<String, DC_JoinConfig> additionalSources = step.getAdditionalSources();
        for (String sourceAlias : additionalSources.keySet()) {
            fetchAdditionalSourceData(multiData, sourceAlias, additionalSources.get(sourceAlias), mainPage);
        }

        DC_UpsertBundle bundle = step.mapMultiSourceScope(multiData);
        processUpsertAndContinue(step, stepName, mainPage, bundle, isDataCloudObject);
    }

    private String replaceDateFilterWithChunk(String originalWhere, Date startDate, Date endDate, String stepName) {
        String modifiedWhere = originalWhere;
        
        if (startDate != null && endDate != null) {
            DC_IStep step = DC_StepFactory.make(stepName);
            String lastModifiedField = 'ssot__LastModifiedDate__c';
            if (step != null) {
                String sourceObject = step.sourceObjectApi();
                lastModifiedField = DC_DateUtil.getLastModifiedFieldName(sourceObject);
            }
            
            DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            DateTime endDateTime = DateTime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
            String formattedStartDateTime = DC_DateUtil.formatDateTimeForCDP(startDateTime);
            String formattedEndDateTime = DC_DateUtil.formatDateTimeForCDP(endDateTime);
            
            String dateRangeFilter = lastModifiedField + ' >= from_iso8601_timestamp(\'' + formattedStartDateTime + '\') AND ' + 
                                   lastModifiedField + ' < from_iso8601_timestamp(\'' + formattedEndDateTime + '\')';
            
            if (modifiedWhere.contains(lastModifiedField + ' >= from_iso8601_timestamp(\'')) {
                Integer startPos = modifiedWhere.indexOf(lastModifiedField + ' >= from_iso8601_timestamp(\'');
                if (startPos >= 0) {
                    String searchPattern = lastModifiedField + ' < from_iso8601_timestamp(\'';
                    Integer endPatternStart = modifiedWhere.indexOf(searchPattern, startPos);
                    if (endPatternStart >= 0) {
                        Integer dateValueStart = endPatternStart + searchPattern.length();
                        Integer quoteEnd = modifiedWhere.indexOf('\')', dateValueStart);
                        if (quoteEnd >= 0) {
                            String beforeDate = modifiedWhere.substring(0, startPos);
                            String afterDate = modifiedWhere.substring(quoteEnd + 2);
                            modifiedWhere = beforeDate + dateRangeFilter + afterDate;
                        }
                    }
                }
            }
        }
        
        return modifiedWhere;
    }

    private void processNextDateChunk(DC_IStep step, String stepName) {
        Date newStartDate = chunkEndDate.addDays(1);
        Date proposedEndDate = newStartDate.addDays(6);
        Date newEndDate = proposedEndDate > Date.today() ? Date.today() : proposedEndDate;
        
        if (newStartDate <= Date.today()) {
            System.debug(LoggingLevel.WARN, 'Moving to next date chunk: ' + newStartDate + ' to ' + newEndDate);
            System.enqueueJob(new DC_StepRunner(stepNames, index, null, pageSize, 0, newStartDate, newEndDate, false));
        } else {
            System.debug(LoggingLevel.WARN, 'All date chunks processed. Moving to next step.');
            enqueueNextStep();
        }
    }

    private void fetchAdditionalSourceData(DC_MultiSourceData multiData, String sourceAlias, DC_JoinConfig config, List<Object> mainPage) {
        Set<String> joinKeys = new Set<String>();
        for (Object mainRec : mainPage) {
            Object keyVal;
            if (mainRec instanceof Map<String, Object>) {
                keyVal = ((Map<String, Object>)mainRec).get(config.parentField);
            } else if (mainRec instanceof SObject) {
                keyVal = ((SObject)mainRec).get(config.parentField);
            }
            if (keyVal != null) {
                joinKeys.add(String.valueOf(keyVal));
            }
        }

        if (joinKeys.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No join keys found for additional source: ' + sourceAlias);
            return;
        }

        Boolean isDataCloudSource = config.sourceObject.contains('__dlm') || config.sourceObject.startsWith('ssot__');
        
        List<SObject> additionalRecs;
        
        if (isDataCloudSource) {
            additionalRecs = queryAdditionalDataCloudSource(config, joinKeys);
        } else {
            additionalRecs = queryAdditionalRegularSource(config, joinKeys);
        }

        System.debug(LoggingLevel.WARN, 'Fetched additional rows for ' + sourceAlias + ': ' + additionalRecs.size());

        for (SObject addRec : additionalRecs) {
            String keyValue = String.valueOf(addRec.get(config.joinField));
            List<SObject> existing = multiData.getAdditionalData(sourceAlias, keyValue);
            if (existing.isEmpty()) {
                existing = new List<SObject>();
            }
            existing.add(addRec);
            multiData.addAdditionalData(sourceAlias, keyValue, existing);
        }
    }

    private List<SObject> queryAdditionalDataCloudSource(DC_JoinConfig config, Set<String> joinKeys) {
        String additionalSelectList = String.join(new List<String>(config.sourceFields), ',');
        if (!config.sourceFields.contains(config.joinField)) {
            additionalSelectList += ', ' + config.joinField;
        }

        String whereClause = config.joinField + ' IN (\'' + String.join(new List<String>(joinKeys), '\', \'') + '\')';
        if (!String.isBlank(config.whereClause)) {
            whereClause += ' AND ' + config.whereClause;
        }

        String sql = 'SELECT ' + additionalSelectList + ' FROM ' + config.sourceObject + 
                    ' WHERE ' + whereClause;

        System.debug(LoggingLevel.WARN, 'Additional CDP SQL for ' + config.sourceObject + ': ' + sql);

        try {
            List<Map<String, Object>> mapResults = DC_CdpQueryUtil.executeQuery(sql);
            List<SObject> results = new List<SObject>();
            for (Map<String, Object> mapRec : mapResults) {
                Account wrapper = new Account();
                results.add(wrapper);
            }
            return results;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching additional CDP data: ' + e.getMessage());
            return new List<SObject>();
        }
    }

    private List<SObject> queryAdditionalRegularSource(DC_JoinConfig config, Set<String> joinKeys) {
        String additionalSelectList = String.join(new List<String>(config.sourceFields), ',');
        if (!config.sourceFields.contains(config.joinField)) {
            additionalSelectList += ', ' + config.joinField;
        }

        String additionalSoql = 'SELECT ' + additionalSelectList + ' FROM ' + config.sourceObject;
        
        List<String> additionalPredicates = new List<String>();
        additionalPredicates.add(config.joinField + ' IN :joinKeys');
        if (!String.isBlank(config.whereClause)) {
            additionalPredicates.add(config.whereClause);
        }
        
        additionalSoql += ' WHERE ' + String.join(additionalPredicates, ' AND ');

        System.debug(LoggingLevel.WARN, 'Additional SOQL: ' + additionalSoql);

        try {
            return Database.query(additionalSoql);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching additional SOQL data: ' + e.getMessage());
            return new List<SObject>();
        }
    }

    private void processUpsertAndContinue(DC_IStep step, String stepName, List<Object> page, DC_UpsertBundle bundle, Boolean isDataCloudObject) {
        if (bundle != null && (!bundle.records.isEmpty() || !bundle.recordsToUpdate.isEmpty())) {
            System.debug(LoggingLevel.WARN, 'Processing records for step: ' + stepName);
            System.debug(LoggingLevel.WARN, '  Records to INSERT: ' + bundle.records.size());
            System.debug(LoggingLevel.WARN, '  Records to UPDATE: ' + bundle.recordsToUpdate.size());
            
            try {
                List<Database.UpsertResult> allResults = new List<Database.UpsertResult>();
                
                // UPDATE records that have Salesforce Id
                if (!bundle.recordsToUpdate.isEmpty()) {
                    System.debug(LoggingLevel.WARN, 'Updating ' + bundle.recordsToUpdate.size() + ' existing records');
                    Database.SaveResult[] updateResults = Database.update(bundle.recordsToUpdate, false);
                    
                    for (Database.SaveResult sr : updateResults) {
                        if (sr.isSuccess()) {
                            System.debug(LoggingLevel.INFO, '[UPDATE SUCCESS] Id: ' + sr.getId());
                        } else {
                            for (Database.Error err : sr.getErrors()) {
                                System.debug(LoggingLevel.ERROR, '[UPDATE FAILED] Id: ' + sr.getId() + 
                                            ', Error: ' + err.getMessage());
                            }
                        }
                    }
                }
                
                // INSERT/UPSERT records without Salesforce Id
                if (!bundle.records.isEmpty()) {
                    System.debug(LoggingLevel.WARN, 'Upserting ' + bundle.records.size() + ' new/existing records by external ID');
                    Database.UpsertResult[] upsertResults = 
                        DC_DmlUtil.upsertByExtId(bundle.records, bundle.externalIdField, false);
                    
                    allResults.addAll(upsertResults);
                    DC_LogUtil.logResults(bundle, upsertResults);
                }
                
                step.afterUpsert(page, bundle, allResults);
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error during DML for step ' + stepName + ': ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
        }

        // Continue with pagination logic
        if (page.size() == pageSize) {
            if (isDataCloudObject) {
                Integer newOffset = offsetValue + pageSize;
                
                if (newOffset >= MAX_CDP_OFFSET) {
                    System.debug(LoggingLevel.WARN, 'Approaching CDP OFFSET limit. Moving to next date chunk.');
                    processNextDateChunk(step, stepName);
                } else {
                    System.debug(LoggingLevel.WARN, 'Page filled up, enqueuing SAME step again with offset=' + newOffset);
                    System.enqueueJob(new DC_StepRunner(stepNames, index, null, pageSize, newOffset, chunkStartDate, chunkEndDate, false));
                }
            } else {
                String newLastKey = null;
                if (!page.isEmpty()) {
                    Object lastRec = page[page.size() - 1];
                    Object keyVal;
                    if (lastRec instanceof Map<String, Object>) {
                        keyVal = ((Map<String, Object>)lastRec).get(step.orderBySourceField());
                    } else if (lastRec instanceof SObject) {
                        keyVal = ((SObject)lastRec).get(step.orderBySourceField());
                    }
                    if (keyVal != null) {
                        newLastKey = String.valueOf(keyVal);
                    }
                }
                if (!String.isBlank(newLastKey)) {
                    System.debug(LoggingLevel.WARN, 'Page filled up, enqueuing SAME step again with lastKey=' + newLastKey);
                    System.enqueueJob(new DC_StepRunner(stepNames, index, newLastKey, pageSize, 0, null, null, false));
                } else {
                    enqueueNextStep();
                }
            }
        } else {
            if (isDataCloudObject && chunkEndDate != null && chunkEndDate < Date.today()) {
                processNextDateChunk(step, stepName);
            } else {
                System.debug(LoggingLevel.WARN, 'Step complete, moving to NEXT step.');
                enqueueNextStep();
            }
        }
    }

    /**
     * **UPDATED: Modified to check if second pass is needed before moving to next step**
     */
    private void enqueueNextStep() {
        Integer next = (index == null) ? null : index + 1;
        System.debug(LoggingLevel.WARN, 'enqueueNextStep called. Next index: ' + next + ', Total steps: ' + stepNames.size());
        
        // **NEW: Check if current step needs a second pass**
        if (!isSecondPass && index != null && index < stepNames.size()) {
            String currentStepName = stepNames[index];
            if (needsSecondPass(currentStepName)) {
                System.debug(LoggingLevel.WARN, 'Step ' + currentStepName + ' requires second pass. Enqueuing second pass job.');
                System.enqueueJob(new DC_StepRunner(
                    stepNames,
                    index, // **SAME index - run same step again**
                    null,
                    (DC_Debug.ENABLE && DC_Debug.MAX_ROWS > 0) ? DC_Debug.MAX_ROWS : DEFAULT_PAGE_SIZE,
                    0,
                    null,
                    null,
                    true // **isSecondPass = true**
                ));
                return; // **Don't move to next step yet**
            }
        }
        
        // Move to next step
        if (next != null && next < stepNames.size()) {
            System.debug(LoggingLevel.WARN, 'Enqueuing StepStarter for step index ' + next + ' (' + stepNames[next] + ')');
            System.enqueueJob(new DC_Orchestrator.StepStarter(
                stepNames,
                next,
                (DC_Debug.ENABLE && DC_Debug.MAX_ROWS > 0) ? DC_Debug.MAX_ROWS : DEFAULT_PAGE_SIZE
            ));
        } else {
            System.debug(LoggingLevel.WARN, 'No further steps available to enqueue. ALL STEPS COMPLETE.');
        }
    }

    /**
     * **NEW METHOD: Determine if a step needs a second pass**
     */
    private Boolean needsSecondPass(String stepName) {
        try {
            List<DataSync_ObjectOrder__mdt> config = [
                SELECT Run_Second_Pass__c
                FROM DataSync_ObjectOrder__mdt
                WHERE StepName__c = :stepName
                AND Active__c = true
                LIMIT 1
            ];
            
            if (!config.isEmpty() && config[0].Run_Second_Pass__c != null) {
                return config[0].Run_Second_Pass__c;
            }
        } catch (Exception e) {
            System.debug('Could not read Run_Second_Pass__c from metadata: ' + e.getMessage());
        }
        
        return false; // Default to no second pass
    }
}
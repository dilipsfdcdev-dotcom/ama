public with sharing class DC_StepRunner implements Queueable, Database.AllowsCallouts {

    private final List<String> stepNames;
    private final Integer index;
    private final String lastKey;
    private final Integer pageSize;
    private final Integer offsetValue;
    private final Date chunkStartDate;
    private final Date chunkEndDate;

    public static final Integer DEFAULT_PAGE_SIZE = 200;
    public static final Integer MAX_CDP_OFFSET = 50000; // CDP has higher limits

    // Constructor for cursor-based pagination (backward compatibility)
    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize) {
        this(stepNames, index, lastKey, pageSize, 0, null, null);
    }

    // Constructor with offset support
    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize, Integer offsetValue) {
        this(stepNames, index, lastKey, pageSize, offsetValue, null, null);
    }

    // Full constructor with date chunking support
    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize, 
                        Integer offsetValue, Date chunkStartDate, Date chunkEndDate) {
        this.stepNames = stepNames;
        this.index = index;
        this.lastKey = lastKey;
        this.pageSize = (pageSize != null && pageSize > 0) ? pageSize :
                         (DC_Debug.ENABLE && DC_Debug.MAX_ROWS > 0 ? DC_Debug.MAX_ROWS : DEFAULT_PAGE_SIZE);
        this.offsetValue = offsetValue != null ? offsetValue : 0;
        this.chunkStartDate = chunkStartDate;
        this.chunkEndDate = chunkEndDate;
    }

    public void execute(QueueableContext qc) {
        System.debug(LoggingLevel.WARN, '=== DC_StepRunner START ===');
        System.debug(LoggingLevel.WARN, 'Step Index: ' + index + ', StepNames: ' + stepNames + 
                    ', lastKey: ' + lastKey + ', offset: ' + offsetValue + 
                    ', chunkStart: ' + chunkStartDate + ', chunkEnd: ' + chunkEndDate);

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

        // Check if this is a multi-source step
        Map<String, DC_JoinConfig> additionalSources = step.getAdditionalSources();
        
        if (additionalSources != null && !additionalSources.isEmpty()) {
            processMultiSourceStep(step, stepName);
        } else {
            processSingleSourceStep(step, stepName);
        }
    }

    private void processSingleSourceStep(DC_IStep step, String stepName) {
        Set<String> srcFields = step.sourceFields();
        String srcObject = step.sourceObjectApi();
        String orderField = step.orderBySourceField();

        // Determine if this is a Data Cloud object
        Boolean isDataCloudObject = srcObject.contains('__dlm') || srcObject.startsWith('ssot__');
        
        List<SObject> page;
        
        if (isDataCloudObject) {
            // Use CDP Query for Data Cloud objects
            page = queryDataCloudObject(step, stepName, srcFields, srcObject, orderField);
        } else {
            // Use regular SOQL for Salesforce objects
            page = queryRegularSalesforceObject(step, stepName, srcFields, srcObject, orderField);
        }

        System.debug(LoggingLevel.WARN, 'Fetched rows: ' + page.size());

        if (page.isEmpty()) {
            if (isDataCloudObject && chunkEndDate != null && chunkEndDate < Date.today()) {
                // Move to next date chunk
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

    private List<SObject> queryDataCloudObject(DC_IStep step, String stepName, Set<String> srcFields, 
                                              String srcObject, String orderField) {
        String whereClause = '';
        
        if (step instanceof DC_IWhere) {
            String wc = ((DC_IWhere)step).whereClause();
            if (!String.isBlank(wc)) {
                if (chunkStartDate != null || chunkEndDate != null) {
                    // Replace date filter with chunk-specific date filter
                    wc = replaceDateFilterWithChunk(wc, chunkStartDate, chunkEndDate, stepName);
                }
                whereClause = wc;
            }
        }
        
        // Build CDP SQL query
        String sql = DC_CdpQueryUtil.buildDataCloudSql(
            srcObject, 
            srcFields, 
            whereClause, 
            orderField, 
            pageSize, 
            offsetValue
        );
        
        // Execute CDP query
        List<Map<String, Object>> mapResults = DC_CdpQueryUtil.executeQuery(sql);
        
        // Convert to SObjects for compatibility with existing code
        return DC_CdpQueryUtil.convertToSObjects(mapResults, 'Account');
    }

    private List<SObject> queryRegularSalesforceObject(DC_IStep step, String stepName, Set<String> srcFields, 
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
        
        // For regular Salesforce objects, use cursor-based pagination
        if (!String.isBlank(lastKey)) {
            predicates.add(orderField + ' > \'' + String.escapeSingleQuotes(lastKey) + '\'');
        }
        
        if (!predicates.isEmpty()) {
            soql += ' WHERE ' + String.join(predicates, ' AND ');
        }
        
        soql += ' ORDER BY ' + orderField + ' ASC';
        soql += ' LIMIT ' + pageSize;

        System.debug(LoggingLevel.WARN, 'SOQL to execute: ' + soql);
        return Database.query(soql);
    }

    private void processMultiSourceStep(DC_IStep step, String stepName) {
        Set<String> srcFields = step.sourceFields();
        String srcObject = step.sourceObjectApi();
        String orderField = step.orderBySourceField();

        Boolean isDataCloudObject = srcObject.contains('__dlm') || srcObject.startsWith('ssot__');
        
        List<SObject> mainPage;
        
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
                System.debug(LoggingLevel.WARN, 'No rows found for step: ' + stepName + '. Moving to next step.');
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
        // Replace date filter patterns with chunk-specific dates
        String modifiedWhere = originalWhere;
        
        if (startDate != null && endDate != null) {
            DC_IStep step = DC_StepFactory.make(stepName);
            String lastModifiedField = 'ssot__LastModifiedDate__c'; // default
            if (step != null) {
                String sourceObject = step.sourceObjectApi();
                lastModifiedField = DC_DateUtil.getLastModifiedFieldName(sourceObject);
            }
            
            // Format dates for CDP SQL - use standard date format
            DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0));
            String formattedStartDate = startDateTime.formatGmt('yyyy-MM-dd');
            String formattedEndDate = endDateTime.formatGmt('yyyy-MM-dd');
            
            // Replace LAST_N_DAYS with specific date range
            String dateRangeFilter = '>= \'' + formattedStartDate + '\' AND ' + 
                                   lastModifiedField + ' <= \'' + formattedEndDate + '\'';
            
            modifiedWhere = modifiedWhere.replaceAll('= LAST_N_DAYS:\\d+', dateRangeFilter);
            modifiedWhere = modifiedWhere.replaceAll('= TODAY', dateRangeFilter);
        }
        
        return modifiedWhere;
    }

    private void processNextDateChunk(DC_IStep step, String stepName) {
        // Calculate next date chunk
        Date newStartDate = chunkEndDate.addDays(1);
        Date proposedEndDate = newStartDate.addDays(6); // 7-day chunks
        Date newEndDate = proposedEndDate > Date.today() ? Date.today() : proposedEndDate;
        
        if (newStartDate <= Date.today()) {
            System.debug(LoggingLevel.WARN, 'Moving to next date chunk: ' + newStartDate + ' to ' + newEndDate);
            System.enqueueJob(new DC_StepRunner(stepNames, index, null, pageSize, 0, newStartDate, newEndDate));
        } else {
            System.debug(LoggingLevel.WARN, 'All date chunks processed. Moving to next step.');
            enqueueNextStep();
        }
    }

    private void fetchAdditionalSourceData(DC_MultiSourceData multiData, String sourceAlias, DC_JoinConfig config, List<SObject> mainPage) {
        Set<String> joinKeys = new Set<String>();
        for (SObject mainRec : mainPage) {
            Object keyVal = mainRec.get(config.parentField);
            if (keyVal != null) {
                joinKeys.add(String.valueOf(keyVal));
            }
        }

        if (joinKeys.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No join keys found for additional source: ' + sourceAlias);
            return;
        }

        // Check if additional source is Data Cloud object
        Boolean isDataCloudSource = config.sourceObject.contains('__dlm') || config.sourceObject.startsWith('ssot__');
        
        List<SObject> additionalRecs;
        
        if (isDataCloudSource) {
            // Use CDP query for Data Cloud additional sources
            additionalRecs = queryAdditionalDataCloudSource(config, joinKeys);
        } else {
            // Use regular SOQL for Salesforce additional sources
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

        // Build WHERE clause for CDP
        String whereClause = config.joinField + ' IN (\'' + String.join(new List<String>(joinKeys), '\', \'') + '\')';
        if (!String.isBlank(config.whereClause)) {
            whereClause += ' AND ' + config.whereClause;
        }

        String sql = 'SELECT ' + additionalSelectList + ' FROM ' + config.sourceObject + 
                    ' WHERE ' + whereClause;

        System.debug(LoggingLevel.WARN, 'Additional CDP SQL for ' + config.sourceObject + ': ' + sql);

        try {
            List<Map<String, Object>> mapResults = DC_CdpQueryUtil.executeQuery(sql);
            return DC_CdpQueryUtil.convertToSObjects(mapResults, 'Account');
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

    private void processUpsertAndContinue(DC_IStep step, String stepName, List<SObject> page, DC_UpsertBundle bundle, Boolean isDataCloudObject) {
        if (bundle != null && !bundle.records.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'Upserting ' + bundle.records.size() + ' records for step: ' + stepName);
            try {
                Database.UpsertResult[] results =
                    DC_DmlUtil.upsertByExtId(bundle.records, bundle.externalIdField, false);
                DC_LogUtil.logResults(bundle, results);
                step.afterUpsert(page, bundle, results);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error during upsert for step ' + stepName + ': ' + e.getMessage());
            }
        }

        // Continue pagination if page is full
        if (page.size() == pageSize) {
            if (isDataCloudObject) {
                Integer newOffset = offsetValue + pageSize;
                
                // CDP has higher limits, but still check for reasonable bounds
                if (newOffset >= MAX_CDP_OFFSET) {
                    System.debug(LoggingLevel.WARN, 'Approaching CDP OFFSET limit. Moving to next date chunk.');
                    processNextDateChunk(step, stepName);
                } else {
                    System.debug(LoggingLevel.WARN, 'Page filled up, enqueuing SAME step again with offset=' + newOffset);
                    System.enqueueJob(new DC_StepRunner(stepNames, index, null, pageSize, newOffset, chunkStartDate, chunkEndDate));
                }
            } else {
                // Regular Salesforce object pagination
                String newLastKey = null;
                if (!page.isEmpty()) {
                    Object keyVal = page[page.size() - 1].get(step.orderBySourceField());
                    if (keyVal != null) {
                        newLastKey = String.valueOf(keyVal);
                    }
                }
                if (!String.isBlank(newLastKey)) {
                    System.debug(LoggingLevel.WARN, 'Page filled up, enqueuing SAME step again with lastKey=' + newLastKey);
                    System.enqueueJob(new DC_StepRunner(stepNames, index, newLastKey, pageSize, 0, null, null));
                } else {
                    enqueueNextStep();
                }
            }
        } else {
            if (isDataCloudObject && chunkEndDate != null && chunkEndDate < Date.today()) {
                // Current chunk is done, move to next chunk
                processNextDateChunk(step, stepName);
            } else {
                System.debug(LoggingLevel.WARN, 'Step complete, moving to NEXT step.');
                enqueueNextStep();
            }
        }
    }

    private void enqueueNextStep() {
        Integer next = (index == null) ? null : index + 1;
        System.debug(LoggingLevel.WARN, 'enqueueNextStep called. Next index: ' + next + ', Total steps: ' + stepNames.size());
        if (next != null && next < stepNames.size()) {
            System.debug(LoggingLevel.WARN, 'Enqueuing StepStarter for step index ' + next + ' (' + stepNames[next] + ')');
            System.enqueueJob(new DC_Orchestrator.StepStarter(
                stepNames,
                next,
                (DC_Debug.ENABLE && DC_Debug.MAX_ROWS > 0) ? DC_Debug.MAX_ROWS : DEFAULT_PAGE_SIZE
            ));
        } else {
            System.debug(LoggingLevel.WARN, 'No further steps available to enqueue.');
        }
    }
}
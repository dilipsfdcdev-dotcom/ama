public with sharing class DC_StepRunner implements Queueable, Database.AllowsCallouts {

    private final List<String> stepNames;
    private final Integer index;
    private final String lastKey;
    private final Integer pageSize;

    public static final Integer DEFAULT_PAGE_SIZE = 200;

    public DC_StepRunner(List<String> stepNames, Integer index, String lastKey, Integer pageSize) {
        this.stepNames = stepNames;
        this.index     = index;
        this.lastKey   = lastKey;
        this.pageSize  = (pageSize != null && pageSize > 0) ? pageSize :
                         (DC_Debug.ENABLE && DC_Debug.MAX_ROWS > 0 ? DC_Debug.MAX_ROWS : DEFAULT_PAGE_SIZE);
    }

    public void execute(QueueableContext qc) {
        System.debug(LoggingLevel.WARN, '=== DC_StepRunner START ===');
        System.debug(LoggingLevel.WARN, 'Step Index: ' + index + ', StepNames: ' + stepNames + ', lastKey: ' + lastKey);

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

        Set<String> srcFields = step.sourceFields();
        String selectList = String.join(new List<String>(srcFields), ',');
        String srcObject  = step.sourceObjectApi();
        String orderField = step.orderBySourceField();

        String soql = 'SELECT ' + selectList + ' FROM ' + srcObject;

        List<String> predicates = new List<String>();
        if (step instanceof DC_IWhere) {
            String wc = ((DC_IWhere)step).whereClause();
            if (!String.isBlank(wc)) predicates.add(wc);
        }
        if (lastKey != null) {
            predicates.add(orderField + ' > :lastKey');
        }
        if (!predicates.isEmpty()) {
            soql += ' WHERE ' + String.join(predicates, ' AND ');
        }
        soql += ' ORDER BY ' + orderField + ' ASC';
        soql += ' LIMIT ' + pageSize;

        System.debug(LoggingLevel.WARN, 'SOQL to execute: ' + soql);

        List<SObject> page = Database.query(soql);
        System.debug(LoggingLevel.WARN, 'Fetched rows: ' + page.size());

        if (page.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No rows found for step: ' + stepName + '. Moving to next step.');
            enqueueNextStep();
            return;
        }

        DC_UpsertBundle bundle = step.mapScope(page);
        if (bundle != null && !bundle.records.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'Upserting ' + bundle.records.size() + ' records for step: ' + stepName);
            Database.UpsertResult[] results =
                DC_DmlUtil.upsertByExtId(bundle.records, bundle.externalIdField, false);
            DC_LogUtil.logResults(bundle, results);
            step.afterUpsert(page, bundle, results);
        }

        String newLastKey = null;
        Object keyVal = page[page.size() - 1].get(orderField);
        if (keyVal != null) newLastKey = String.valueOf(keyVal);

        if (page.size() == pageSize && newLastKey != null) {
            System.debug(LoggingLevel.WARN, 'Page filled up, enqueuing SAME step again with lastKey=' + newLastKey);
            System.enqueueJob(new DC_StepRunner(stepNames, index, newLastKey, pageSize));
        } else {
            System.debug(LoggingLevel.WARN, 'Step complete, moving to NEXT step.');
            enqueueNextStep();
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

@IsTest
private class TaskTriggerHandlerTest {

    // -- Utility: ensure we have a Case RecordType with DeveloperName = 'PRC'
    // Tries to create one tied to a SupportProcess; if it already exists, it queries it.
    private static Id ensurePRCRecordTypeId() {
        RecordType rt = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Case' AND DeveloperName = 'PRC'
            LIMIT 1
        ];
        return rt.Id;
    }

    @TestSetup
    static void setupData() {
        // Create a Contact that the Lead will reference via Converted_Contact__c
        Contact c = new Contact(LastName = 'Test Contact');
        insert c;

        // We need a PRC Case RecordType present in org (per your handler logic).
        // If your org already has it (common), great; otherwise, consider adding
        // a one-time PRC record type in the org setup. (Creating SupportProcess
        // and a new RecordType in tests can be brittle across orgs.)
        Id prcRtId = ensurePRCRecordTypeId();

        // Create a PRC Case
        Case prcCase = new Case(
            Subject = 'PRC Case',
            Origin  = 'Phone',
            Status  = 'New',
            Last_Name__c = 'Mapped Lead',
            RecordTypeId = prcRtId
        );
        insert prcCase;

        // Lead mapped to the PRC Case, with Converted_Contact__c populated
        // NOTE: Case_ID__c and Converted_Contact__c must exist in your org (as in your code).
        Lead l1 = new Lead(
            LastName = 'Mapped Lead',
            Company  = 'Acme',
            Case_ID__c = prcCase.Id,              // custom field from your org
            Converted_Contact__c = c.Id           // custom lookup from your org
        );
        insert l1;

        // Create a NON-PRC Case (use the Master/Default RT)
        Case nonPrcCase = new Case(
            Subject = 'Non PRC Case',
            Origin  = 'Phone',
            Status  = 'New',
            Last_Name__c = 'Mapped Lead 1'
            // RecordTypeId omitted → default/master (non-PRC)
        );
        insert nonPrcCase;

        // Lead for the NON-PRC case as a control (even if mapped, should not attach due to RT)
        Lead l2 = new Lead(
            LastName = 'Other Lead',
            Company  = 'Beta',
            Case_ID__c = nonPrcCase.Id,
            Converted_Contact__c = c.Id
        );
        insert l2;

        // Seed a few tasks in 'Open' status; we will update to 'Completed' in tests
        // 1) Candidate: PRC case → should link WhoId to Contact
        Task t1 = new Task(
            Subject = 'Follow up PRC',
            Status  = 'Open',
            WhatId  = prcCase.Id
        );
        // 2) Control: NON-PRC case → should NOT link
        Task t2 = new Task(
            Subject = 'Follow up Non-PRC',
            Status  = 'Open',
            WhatId  = nonPrcCase.Id
        );
        // 3) Control: Not a Case at all (no WhatId) → should NOT link
        Task t3 = new Task(
            Subject = 'No WhatId',
            Status  = 'Open'
        );
        insert new List<Task>{ t1, t2, t3 };
    }

    @IsTest
    static void test_OpenToCompleted_On_PRC_Case_LinksWhoId() {
        // Arrange
        Task t1 = [SELECT Id, Status, WhoId, WhatId FROM Task WHERE Subject = 'Follow up PRC' LIMIT 1];
        System.assertEquals('Open', t1.Status, 'Precondition: t1 should start as Open');

        // Act: bulk style update (include controls)
        List<Task> toUpd = [
            SELECT Id, Status, Subject, WhatId, WhoId
            FROM Task
            WHERE Subject IN ('Follow up PRC', 'Follow up Non-PRC', 'No WhatId')
        ];
        for (Task t : toUpd) {
            // Move all three to Completed; only PRC+Case should be processed
            t.Status = 'Completed';
        }
        Test.startTest();
        update toUpd;
        Test.stopTest();

        // Assert
        // Reload
        Map<String, Task> bySubject = new Map<String, Task>();
        for (Task t : [
            SELECT Id, Status, Subject, WhatId, WhoId
            FROM Task
            WHERE Id IN :toUpd
        ]) {
            bySubject.put(t.Subject, t);
        }
    }

    @IsTest
    static void test_NoStatusTransition_NoLinking() {
        // Arrange: keep status as Open → update a description only
        Task t = [SELECT Id, Status, Subject, WhatId, WhoId FROM Task WHERE Subject = 'Follow up PRC' LIMIT 1];
        System.assertEquals('Open', t.Status);

        // Act: update field other than Status so transition Open→Completed does not occur
        t.Subject = 'Follow up PRC (edited only)';
        Test.startTest();
        update t;
        Test.stopTest();

        // Assert: WhoId should remain null (no status transition)
        Task reloaded = [SELECT Id, Status, Subject, WhatId, WhoId FROM Task WHERE Id = :t.Id];
        System.assertEquals(null, reloaded.WhoId, 'No Open→Completed transition: should not link');
    }

    @IsTest
    static void test_Ignores_When_No_Lead_Mapping() {
        // Create another PRC case with no Lead mapping
        Id prcRtId = ensurePRCRecordTypeId();
        Case prcNoLead = new Case(Subject='PRC no lead', Origin='Phone', Status='New', Last_Name__c = 'Mapped Lead 2',RecordTypeId=prcRtId);
        insert prcNoLead;

        Task t = new Task(Subject='PRC no lead task', Status='Open', WhatId=prcNoLead.Id);
        insert t;

        // Update to Completed
        t.Status = 'Completed';
        Test.startTest();
        update t;
        Test.stopTest();
    }
}
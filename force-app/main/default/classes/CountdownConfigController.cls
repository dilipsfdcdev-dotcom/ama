public with sharing class CountdownConfigController {

    public class Response {
        @AuraEnabled public Boolean hasConfig;
        @AuraEnabled public Boolean timerEnabled;
        @AuraEnabled public Datetime startTime;
        @AuraEnabled public Integer durationSeconds;
        @AuraEnabled public String message;
        @AuraEnabled public String expiredMessage;
        @AuraEnabled public Datetime serverNowUtc;
        @AuraEnabled public Datetime expireAtUtc;
        @AuraEnabled public Boolean stopNow; // true if stop condition matched (StageName == 'Attempting Contact')
    }

    // We poll from LWC; caching would return stale values
    @AuraEnabled(cacheable=false)
    public static Response getCountdownInfo(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('recordId is required');
        }

        Schema.SObjectType sType = recordId.getSObjectType();
        String objectApiName = sType.getDescribe().getName();

        Countdown_Config__mdt cfg = [
            SELECT Is_Active__c,
                   Object_API_Name__c,
                   Enable_Field__c,
                   Start_Time_Field__c,
                   Duration_Seconds__c,
                   Message__c,
                   Expired_Message__c,
                   Stop_Timer_Field__c
            FROM Countdown_Config__mdt
            WHERE Is_Active__c = true
              AND Object_API_Name__c = :objectApiName
            LIMIT 1
        ];

        Response res = new Response();
        res.serverNowUtc = System.now();

        if (cfg == null) {
            res.hasConfig = false;
            res.timerEnabled = false;
            res.durationSeconds = 0;
            res.stopNow = false;
            return res;
        }
        res.hasConfig = true;

        if (String.isBlank(cfg.Enable_Field__c) || String.isBlank(cfg.Start_Time_Field__c)) {
            throw new AuraHandledException('Countdown_Config__mdt missing Enable_Field__c or Start_Time_Field__c.');
        }

        String enableField    = cfg.Enable_Field__c.trim();
        String startTimeField = cfg.Start_Time_Field__c.trim();
        String stopField      = String.isBlank(cfg.Stop_Timer_Field__c) ? null : cfg.Stop_Timer_Field__c.trim();

        if (enableField.contains(',') || startTimeField.contains(',') || (stopField != null && stopField.contains(','))) {
            throw new AuraHandledException('Invalid field API names in Countdown_Config__mdt.');
        }

        // Build SOQL dynamically with optional stop field
        String soql =
            'SELECT ' + enableField + ', ' + startTimeField +
            (stopField != null ? (', ' + stopField) : '') +
            ' FROM ' + objectApiName + ' WHERE Id = :recordId';

        SObject rec = Database.query(soql);

        Object enableVal = rec.get(enableField);
        Object startVal  = rec.get(startTimeField);
        Object stopVal   = (stopField != null) ? rec.get(stopField) : null;

        Boolean timerEnabled = (enableVal instanceof Boolean) ? (Boolean) enableVal : false;
        Datetime startTime   = (startVal instanceof Datetime) ? (Datetime) startVal : null;

        res.timerEnabled    = timerEnabled;
        res.startTime       = startTime;
        res.durationSeconds = (cfg.Duration_Seconds__c == null ? 0 : Integer.valueOf(cfg.Duration_Seconds__c));
        res.message         = cfg.Message__c;
        res.expiredMessage  = cfg.Expired_Message__c;

        if (startTime != null && res.durationSeconds > 0) {
            res.expireAtUtc = startTime.addSeconds(res.durationSeconds);
        }

        // Stop condition:
        // You configured Stop_Timer_Field__c = 'StageName' (Opportunity).
        // We stop when the current value equals 'Attempting Contact'.
        if (stopField != null && stopVal != null) {
            String stopStr = String.valueOf(stopVal);
            // be safe on spaces/case
            String normalized = stopStr == null ? '' : stopStr.trim().toLowerCase();
        
            // add any additional stopping stages here
            Set<String> stopMatches = new Set<String>{ 'attempting contact', 'in contact' };
        
            res.stopNow = stopMatches.contains(normalized);
        } else {
            res.stopNow = false;
        }

        return res;
    }

     @AuraEnabled(cacheable=true)
    public static List<Id> getLeadIdsByConvertedOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            return new List<Id>();
        }

        List<Lead> leads = [
            SELECT Id
            FROM Lead
            WHERE Converted_Opportunity__c = :opportunityId
        ];

        List<Id> leadIds = new List<Id>();
        for (Lead l : leads) {
            leadIds.add(l.Id);
        }
        return leadIds;
    }
}

/*Id oppId = 'PUT_OPPORTUNITY_ID_HERE';
Opportunity opp = new Opportunity(
    Id = oppId,
    Assignment_Timer_Start__c = true,
    Timer_Starttime__c = System.now()
);
update opp;
System.debug('Updated Opportunity to start timer now.'); */
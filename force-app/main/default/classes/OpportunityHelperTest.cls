@isTest
public with sharing class OpportunityHelperTest {
    
    public static testMethod void testOpportunityHelper() {

    	Account a = new Account(
            AccountNumber = '848452',
            Name = 'Test Account'
        );
        insert a;

        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = a.Id,
            Agent_ID__c ='TEST70904'
        );
        insert c;
               
        test.startTest();

        Opportunity o = new Opportunity(
            Name = 'Test Opp',
            CloseDate = Date.newInstance(2018, 03, 02),
            AccountId = a.Id,
            StageName = 'StageName',
            Agent_ID__c = 'TEST70904'
        );
        insert o;

        List<OpportunityContactRole> ocrs = [Select OpportunityId, ContactId From OpportunityContactRole Where OpportunityId = :o.Id AND ContactId = :c.Id];
       // System.assertEquals(1, ocrs.size(), 'The OpportunityContactRole was not inserted');

    
        Opportunity o2 = new Opportunity(
            Name = 'Test Opp2',
            CloseDate = Date.newInstance(2018, 03, 02),
            AccountId = a.Id,
            StageName = 'StageName',
            Agent_ID__c = '70904'
        );
        insert o2;

        List<OpportunityContactRole> opp = [Select OpportunityId, ContactId From OpportunityContactRole Where OpportunityId = :o2.Id];
        //System.assertEquals(0, opp.size());

        test.stopTest();

    }
    
}
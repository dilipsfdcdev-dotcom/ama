@isTest
public class Contact_UpdateOwnershipBatch_Test {
    
    @testVisible private static Id getAgencyRT() {
        return Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId(); 
    }
    
    @testVisible private static Id getConfirmedAgentRT() {
        return Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Confirmed Agent').getRecordTypeId();
    }
    
    static testMethod void testMethod1() 
    {      
        List<Account> accountList = new List<Account>();
        List<Contact> contactList = new List<Contact>();
        
        Account acc = new Account();
        acc.Name ='Test_Account';
        acc.Phone = '000000';
        acc.DistrictID__c = '123';
        acc.RecordTypeId = Contact_UpdateOwnershipBatch_Test.getAgencyRT();
        acc.Office_Code__c = 'Main';
        accountList.add(acc);
        
        Contact con = new Contact();
        con.AccountId = acc.Id;
        con.FirstName = 'FName';
        con.LastName = 'LName';
        con.MailingState = 'OH';
        con.RecordTypeId = Contact_UpdateOwnershipBatch_Test.getConfirmedAgentRT();
        con.Status__c = 'New';
        con.Total_of_Agent_Bookings__c = 5;
        contactList.add(con);
                
        Contact con1 = new Contact();
        con1.AccountId = acc.Id;
        con1.FirstName = 'FName';
        con1.LastName = 'LName';
        con1.MailingPostalCode = 'P9N';
        con1.RecordTypeId = Contact_UpdateOwnershipBatch_Test.getConfirmedAgentRT();
        con1.Status__c = 'New';
        contactList.add(con1);
		
		Contact con2 = new Contact();
        con2.AccountId = acc.Id;
        con2.FirstName = 'FName';
        con2.LastName = 'LName';
        con2.MailingPostalCode = '93201';
        con2.RecordTypeId = Contact_UpdateOwnershipBatch_Test.getConfirmedAgentRT();
        con2.Status__c = 'New';
        con2.Total_of_Agent_Bookings__c = 5;  
        contactList.add(con2);   
        
        Contact con3 = new Contact();
        con3.AccountId = acc.Id;
        con3.FirstName = 'FName';
        con3.LastName = 'LName';
        con3.RecordTypeId = Contact_UpdateOwnershipBatch_Test.getConfirmedAgentRT();
        con3.Status__c = 'New'; 
        con3.Total_of_Agent_Bookings__c = 5; 
        contactList.add(con3);   
                
        insert accountList;
        insert contactList;
                
        Test.startTest();  
        Contact_UpdateOwnershipBatch obj = new Contact_UpdateOwnershipBatch();
        DataBase.executeBatch(obj);   
        Test.stopTest();   

    }
}
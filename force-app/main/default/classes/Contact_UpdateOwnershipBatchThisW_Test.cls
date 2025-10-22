@isTest
public class Contact_UpdateOwnershipBatchThisW_Test {
    
    @testVisible private static Id getAgencyRT() {
        return Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId(); 
    }
    
    @testVisible private static Id getConfirmedAgentRT() {
        return Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Confirmed Agent').getRecordTypeId();
    }
    
    static testMethod void testMethod1() 
    {          
        Account acc = new Account();
        acc.Name ='Test_Account';
        acc.Phone = '000000';
        acc.DistrictID__c = '123';
        acc.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getAgencyRT();
        acc.Office_Code__c = 'Main';
        insert acc;
        
        Contact con = new Contact();
        con.AccountId = acc.Id;
        con.FirstName = 'FName';
        con.LastName = 'LName';
        con.MailingState = 'OH';
        con.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getConfirmedAgentRT();
        con.Status__c = 'New';
        con.Total_of_Agent_Bookings__c = 5;
        insert con;
                
        Test.startTest();  
        Contact_UpdateOwnershipBatchThisWeek obj = new Contact_UpdateOwnershipBatchThisWeek();
        DataBase.executeBatch(obj);   
        Test.stopTest(); 
    

    }
    
     
    
    static testMethod void testMethod3() 
    {        
        Id agencyRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId();
        
        Account acc = new Account();
        acc.Name ='Test_Account';
        acc.Phone = '000000';
        acc.DistrictID__c = '123';
        acc.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getAgencyRT();
        acc.Office_Code__c = 'Main';
        insert acc;
        
        Contact con = new Contact();
        con.AccountId = acc.Id;
        con.FirstName = 'FName';
        con.LastName = 'LName';
        con.MailingState = 'ON';
        con.MailingPostalCode = 'P9N';
        con.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getConfirmedAgentRT();
        con.Status__c = 'New';
        con.Total_of_Agent_Bookings__c = 5;
        insert con;
                
        Test.startTest();  
        Contact_UpdateOwnershipBatchThisWeek obj = new Contact_UpdateOwnershipBatchThisWeek();
        DataBase.executeBatch(obj);   
        Test.stopTest(); 
        
        Contact conRec = [SELECT Owner.Name, MailingState FROM Contact WHERE Id =: con.Id];  
      //  System.assertEquals('Teri Recunyk', conRec.Owner.Name);  

    }
    static testMethod void testMethod4() 
    {        
        Id agencyRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId();
        
        Account acc = new Account();
        acc.Name ='Test_Account';
        acc.Phone = '000000';
        acc.DistrictID__c = '123';
        acc.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getAgencyRT();
        acc.Office_Code__c = 'Main';
        insert acc;
        
        Contact con = new Contact();
        con.AccountId = acc.Id;
        con.FirstName = 'FName';
        con.LastName = 'LName';
        con.MailingState = 'ON';
        con.MailingPostalCode = 'L4G';
        con.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getConfirmedAgentRT();
        con.Status__c = 'New';
        con.Total_of_Agent_Bookings__c = 5;
        insert con;
                
        Test.startTest();  
        Contact_UpdateOwnershipBatchThisWeek obj = new Contact_UpdateOwnershipBatchThisWeek();
        DataBase.executeBatch(obj);   
        Test.stopTest(); 
        
        Contact conRec = [SELECT Owner.Name, MailingState FROM Contact WHERE Id =: con.Id];  
       // System.assertEquals('Neil Dudley', conRec.Owner.Name);  

    }
    static testMethod void testMethod5() 
    {        
        Id agencyRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId();
        
        Account acc = new Account();
        acc.Name ='Test_Account';
        acc.Phone = '000000';
        acc.DistrictID__c = '123';
        acc.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getAgencyRT();
        acc.Office_Code__c = 'Main';
        insert acc;
        
        Contact con = new Contact();
        con.AccountId = acc.Id;
        con.FirstName = 'FName';
        con.LastName = 'LName';
        con.RecordTypeId = Contact_UpdateOwnershipBatchThisW_Test.getConfirmedAgentRT();
        con.Status__c = 'New'; 
        con.Total_of_Agent_Bookings__c = 5;
        insert con;
                
        Test.startTest();  
        Contact_UpdateOwnershipBatchThisWeek obj = new Contact_UpdateOwnershipBatchThisWeek();
        DataBase.executeBatch(obj);   
        Test.stopTest(); 
        
        Contact conRec = [SELECT Owner.Name, MailingState FROM Contact WHERE Id =: con.Id];          
        Account accRec = [SELECT Owner.Name FROM Account WHERE Id =: acc.Id];  
        //System.assertEquals(accRec.Owner.Name, conRec.Owner.Name);   

    }
}
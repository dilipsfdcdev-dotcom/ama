public with sharing class DC_Mappings {

    // ---------- EXISTING MAPPINGS (unchanged) ----------
    // ssot__Account__dlm → Account
    public static final List<DC_FieldMap> ACCOUNT_MAP = new List<DC_FieldMap>{
        new DC_FieldMap('Address_City__c','BillingCity'),
        new DC_FieldMap('Country_Code__c','BillingCountry'),
        new DC_FieldMap('Zip_Code__c','BillingPostalCode'),
        new DC_FieldMap('State_Code__c','BillingState'),
        new DC_FieldMap('Address_Line1__c','BillingStreet'),
        new DC_FieldMap('Classification_Code__c','Classification_Code__c'),
        new DC_FieldMap('CLIA__c','CLIA__c'),
        new DC_FieldMap('Code__c','Code__c'),
        new DC_FieldMap('Currency__c','Currency__c'),
        new DC_FieldMap('District_ID__c','DistrictID__c'),
        new DC_FieldMap('ssot__ContactPointEmailId__c','Email__c'),
        new DC_FieldMap('IATA_Number__c','IATA__c'),
        new DC_FieldMap('ssot__Name__c','Name'),
        new DC_FieldMap('Office_Code__c','Office_Code__c'),
        new DC_FieldMap('Phone__c','Phone'),
        new DC_FieldMap('Region_ID__c','RegionID__c'),
        new DC_FieldMap('GCPS_Number__c','RESCO_AgencyID__c'),
        new DC_FieldMap('ssot__Id__c','SEAWARE_Agency_ID__c'),
        new DC_FieldMap('Secondary_Account_Name__c','Secondary_Account_Name__c'),
        new DC_FieldMap('Status__c','Status__c'),
        new DC_FieldMap('Parent_ID__c','Host_Account__c')
    };

    // Seaware_Commission_Structure__dlm → Commission_Structure__c
    public static final List<DC_FieldMap> COMMISSION_MAP = new List<DC_FieldMap>{
        new DC_FieldMap('Commission_Africa__c','Africa__c'),
        new DC_FieldMap('Agency_Classification_Code__c','Agency_Classification_Code__c'),
        new DC_FieldMap('Agency_Name__c','Agency_Name__c'),
        new DC_FieldMap('Agency_ID__c','AgencyID__c'),
        new DC_FieldMap('Commission_Air_Fare__c','Air_Fare__c'),
        new DC_FieldMap('Date_From__c','Classification_Date_From__c'),
        new DC_FieldMap('Date_To__c','Classification_Date_To__c'),
        new DC_FieldMap('Commission_Code__c','Commission_Code__c'),
        new DC_FieldMap('Commission_Code_ID__c','Commission_Code_Id__c'),
        new DC_FieldMap('Commission_Name__c','Commission_Name__c'),
        new DC_FieldMap('Commission_Type__c','Commission_Type__c'),
        new DC_FieldMap('Effective_From__c','Effective_From__c'),
        new DC_FieldMap('Effective_To__c','Effective_To__c'),
        new DC_FieldMap('Commission_Europe__c','Europe__c'),
        new DC_FieldMap('Commission_Hotel_Fare__c','Hotel_Fare__c'),
        new DC_FieldMap('Commission_Insurance__c','Insurance__c'),
        new DC_FieldMap('Commission_Intra_Air__c','Intra_Air__c'),
        new DC_FieldMap('Commission_Land__c','Land_Program__c'),
        new DC_FieldMap('Commission_Mekong__c','Mekong__c'),
        new DC_FieldMap('Commission_Myanmar__c','Myanmar__c'),
       //new DC_FieldMap('Commission_Structure_Name__c','Name'),
        new DC_FieldMap('Primary_Type__c','Primary_Type__c')
    };

    // ---------- ENHANCED CONTACT MAPPINGS WITH RELATIONSHIP HANDLING ----------

    // Contact (Agent) ← ssot__Individual__dlm + Contact Point Relationships
    public static final List<DC_FieldMap> CONTACT_AGENT_MAP = new List<DC_FieldMap>{
        // Main Individual fields
        new DC_FieldMap('Agency_ID__c','AgencyID__c'),
        new DC_FieldMap('Agent_ID__c','Agent_ID__c'),
        new DC_FieldMap('ssot__Id__c','Agent_ID__c'),
        new DC_FieldMap('ssot__PartyId__c','Agent_ID__c'),
        new DC_FieldMap('Allow_Web_Access__c','Allow_Web_Access__c'),
        new DC_FieldMap('Birthday__c','Birthdate'),
        new DC_FieldMap('Agent_Do_Not_Mail__c','HasOptedOutOfEmail'),
        new DC_FieldMap('ssot__FirstName__c','FirstName'),
        new DC_FieldMap('IATA__c','IATA__c'),
        new DC_FieldMap('IATAN_Company_Name__c','IATAN_Company_Name__c'),
        new DC_FieldMap('IATAN_Holder_Name__c','IATAN_Holder_Name__c'),
        new DC_FieldMap('ssot__LastName__c','LastName'),
        new DC_FieldMap('ssot__MiddleName__c','MiddleName'),
        new DC_FieldMap('ssot__PersonName__c','Name'),
        new DC_FieldMap('Status__c','Status__c'),
        new DC_FieldMap('Sex__c','Gender__c'),
        new DC_FieldMap('Web_Login_Name__c','Web_Login_Name__c'),
        new DC_FieldMap('AmaAcademy_Graduate__c','AmaAcademy_Graduate__c'),
        new DC_FieldMap('AmaAcademy_Course_Level__c','AmaAcademy_Course_Level__c'),
        
        // Contact Point Email fields (from ssot__rel_1697761162380_end__r)
        new DC_FieldMap('EMAIL:ssot__EmailAddress__c','Email'),
        
        // Contact Point Phone fields (from ssot__rel_1697761164176_end__r)
        new DC_FieldMap('PHONE:ssot__FormattedE164PhoneNumber__c','Phone'),
        new DC_FieldMap('PHONE:ssot__ExtensionNumber__c','Extension__c'),
        
        // Contact Point Address fields (from ssot__rel_1697761159567_end__r)
        new DC_FieldMap('ADDRESS:ssot__AddressLine1__c','MailingStreet'),
        new DC_FieldMap('ADDRESS:ssot__CityId__c','MailingCity'),
        new DC_FieldMap('ADDRESS:ssot__StateProvinceId__c','MailingState'),
        new DC_FieldMap('ADDRESS:ssot__CountryId__c','MailingCountry'),
        new DC_FieldMap('ADDRESS:Zipcode__c','MailingPostalCode')
    };

    // Contact (Client) ← ssot__Individual__dlm + Contact Point Relationships + PartyIdentification
    public static final List<DC_FieldMap> CONTACT_CLIENT_MAP = new List<DC_FieldMap>{
        // Main Individual fields
        new DC_FieldMap('Birthday__c','Birthdate'),
        new DC_FieldMap('Client_ID__c','Client_ID__c'),
        new DC_FieldMap('ssot__Id__c','Client_ID__c'),
        new DC_FieldMap('ssot__PartyId__c','Client_ID__c'),
        new DC_FieldMap('Client_Type__c','Client_Type__c'),
        new DC_FieldMap('ssot__FirstName__c','FirstName'),
        new DC_FieldMap('Sex__c','Gender__c'),
        new DC_FieldMap('Guest_Type__c','Guest_Type__c'),
        new DC_FieldMap('Household_ID__c','Household_ID__c'),
        new DC_FieldMap('ssot__LastName__c','LastName'),
        new DC_FieldMap('ssot__MiddleName__c','MiddleName'),
        new DC_FieldMap('ssot__PersonName__c','Name'),
        new DC_FieldMap('Status__c','Status__c'),
        new DC_FieldMap('ssot__TitleName__c','Title'),
        new DC_FieldMap('Send_Promotional_Email__c','Clients_Communication_Via_Email__c'),
        new DC_FieldMap('Send_Promotional_Mail__c','Clients_Communication_Via_Mail__c'),
        new DC_FieldMap('Client_Do_Not_Mail__c','Do_Not_Contact__c'),
        new DC_FieldMap('Client_Do_Not_Email__c','HasOptedOutOfEmail'),
        
        // Contact Point Email fields (from ssot__rel_1697761162380_end__r)
        new DC_FieldMap('EMAIL:ssot__EmailAddress__c','Email'),
        
        // Contact Point Phone fields (from ssot__rel_1697761164176_end__r)
        new DC_FieldMap('PHONE:ssot__FormattedE164PhoneNumber__c','Phone'),
        
        // Contact Point Address fields (from ssot__rel_1697761159567_end__r)
        new DC_FieldMap('ADDRESS:ssot__AddressLine1__c','MailingStreet'),
        new DC_FieldMap('ADDRESS:ssot__CityId__c','MailingCity'),
        new DC_FieldMap('ADDRESS:ssot__StateProvinceId__c','MailingState'),
        new DC_FieldMap('ADDRESS:ssot__CountryId__c','MailingCountry'),
        new DC_FieldMap('ADDRESS:Zipcode__c','MailingPostalCode'),
        
        // PartyIdentification fields (from ssot__rel_1697761176956_end__r)
        new DC_FieldMap('PASSPORT:ssot__IdentificationNumber__c','Passport_Number__c'),
        new DC_FieldMap('PASSPORT:ssot__IssuedAtLocation__c','Passport_Issue_Country__c'),
        new DC_FieldMap('PASSPORT:Issued_Date__c','Passport_Issue_Date__c'),
        new DC_FieldMap('PASSPORT:Expiration_Date__c','Passport_Expire_Date__c')
    };

    // ---------- OTHER OBJECT MAPPINGS (unchanged) ----------

    // Ship__c ← Seaware_Ship__dlm
    public static final List<DC_FieldMap> SHIP_MAP = new List<DC_FieldMap>{
        new DC_FieldMap('Ship_Name__c','Name'),
        new DC_FieldMap('Passengers__c','Passengers__c'),
        new DC_FieldMap('Ship_Code__c','Ship_Code__c'),
        new DC_FieldMap('Staterooms__c','Staterooms__c')
       // new DC_FieldMap('Ship_ID__c','Ship_ID__c'),
       // new DC_FieldMap('Ship_Brand__c','Ship_Brand__c'),
       // new DC_FieldMap('Ship_Registry__c','Ship_Registry__c'),
        //new DC_FieldMap('Last_Modified_Date__c','Last_Modified_Date__c')
    };

    // Sailing__c ← Seaware_Sailing__dlm
    public static final List<DC_FieldMap> SAILING_MAP = new List<DC_FieldMap>{
        new DC_FieldMap('Is_Active__c','Active__c'),
        new DC_FieldMap('Cruise_Land__c','Cruise_Land__c'),
        new DC_FieldMap('Cruise_Name__c','Cruise_Name__c'),
        new DC_FieldMap('Price__c','Cruise_Only__c'),
        new DC_FieldMap('Port_To__c','Disembarkation_City__c'),
        new DC_FieldMap('Port_From__c','Embarkation_City__c'),
        new DC_FieldMap('ITI_Code__c','iti_code__c'),
        new DC_FieldMap('Vacation_Date__c','Departure_Date__c'),
        new DC_FieldMap('Sail_Date_From__c','Sailing_Date__c'),
        new DC_FieldMap('Sail_Date_To__c','Sail_End_Date__c'),
        new DC_FieldMap('Name__c','Name'),
        new DC_FieldMap('Cruise_Length__c','Nights__c'),
        new DC_FieldMap('Package_Code__c','Package_Code__c'),
        new DC_FieldMap('Package_ID__c','Package_ID__c'),
        new DC_FieldMap('Sail_ID__c','SailID__c'),
        new DC_FieldMap('Sailing_Code__c','Sailing_Code__c'),
        new DC_FieldMap('Sail_ID__c','Ship__c')
    };

    // Opportunity ← ssot__Opportunity__dlm
    public static final List<DC_FieldMap> OPPORTUNITY_MAP = new List<DC_FieldMap>{
        new DC_FieldMap('Group_Coordinator__c','Group_Coordinator__c'),
        new DC_FieldMap('Group_Initialization_Date__c','Group_Create_Date__c'),
        //new DC_FieldMap('Group_ID__c','Group_Id__c'),
        new DC_FieldMap('Group_Type__c','Group_Type__c'),
        new DC_FieldMap('Group_Type_Code__c','Group_Type_Code__c'),
        new DC_FieldMap('Comments__c','Group_Type_Name__c'),
        new DC_FieldMap('Group_Status__c','Group_Status__c'),
        new DC_FieldMap('ssot__OpportunityName__c','Name'),
        new DC_FieldMap('Sailing__c','Sailing__c'),
        new DC_FieldMap('SEAWARE_Agency_ID__c','SEAWARE_Agency_ID__c'),
        new DC_FieldMap('ssot__OpportunityStageId__c','StageName'),
        new DC_FieldMap('x120_Day_Release_Date__c','X120_Day_Release_Date__c'),
        new DC_FieldMap('x180_Day_Release_Date__c','X180_Day_Release_Date__c'),
        new DC_FieldMap('Travel_Agent_Name__c','Travel_Agent_Name__c'),
        new DC_FieldMap('Agent_ID__c','agent_ID__c')
    };

    // Booking__c ← Seaware_Booking__dlm
    public static final List<DC_FieldMap> BOOKING_MAP = new List<DC_FieldMap>{
        new DC_FieldMap('Account_ID__c','Agency__c'),
        new DC_FieldMap('Booking_Date__c','Booking_Date__c'),
        new DC_FieldMap('Res_ID__c','Booking_Number__c'),
        new DC_FieldMap('Res_Status__c','Booking_Status__c'),
       // new DC_FieldMap('Package_Type__c','Booking_Type__c'),
        new DC_FieldMap('Group_ID__c','Group_Id__c'),
       // new DC_FieldMap('ssot__Id__c','Group_Id__c'),
        new DC_FieldMap('Gross_Commission__c','Commission__c'),
        new DC_FieldMap('Cruise_Revenue_Net__c','Net_Cruise_Only__c'),
        new DC_FieldMap('NBR_Of_FIT_PAX__c','Number_of_Passengers_FIT__c'),
        new DC_FieldMap('NBR_Of_DLGT_PAX__c','Number_of_Passengers_Group__c'),
        new DC_FieldMap('Gross_Balance_Due__c','Open_Balance__c'),
        new DC_FieldMap('Opportunity__c','Opportunity__c'),
        new DC_FieldMap('Total_Paid_INC_Minus_Refunds__c','Payments__c'),
        new DC_FieldMap('Port_Charges__c','Port_Charge__c'),
        new DC_FieldMap('Primary_Passenger__c','Primary_Passenger__c'),
        new DC_FieldMap('Sailing_ID__c','Sailing_Name__c'),
        new DC_FieldMap('Ship__c','Ship__c'),
        new DC_FieldMap('Agent_ID__c','Travel_Agent__c'),
        new DC_FieldMap('Cabin_Number__c','Cabin__c'),
        new DC_FieldMap('Berth_Category__c','Category__c'),
        new DC_FieldMap('Package_Code__c','Sailing_Code__c')
    };

    // Reservation__c ← Seaware_Reservation__dlm
    public static final List<DC_FieldMap> RESERVATION_MAP = new List<DC_FieldMap>{
        new DC_FieldMap('TaDocs_Update_Date__c','TA_eDocs_Update_Date__c'),
        new DC_FieldMap('TaDocs_Ready_Date__c','TA_eDoc_Ready_Date__c'),
        new DC_FieldMap('SF_Booking_ID__c','BookingID__c'),
        new DC_FieldMap('Client_Name_ID__c','Client_NameID__c'),
        new DC_FieldMap('Guest_ID__c','Guest_ID__c'),
        new DC_FieldMap('Is_Check_In_Complete__c','IsCheck_in_Complete__c'),
        new DC_FieldMap('Name__c','Name'),
       // new DC_FieldMap('Sailing_Code__c','Sailing_Code__c'),
        new DC_FieldMap('Primary_Agency_ID__c','xBooking_AgencyID__c'),
        new DC_FieldMap('Agent_Email__c','xBooking_AgentEmail__c'),
        new DC_FieldMap('Agent_ID__c','xBooking_AgentID__c'),
        new DC_FieldMap('Booking_Agent_Name__c','xBooking_AgentName__c'),
        new DC_FieldMap('Booking_Date__c','xBooking_BookingDate__c'),
        new DC_FieldMap('Cancellation_Date__c','xBooking_CancellationDate__c'),
        new DC_FieldMap('Gross_Revenue__c','xBooking_GrossRev__c'),
        new DC_FieldMap('Guest_Type__c','xBooking_GuestType__c'),
        new DC_FieldMap('Cruise_Description__c','xBooking_ItineraryName__c'),
        new DC_FieldMap('Package_Type__c','xBooking_PackageType__c'),
        new DC_FieldMap('Client_Type__c','xClient_ClientType__c'),
        new DC_FieldMap('Client_Email__c','xClient_EmailAddress__c'),
        new DC_FieldMap('Client_Guest_Type__c','xClient_GuestType__c'),
        new DC_FieldMap('Client_Active_in_Booking__c','Client_Active_in_Booking__c'),
        new DC_FieldMap('Cabin_Number__c','Cabin__c'),
        new DC_FieldMap('Price_Category__c','Booked_Category__c'),
        new DC_FieldMap('Berth_Category__c','Sailed_Category__c'),
        new DC_FieldMap('Total_Tours__c','Is_Shorex_Selected__c'),
        new DC_FieldMap('eDocs_Ready_Date__c','Guest_eDocs_Ready_Date__c'),
        new DC_FieldMap('eDocs_Update_Date__c','Guest_eDocs_Update_Date__c')
    };

    // ---------- RELATIONSHIP CONFIGURATION ----------

    // Relationship mapping configuration for Data Cloud subqueries
    public static final Map<String, String> RELATIONSHIP_MAPPINGS = new Map<String, String>{
        'EMAIL' => 'ssot__rel_1697761162380_end__r',
        'PHONE' => 'ssot__rel_1697761164176_end__r',
        'ADDRESS' => 'ssot__rel_1697761159567_end__r',
        'PASSPORT' => 'ssot__rel_1697761176956_end__r'
    };

    // External ID field mappings
    public static final Map<String, String> UPSERT_KEYS_BY_SOBJECT = new Map<String, String>{
        'Contact_Agent__virtual' => 'Agent_ID__c',
        'Contact_Client__virtual' => 'Client_ID__c',
        'Sailing__c' => 'Sailing_Code__c',
        'Opportunity' => 'Group_Id__c',
        'Booking__c' => 'Booking_Number__c',
        'Reservation__c' => 'Guest_ID__c',
        'Ship__c' => 'Ship_Code__c',
        'Commission_Structure__c' => 'AgencyID__c'
    };
}
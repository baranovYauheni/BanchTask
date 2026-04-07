@IsTest
private class CustomerAppointmentControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact customer = new Contact(LastName = 'TestCustomer', AccountId = acc.Id, Email='test@example.com');
        insert customer;
        
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User agent = new User(
            Alias = 'standt', Email='agent@testorg.com',
            EmailEncodingKey='UTF-8', LastName='TestAgent', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='agent' + DateTime.now().getTime() + '@testorg.com'
        );
        insert agent;
        
        Service_Appointment__c appt = new Service_Appointment__c(
            Service_Agent__c = agent.Id,
            Customer__c = customer.Id,
            Status__c = 'New',
            Appointment_Date_Time__c = DateTime.now().addDays(1)
        );
        insert appt;
    }
    
    @IsTest
    static void testGetAppointmentsForCustomer() {
        Contact customer = [SELECT Id FROM Contact WHERE LastName = 'TestCustomer' LIMIT 1];
        
        Test.startTest();
        List<Service_Appointment__c> appts = CustomerAppointmentController.getAppointmentsForCustomer(customer.Id, 'ASC');
        Test.stopTest();
        
        System.assertEquals(1, appts.size());
    }
    
    @IsTest
    static void testCancelAppointments() {
        Service_Appointment__c appt = [SELECT Id FROM Service_Appointment__c LIMIT 1];
        List<Id> ids = new List<Id>{appt.Id};
        
        Test.startTest();
        CustomerAppointmentController.cancelAppointments(ids);
        Test.stopTest();
        
        Service_Appointment__c cancelledAppt = [SELECT Status__c FROM Service_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Cancelled', cancelledAppt.Status__c);
    }
}

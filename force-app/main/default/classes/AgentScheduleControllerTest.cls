@IsTest
private class AgentScheduleControllerTest {
    
    @TestSetup
    static void makeData() {
        UserRole agentRole;
        try {
            agentRole = [SELECT Id FROM UserRole WHERE Name = 'Service Agent' LIMIT 1];
        } catch (QueryException e) {}
        
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User agent = new User(
            Alias = 'standt', Email='agent@testorg.com',
            EmailEncodingKey='UTF-8', LastName='TestAgent', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='agent' + DateTime.now().getTime() + '@testorg.com',
            UserRoleId = agentRole != null ? agentRole.Id : null,
            IsActive = true
        );
        insert agent;
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account acc = new Account(Name = 'Test Account');
            insert acc;
            
            Contact customer = new Contact(LastName = 'TestCustomer', AccountId = acc.Id, Email='test@example.com');
            insert customer;
            
            Service_Appointment__c appt = new Service_Appointment__c(
                Service_Agent__c = agent.Id,
                Customer__c = customer.Id,
                Status__c = 'New',
                Appointment_Date_Time__c = DateTime.now().addDays(1)
            );
            insert appt;
        }
    }
    
    @IsTest
    static void testGetServiceAgents() {
        Test.startTest();
        List<User> agents = AgentScheduleController.getServiceAgents();
        Test.stopTest();
        System.assertNotEquals(null, agents);
    }
    
    @IsTest
    static void testGetAppointments() {
        User agent = [SELECT Id FROM User WHERE LastName = 'TestAgent' LIMIT 1];
        Date today = Date.today();
        
        Test.startTest();
        List<Service_Appointment__c> appts = AgentScheduleController.getAppointments(agent.Id, 'New', today, today.addDays(7));
        Test.stopTest();
        
        System.assertEquals(1, appts.size());
    }
    
    @IsTest
    static void testUpdateAppointments() {
        Service_Appointment__c appt = [SELECT Id, Status__c FROM Service_Appointment__c LIMIT 1];
        
        List<Map<String, String>> changes = new List<Map<String, String>>{
            new Map<String, String>{
                'Id' => appt.Id,
                'Status__c' => 'Confirmed'
            }
        };
        
        Test.startTest();
        AgentScheduleController.updateAppointments(changes);
        Test.stopTest();
        
        Service_Appointment__c updatedAppt = [SELECT Status__c FROM Service_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Confirmed', updatedAppt.Status__c);
    }
}

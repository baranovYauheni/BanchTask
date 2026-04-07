
@IsTest
private class AppointmentServiceTest {

    @TestSetup
    static void makeData() {
        Contact customer = new Contact(LastName = 'TestCustomer');
        insert customer;

    }

    private static Contact getCustomer() {
        return [SELECT Id FROM Contact WHERE LastName = 'TestCustomer' LIMIT 1];
    }

    private static Service_Appointment__c buildAppointment(
        Id customerId,
        Id agentId,
        DateTime apptTime,
        String status
    ) {
        return new Service_Appointment__c(
            Customer__c              = customerId,
            Service_Agent__c         = agentId,
            Appointment_Date_Time__c = apptTime,
            Status__c                = status,
            Description__c           = 'Test appointment'
        );
    }

    @IsTest
    static void testGetAppointmentsForAgent() {
        Contact customer = getCustomer();
        DateTime t1 = DateTime.now().addDays(1);
        
        List<Service_Appointment__c> appts = new List<Service_Appointment__c>{
            buildAppointment(customer.Id, UserInfo.getUserId(), t1, 'New')
        };
        insert appts;
        
        Test.startTest();
        IAppointmentService svc = new AppointmentService();
        List<Service_Appointment__c> result = svc.getAppointmentsForAgent(UserInfo.getUserId(), 'New', Date.today(), Date.today().addDays(7));
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should return 1 appointment');
    }

    @IsTest
    static void testGetAppointmentsForCustomer_ASC() {
        Contact customer = getCustomer();
        DateTime t1 = DateTime.now().addDays(1);
        DateTime t2 = DateTime.now().addDays(2);

        List<Service_Appointment__c> appts = new List<Service_Appointment__c>{
            buildAppointment(customer.Id, UserInfo.getUserId(), t2, 'New'),
            buildAppointment(customer.Id, UserInfo.getUserId(), t1, 'New')
        };
        insert appts;

        Test.startTest();
        IAppointmentService svc = new AppointmentService();
        List<Service_Appointment__c> result = svc.getAppointmentsForCustomer(customer.Id, 'ASC');
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return 2 appointments');
        System.assert(
            result[0].Appointment_Date_Time__c <= result[1].Appointment_Date_Time__c,
            'Should be sorted ASC'
        );
    }

    @IsTest
    static void testGetAppointmentsForCustomer_DESC() {
        Contact customer = getCustomer();
        DateTime t1 = DateTime.now().addDays(1);
        DateTime t2 = DateTime.now().addDays(2);

        List<Service_Appointment__c> appts = new List<Service_Appointment__c>{
            buildAppointment(customer.Id, UserInfo.getUserId(), t1, 'New'),
            buildAppointment(customer.Id, UserInfo.getUserId(), t2, 'New')
        };
        insert appts;

        Test.startTest();
        IAppointmentService svc = new AppointmentService();
        List<Service_Appointment__c> result = svc.getAppointmentsForCustomer(customer.Id, 'DESC');
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return 2 appointments');
        System.assert(
            result[0].Appointment_Date_Time__c >= result[1].Appointment_Date_Time__c,
            'Should be sorted DESC'
        );
    }

    @IsTest
    static void testCancelAppointments() {
        Contact customer = getCustomer();
        List<Service_Appointment__c> appts = new List<Service_Appointment__c>{
            buildAppointment(customer.Id, UserInfo.getUserId(), DateTime.now().addDays(1), 'New'),
            buildAppointment(customer.Id, UserInfo.getUserId(), DateTime.now().addDays(2), 'Confirmed')
        };
        insert appts;

        List<Id> ids = new List<Id>{ appts[0].Id, appts[1].Id };

        Test.startTest();
        IAppointmentService svc = new AppointmentService();
        svc.cancelAppointments(ids);
        Test.stopTest();

        List<Service_Appointment__c> updated = [
            SELECT Status__c FROM Service_Appointment__c WHERE Id IN :ids
        ];
        for (Service_Appointment__c a : updated) {
            System.assertEquals('Cancelled', a.Status__c, 'All appointments should be Cancelled');
        }
    }

    @IsTest
    static void testValidateNoDoubleBooking_NoConflict() {
        Contact customer = getCustomer();
        DateTime apptTime = DateTime.now().addDays(3);

        Service_Appointment__c existing = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime.addHours(1), 'New'
        );
        insert existing;

        Service_Appointment__c newAppt = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime, 'New'
        );

        Test.startTest();
        IAppointmentService svc = new AppointmentService();
        svc.validateNoDoubleBooking(new List<Service_Appointment__c>{ newAppt }, null);
        Test.stopTest();

        System.assert(true, 'No exception should be thrown when no double-booking exists');
    }

    @IsTest
    static void testValidateNoDoubleBooking_WithConflict() {
        Contact customer = getCustomer();
        DateTime apptTime = DateTime.now().addDays(4);

        Service_Appointment__c existing = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime, 'New'
        );
        insert existing;

        Service_Appointment__c newAppt = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime, 'New'
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert newAppt; // Trigger fires, calls validateNoDoubleBooking → addError
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('within 15 minutes'),
                'Error message should mention 15-minute buffer'
            );
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'DmlException should be thrown for double-booking');
    }

    @IsTest
    static void testValidateNoDoubleBooking_Within15MinBuffer() {
        Contact customer = getCustomer();
        DateTime apptTime = DateTime.now().addDays(5);

        Service_Appointment__c existing = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime, 'New'
        );
        insert existing;

        // Try to create an appointment 10 minutes later — should fail
        Service_Appointment__c newAppt = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime.addMinutes(10), 'New'
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert newAppt;
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('within 15 minutes'),
                'Error message should mention 15-minute buffer'
            );
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'DmlException should be thrown for appointment within 15-min buffer');
    }

    @IsTest
    static void testValidateNoDoubleBooking_After15MinBuffer() {
        Contact customer = getCustomer();
        DateTime apptTime = DateTime.now().addDays(6);

        Service_Appointment__c existing = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime, 'New'
        );
        insert existing;

        // Create an appointment exactly 15 minutes later — should succeed
        Service_Appointment__c newAppt = buildAppointment(
            customer.Id, UserInfo.getUserId(), apptTime.addMinutes(15), 'New'
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert newAppt;
        } catch (DmlException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'No exception should be thrown for appointment exactly 15 minutes apart');
    }

    @IsTest
    static void testUpdateAppointments() {
        Contact customer = getCustomer();
        Service_Appointment__c appt = buildAppointment(
            customer.Id, UserInfo.getUserId(), DateTime.now().addDays(5), 'New'
        );
        insert appt;

        List<Map<String, String>> changes = new List<Map<String, String>>{
            new Map<String, String>{ 'Id' => appt.Id, 'Status__c' => 'Confirmed' }
        };

        Test.startTest();
        IAppointmentService svc = new AppointmentService();
        svc.updateAppointments(changes);
        Test.stopTest();

        Service_Appointment__c updated = [SELECT Status__c FROM Service_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Confirmed', updated.Status__c, 'Status should be updated to Confirmed');
    }
}

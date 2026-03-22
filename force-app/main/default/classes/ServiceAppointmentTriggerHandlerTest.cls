/**
 * ServiceAppointmentTriggerHandlerTest — unit tests for ServiceAppointmentTriggerHandler.
 *
 * Uses Dependency Injection to inject a mock IEventPublisher —
 * demonstrates that the DI pattern is working correctly and testable.
 *
 * Covers:
 *   - onAfterUpdate: Platform Event published when Status changes
 *   - onAfterUpdate: No event published when Status does NOT change
 *   - onBeforeInsert: double-booking via trigger fires correctly
 */
@IsTest
private class ServiceAppointmentTriggerHandlerTest {

    // ─── Mock IEventPublisher ─────────────────────────────────────────────────
    /**
     * MockEventPublisher — test double for IEventPublisher.
     * Captures published events instead of sending to EventBus.
     * Demonstrates Dependency Inversion (D in SOLID).
     */
    private class MockEventPublisher implements IEventPublisher {
        public List<SObject> publishedEvents = new List<SObject>();

        public void publish(List<SObject> events) {
            if (events != null) {
                publishedEvents.addAll(events);
            }
        }
    }

    // ─── Mock IAppointmentService ─────────────────────────────────────────────
    private class MockAppointmentService implements IAppointmentService {
        public Boolean validateCalled = false;

        public List<Service_Appointment__c> getAppointmentsForAgent(
            Id agentId, String status, Date startDate, Date endDate) {
            return new List<Service_Appointment__c>();
        }
        public List<Service_Appointment__c> getAppointmentsForCustomer(
            Id contactId, String sortOrder) {
            return new List<Service_Appointment__c>();
        }
        public void updateAppointments(List<Map<String, String>> changes) {}
        public void cancelAppointments(List<Id> ids) {}
        public void validateNoDoubleBooking(
            List<Service_Appointment__c> newRecords,
            Map<Id, Service_Appointment__c> oldMap) {
            validateCalled = true;
        }
    }

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Contact customer = new Contact(LastName = 'TriggerTestCustomer');
        insert customer;
    }

    private static Contact getCustomer() {
        return [SELECT Id FROM Contact WHERE LastName = 'TriggerTestCustomer' LIMIT 1];
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void testAfterUpdate_StatusChanged_PublishesEvent() {
        Contact customer = getCustomer();

        Service_Appointment__c appt = new Service_Appointment__c(
            Customer__c              = customer.Id,
            Service_Agent__c         = UserInfo.getUserId(),
            Appointment_Date_Time__c = DateTime.now().addDays(10),
            Status__c                = 'New',
            Description__c           = 'Trigger Test'
        );
        insert appt;

        MockEventPublisher mockPublisher = new MockEventPublisher();
        MockAppointmentService mockService = new MockAppointmentService();

        // Build trigger-like context manually using the DI constructor
        List<Service_Appointment__c> newList = new List<Service_Appointment__c>{
            new Service_Appointment__c(
                Id              = appt.Id,
                Status__c       = 'Confirmed',
                Service_Agent__c = appt.Service_Agent__c,
                Appointment_Date_Time__c = appt.Appointment_Date_Time__c
            )
        };
        Map<Id, Service_Appointment__c> oldMap = new Map<Id, Service_Appointment__c>{
            appt.Id => new Service_Appointment__c(
                Id        = appt.Id,
                Status__c = 'New'
            )
        };

        Test.startTest();
        ServiceAppointmentTriggerHandler handler =
            new ServiceAppointmentTriggerHandler(mockPublisher, mockService);
        // Call onAfterUpdate directly (simulates trigger context)
        handler.onAfterUpdate(newList, oldMap);
        Test.stopTest();

        System.assertEquals(
            1, mockPublisher.publishedEvents.size(),
            'One Platform Event should be published on status change'
        );
        Change_Service_Appointment__e evt =
            (Change_Service_Appointment__e) mockPublisher.publishedEvents[0];
        System.assertEquals('New', evt.Old_status__c);
        System.assertEquals('Confirmed', evt.New_Status__c);
    }

    @IsTest
    static void testAfterUpdate_NoStatusChange_NoEvent() {
        Contact customer = getCustomer();

        Service_Appointment__c appt = new Service_Appointment__c(
            Customer__c              = customer.Id,
            Service_Agent__c         = UserInfo.getUserId(),
            Appointment_Date_Time__c = DateTime.now().addDays(11),
            Status__c                = 'New',
            Description__c           = 'No change test'
        );
        insert appt;

        MockEventPublisher mockPublisher = new MockEventPublisher();
        MockAppointmentService mockService = new MockAppointmentService();

        List<Service_Appointment__c> newList = new List<Service_Appointment__c>{
            new Service_Appointment__c(Id = appt.Id, Status__c = 'New')
        };
        Map<Id, Service_Appointment__c> oldMap = new Map<Id, Service_Appointment__c>{
            appt.Id => new Service_Appointment__c(Id = appt.Id, Status__c = 'New')
        };

        Test.startTest();
        ServiceAppointmentTriggerHandler handler =
            new ServiceAppointmentTriggerHandler(mockPublisher, mockService);
        handler.onAfterUpdate(newList, oldMap);
        Test.stopTest();

        System.assertEquals(
            0, mockPublisher.publishedEvents.size(),
            'No event should be published when status does not change'
        );
    }

    @IsTest
    static void testBeforeInsert_CallsValidateNoDoubleBooking() {
        MockEventPublisher mockPublisher = new MockEventPublisher();
        MockAppointmentService mockService = new MockAppointmentService();

        List<Service_Appointment__c> newList = new List<Service_Appointment__c>{
            new Service_Appointment__c(
                Status__c                = 'New',
                Service_Agent__c         = UserInfo.getUserId(),
                Appointment_Date_Time__c = DateTime.now().addDays(15)
            )
        };

        Test.startTest();
        ServiceAppointmentTriggerHandler handler =
            new ServiceAppointmentTriggerHandler(mockPublisher, mockService);
        handler.onBeforeInsert(newList);
        Test.stopTest();

        System.assert(
            mockService.validateCalled,
            'validateNoDoubleBooking should be called on before insert'
        );
    }
}

/**
 * ServiceAppointmentTriggerHandler — extends BaseTriggerHandler.
 *
 * SOLID — Single Responsibility Principle (S):
 *   Handles trigger events for Service_Appointment__c only.
 *   Business logic is fully delegated to IAppointmentService and IEventPublisher.
 *
 * SOLID — Dependency Inversion Principle (D):
 *   Depends on IAppointmentService and IEventPublisher abstractions,
 *   not on AppointmentService or EventBus directly.
 *   This allows injecting mocks in unit tests.
 *
 * SOLID — Liskov Substitution Principle (L):
 *   Extends BaseTriggerHandler and overrides only the needed hooks,
 *   without breaking the execute() contract.
 */
public with sharing class ServiceAppointmentTriggerHandler extends BaseTriggerHandler {

    // D — Dependency Inversion: fields reference interfaces (abstractions)
    private IEventPublisher eventPublisher;
    private IAppointmentService appointmentService;

    /**
     * Dependency Injection constructor — used in unit tests to inject mocks.
     */
    public ServiceAppointmentTriggerHandler(
        IEventPublisher eventPublisher,
        IAppointmentService appointmentService
    ) {
        this.eventPublisher     = eventPublisher;
        this.appointmentService = appointmentService;
    }

    /**
     * Default constructor — wires concrete implementations for production use.
     * O — Open/Closed: to switch publisher or service, no existing code changes;
     *     just pass a different implementation to the DI constructor.
     */
    public ServiceAppointmentTriggerHandler() {
        this(new PlatformEventPublisher(), new AppointmentService());
    }

    /**
     * Before Insert: prevent double booking for new appointments.
     * Requirement 2.6: Trigger prevents double booking.
     */
    protected override void onBeforeInsert(List<SObject> newRecords) {
        appointmentService.validateNoDoubleBooking(
            (List<Service_Appointment__c>) newRecords,
            null
        );
    }

    /**
     * Before Update: prevent double booking when agent or time changes.
     */
    protected override void onBeforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        appointmentService.validateNoDoubleBooking(
            (List<Service_Appointment__c>) newRecords,
            (Map<Id, Service_Appointment__c>) oldMap
        );
    }

    /**
     * After Update: publish Platform Event when Status__c changes.
     * Requirement 2.3: Platform Event published on status change.
     */
    protected override void onAfterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Change_Service_Appointment__e> events = new List<Change_Service_Appointment__e>();

        for (Service_Appointment__c newAppt : (List<Service_Appointment__c>) newRecords) {
            Service_Appointment__c oldAppt = (Service_Appointment__c) oldMap.get(newAppt.Id);
            if (newAppt.Status__c != oldAppt.Status__c) {
                events.add(new Change_Service_Appointment__e(
                    Appointment_Id__c = String.valueOf(newAppt.Id),
                    Old_status__c     = oldAppt.Status__c,
                    New_Status__c     = newAppt.Status__c,
                    Changed_by_Id__c  = UserInfo.getUserId(),
                    Changed_on__c     = System.now()
                ));
            }
        }

        // D — Dependency Inversion: call through abstraction, not EventBus directly
        eventPublisher.publish(events);
    }
}
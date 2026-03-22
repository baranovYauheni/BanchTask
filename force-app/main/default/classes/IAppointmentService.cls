/**
 * IAppointmentService
 *
 * SOLID — Interface Segregation Principle (I):
 *   Defines the contract for all appointment business operations.
 *   Controllers and trigger handlers depend on this interface, not on concrete classes.
 *
 * SOLID — Dependency Inversion Principle (D):
 *   High-level modules (AgentScheduleController, CustomerAppointmentController,
 *   ServiceAppointmentTriggerHandler) depend on this abstraction.
 *   Concrete implementation (AppointmentService) can be swapped without
 *   changing any caller — e.g. for mocking in unit tests.
 */
public interface IAppointmentService {

    List<Service_Appointment__c> getAppointmentsForAgent(
        Id agentId,
        String status,
        Date startDate,
        Date endDate
    );

    List<Service_Appointment__c> getAppointmentsForCustomer(
        Id contactId,
        String sortOrder
    );

    void updateAppointments(List<Map<String, String>> changes);

    void cancelAppointments(List<Id> appointmentIds);

    /**
     * Validates that no two active appointments for the same agent
     * overlap at the same date/time. Adds field-level errors for violations.
     * Called from ServiceAppointmentTriggerHandler on before insert and before update.
     */
    void validateNoDoubleBooking(
        List<Service_Appointment__c> newRecords,
        Map<Id, Service_Appointment__c> oldMap
    );
}

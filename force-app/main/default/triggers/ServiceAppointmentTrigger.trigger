/**
 * ServiceAppointmentTrigger
 * 
 * Requirement 2.6: One trigger per object, logic in handler.
 * Before Insert/Update: validates no double booking via AppointmentService.
 * After Update: publishes Platform Event on status change.
 * 
 * Uses BaseTriggerHandler.execute() — Template Method pattern.
 */
trigger ServiceAppointmentTrigger on Service_Appointment__c (
    before insert,
    before update,
    after update
) {
    new ServiceAppointmentTriggerHandler().execute();
}
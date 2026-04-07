
trigger ServiceAppointmentTrigger on Service_Appointment__c (
    before insert,
    before update,
    after update
) {
    new ServiceAppointmentTriggerHandler().execute();
}
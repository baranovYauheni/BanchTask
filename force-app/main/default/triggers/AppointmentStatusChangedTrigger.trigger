/**
 * AppointmentStatusChangedTrigger
 * Catches Change_Service_Appointment__e Platform Events and delegates
 * to AppointmentStatusChangedTriggerHandler via BaseTriggerHandler.execute().
 */
trigger AppointmentStatusChangedTrigger on Change_Service_Appointment__e (after insert) {
    new AppointmentStatusChangedTriggerHandler().execute();
}

trigger AppointmentStatusChangedTrigger on Change_Service_Appointment__e (after insert) {
    new AppointmentStatusChangedTriggerHandler().execute();
}
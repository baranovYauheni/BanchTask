/**
 * AppointmentReminderScheduler
 *
 * Schedulable wrapper for AppointmentReminderBatch.
 * Runs the batch job on a configured schedule (via Setup → Apex Jobs, or programmatically).
 *
 * SOLID — Single Responsibility (S):
 *   Responsible only for scheduling. Does not contain any batch logic.
 *
 * Usage — schedule daily at 8:00 AM:
 *   System.schedule('Daily Appointment Reminders', '0 0 8 * * ?', new AppointmentReminderScheduler());
 */
public with sharing class AppointmentReminderScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AppointmentReminderBatch(), 200);
    }
}

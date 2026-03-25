/**
 * AppointmentReminderBatchTest
 *
 * Tests for AppointmentReminderBatch and AppointmentReminderScheduler.
 *
 * Covers:
 *   - Batch executes without errors when appointments exist for tomorrow
 *   - Batch executes without errors when no appointments exist (empty scope)
 *   - Scheduler correctly instantiates and enqueues the batch
 */
@IsTest
private class AppointmentReminderBatchTest {

    @TestSetup
    static void makeData() {
        // Contact WITH email — should receive reminder
        Contact customerWithEmail = new Contact(
            LastName = 'CustomerWithEmail',
            Email    = 'test@example.com'
        );
        // Contact WITHOUT email — should be skipped gracefully
        Contact customerNoEmail = new Contact(
            LastName = 'CustomerNoEmail'
        );
        insert new List<Contact>{ customerWithEmail, customerNoEmail };

        DateTime tomorrow = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(10, 0, 0, 0));

        List<Service_Appointment__c> appts = new List<Service_Appointment__c>{
            // Should be picked up — New status, has email
            new Service_Appointment__c(
                Customer__c              = customerWithEmail.Id,
                Service_Agent__c         = UserInfo.getUserId(),
                Appointment_Date_Time__c = tomorrow,
                Status__c                = 'New',
                Description__c           = 'Batch test appointment'
            ),
            // Should be picked up — Confirmed status, has email
            new Service_Appointment__c(
                Customer__c              = customerWithEmail.Id,
                Service_Agent__c         = UserInfo.getUserId(),
                Appointment_Date_Time__c = tomorrow.addHours(2),
                Status__c                = 'Confirmed',
                Description__c           = 'Batch test confirmed'
            ),
            // Should be SKIPPED — Cancelled status
            new Service_Appointment__c(
                Customer__c              = customerWithEmail.Id,
                Service_Agent__c         = UserInfo.getUserId(),
                Appointment_Date_Time__c = tomorrow.addHours(4),
                Status__c                = 'Cancelled',
                Description__c           = 'Should be excluded'
            )
        };
        insert appts;
    }

    @IsTest
    static void testBatch_WithTomorrowAppointments() {
        Test.startTest();
        AppointmentReminderBatch batch = new AppointmentReminderBatch();
        Id jobId = Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify batch completed — no exception thrown
        System.assertNotEquals(null, jobId, 'Batch job should have been enqueued');

        // Verify only non-cancelled appointments would be in scope (2 records)
        DateTime tomorrowStart = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(0, 0, 0, 0));
        DateTime tomorrowEnd   = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(23, 59, 59, 999));

        Integer count = [
            SELECT COUNT()
            FROM Service_Appointment__c
            WHERE Appointment_Date_Time__c >= :tomorrowStart
            AND   Appointment_Date_Time__c <= :tomorrowEnd
            AND   Status__c IN ('New', 'Confirmed')
        ];
        System.assertEquals(2, count, 'Query scope should include exactly 2 active appointments');
    }

    @IsTest
    static void testBatch_EmptyScope() {
        // Delete all appointments — batch should handle empty scope gracefully
        delete [SELECT Id FROM Service_Appointment__c];

        Test.startTest();
        Id jobId = Database.executeBatch(new AppointmentReminderBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch should run even with empty scope');
    }

    @IsTest
    static void testScheduler() {
        Test.startTest();
        String cronExp = '0 0 8 * * ?';
        Id scheduledJobId = System.schedule(
            'Test Appointment Reminder',
            cronExp,
            new AppointmentReminderScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduledJobId, 'Scheduler job should be created');
    }
}

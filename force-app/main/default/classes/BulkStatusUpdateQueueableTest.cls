/**
 * BulkStatusUpdateQueueableTest
 *
 * Tests for BulkStatusUpdateQueueable.
 *
 * Covers:
 *   - Cancel all appointments for an agent on a specific date
 *   - No records to update — executes without error
 *   - Convenience constructor (agent + date)
 */
@IsTest
private class BulkStatusUpdateQueueableTest {

    @TestSetup
    static void makeData() {
        Contact customer = new Contact(LastName = 'QueueableTestCustomer');
        insert customer;

        Date targetDate = Date.today().addDays(5);
        DateTime apptTime = DateTime.newInstance(targetDate, Time.newInstance(9, 0, 0, 0));

        List<Service_Appointment__c> appts = new List<Service_Appointment__c>{
            new Service_Appointment__c(
                Customer__c              = customer.Id,
                Service_Agent__c         = UserInfo.getUserId(),
                Appointment_Date_Time__c = apptTime,
                Status__c                = 'New',
                Description__c           = 'Queueable test 1'
            ),
            new Service_Appointment__c(
                Customer__c              = customer.Id,
                Service_Agent__c         = UserInfo.getUserId(),
                Appointment_Date_Time__c = apptTime.addHours(1),
                Status__c                = 'Confirmed',
                Description__c           = 'Queueable test 2'
            ),
            // Already cancelled — should NOT be updated again
            new Service_Appointment__c(
                Customer__c              = customer.Id,
                Service_Agent__c         = UserInfo.getUserId(),
                Appointment_Date_Time__c = apptTime.addHours(2),
                Status__c                = 'Cancelled',
                Description__c           = 'Already cancelled'
            )
        };
        insert appts;
    }

    @IsTest
    static void testBulkCancel_ForAgentOnDate() {
        Date targetDate = Date.today().addDays(5);

        Test.startTest();
        BulkStatusUpdateQueueable job = new BulkStatusUpdateQueueable(
            UserInfo.getUserId(),
            targetDate
        );
        System.enqueueJob(job);
        Test.stopTest();

        // Verify that New and Confirmed → Cancelled; already-cancelled stays Cancelled
        List<Service_Appointment__c> updated = [
            SELECT Status__c
            FROM Service_Appointment__c
            WHERE Service_Agent__c = :UserInfo.getUserId()
        ];

        for (Service_Appointment__c a : updated) {
            System.assertEquals('Cancelled', a.Status__c,
                'All appointments should be Cancelled after queueable run');
        }
    }

    @IsTest
    static void testBulkUpdate_EmptyResult() {
        // Delete all records so the query returns nothing
        delete [SELECT Id FROM Service_Appointment__c];

        Test.startTest();
        BulkStatusUpdateQueueable job = new BulkStatusUpdateQueueable(
            UserInfo.getUserId(),
            Date.today().addDays(5)
        );
        System.enqueueJob(job);
        Test.stopTest();

        // Should complete without exception
        System.assertEquals(0,
            [SELECT COUNT() FROM Service_Appointment__c],
            'No records should exist'
        );
    }

    @IsTest
    static void testFullConstructor_StatusFilter() {
        Date targetDate = Date.today().addDays(5);

        Test.startTest();
        // Only update 'New' → 'Confirmed', leave 'Confirmed' as is
        BulkStatusUpdateQueueable job = new BulkStatusUpdateQueueable(
            UserInfo.getUserId(),
            targetDate,
            'New',
            'Confirmed',
            200,
            0
        );
        System.enqueueJob(job);
        Test.stopTest();

        // The 'New' one should now be 'Confirmed'
        List<Service_Appointment__c> newOnes = [
            SELECT Status__c
            FROM Service_Appointment__c
            WHERE Description__c = 'Queueable test 1'
        ];
        System.assertEquals(1, newOnes.size());
        System.assertEquals('Confirmed', newOnes[0].Status__c,
            'New appointment should be updated to Confirmed');
    }
}

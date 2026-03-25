/**
 * BulkStatusUpdateQueueable
 *
 * Requirement 2.3 — Queueable Apex:
 *   Bulk-updates the Status__c of Service_Appointment__c records
 *   matching a given agent and/or date to a target status.
 *
 * Typical use-case: cancel all 'New' and 'Confirmed' appointments
 *   for a specific agent on a specific day (e.g. agent is sick).
 *
 * SOLID — Single Responsibility (S):
 *   Responsible only for executing a bulk status update asynchronously.
 *
 * SOLID — Dependency Inversion (D):
 *   Uses IAppointmentService for the actual DML — conforms to the
 *   established service layer architecture.
 *
 * Bulk Safety (Requirement 2.7):
 *   All DML goes through AppointmentService.cancelAppointments() which
 *   collects into a List before a single update call.
 *
 * Chaining:
 *   If the result set exceeds the batch limit, a new Queueable job
 *   is chained automatically (using System.enqueueJob).
 */
public with sharing class BulkStatusUpdateQueueable implements Queueable {

    private Id      agentId;
    private Date    targetDate;
    private String  fromStatus;
    private String  toStatus;
    private Integer batchSize;
    private Integer offset;

    /**
     * @param agentId    — filter by Service Agent (null = all agents)
     * @param targetDate — filter by appointment date (null = all dates)
     * @param fromStatus — current status to match (null = any status)
     * @param toStatus   — new status to set
     * @param batchSize  — records per execution (max 200 for safety)
     * @param offset     — SOQL offset for chaining (start at 0)
     */
    public BulkStatusUpdateQueueable(
        Id      agentId,
        Date    targetDate,
        String  fromStatus,
        String  toStatus,
        Integer batchSize,
        Integer offset
    ) {
        this.agentId    = agentId;
        this.targetDate = targetDate;
        this.fromStatus = fromStatus;
        this.toStatus   = toStatus;
        this.batchSize  = (batchSize != null && batchSize > 0 && batchSize <= 200) ? batchSize : 200;
        this.offset     = (offset != null && offset >= 0) ? offset : 0;
    }

    /**
     * Convenience constructor — cancel all active appointments for an agent on a date.
     */
    public BulkStatusUpdateQueueable(Id agentId, Date targetDate) {
        this(agentId, targetDate, null, 'Cancelled', 200, 0);
    }

    // ─── Queueable ───────────────────────────────────────────────────────────

    public void execute(QueueableContext qc) {
        // Build dynamic SOQL to find matching appointments
        String query =
            'SELECT Id FROM Service_Appointment__c ' +
            'WHERE Status__c NOT IN (\'Cancelled\', \'Completed\') ';

        if (agentId != null) {
            query += 'AND Service_Agent__c = \'' + agentId + '\' ';
        }

        if (targetDate != null) {
            DateTime dayStart = DateTime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
            DateTime dayEnd   = DateTime.newInstance(targetDate, Time.newInstance(23, 59, 59, 999));
            query += 'AND Appointment_Date_Time__c >= ' + dayStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + ' ';
            query += 'AND Appointment_Date_Time__c <= ' + dayEnd.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + ' ';
        }

        if (String.isNotBlank(fromStatus)) {
            query += 'AND Status__c = \'' + fromStatus + '\' ';
        }

        query += 'LIMIT ' + batchSize + ' OFFSET ' + offset;

        List<SObject> records = Database.query(query);

        if (records.isEmpty()) {
            System.debug('BulkStatusUpdateQueueable: no more records to update. Done.');
            return;
        }

        // Collect IDs and update status in bulk
        List<Service_Appointment__c> toUpdate = new List<Service_Appointment__c>();
        for (SObject rec : records) {
            toUpdate.add(new Service_Appointment__c(
                Id        = rec.Id,
                Status__c = toStatus
            ));
        }

        update toUpdate;

        System.debug(
            'BulkStatusUpdateQueueable: updated ' + toUpdate.size() +
            ' records to status "' + toStatus + '" (offset ' + offset + ')'
        );

        // Chain next batch if more records may exist
        if (records.size() == batchSize && !Test.isRunningTest()) {
            System.enqueueJob(new BulkStatusUpdateQueueable(
                agentId, targetDate, fromStatus, toStatus, batchSize, offset + batchSize
            ));
        }
    }
}

/**
 * BulkStatusUpdateQueueable — asynchronously bulk-updates Status__c on appointments.
 *
 * SOLID — Single Responsibility Principle (S):
 *   Responsible only for executing a bulk status update asynchronously.
 *
 * Supports filtering by agent, date, and current status.
 * Chains a new job automatically if more records may exist (offset-based pagination).
 */
public with sharing class BulkStatusUpdateQueueable implements Queueable {

    private Id      agentId;
    private Date    targetDate;
    private String  fromStatus;
    private String  toStatus;
    private Integer batchSize;
    private Integer offset;

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

    public BulkStatusUpdateQueueable(Id agentId, Date targetDate) {
        this(agentId, targetDate, null, 'Cancelled', 200, 0);
    }

    public void execute(QueueableContext qc) {
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
        query += 'WITH SECURITY_ENFORCED LIMIT ' + batchSize + ' OFFSET ' + offset;

        List<SObject> records = Database.query(query);
        
        if (!records.isEmpty() && !Schema.sObjectType.Service_Appointment__c.fields.Status__c.isUpdateable()) {
            throw new SecurityException('Insufficient permissions to bulk update Status.');
        }
        if (records.isEmpty()) {
            System.debug('BulkStatusUpdateQueueable: no more records to update.');
            return;
        }

        List<Service_Appointment__c> toUpdate = new List<Service_Appointment__c>();
        for (SObject rec : records) {
            toUpdate.add(new Service_Appointment__c(Id = rec.Id, Status__c = toStatus));
        }
        update toUpdate;

        System.debug('BulkStatusUpdateQueueable: updated ' + toUpdate.size() + ' records to "' + toStatus + '"');

        if (records.size() == batchSize && !Test.isRunningTest()) {
            System.enqueueJob(new BulkStatusUpdateQueueable(
                agentId, targetDate, fromStatus, toStatus, batchSize, offset + batchSize
            ));
        }
    }
}

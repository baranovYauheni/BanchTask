public with sharing class AgentScheduleController {

    public with sharing class UserSelector {
        public List<User> getAgents() {
            return [
                SELECT Id, Name, UserRole.Name
                FROM User 
                WHERE isActive = true
                AND UserRole.Name = 'Service Agent'
                ORDER BY Name
                LIMIT 100
            ];
        }
    }

    @AuraEnabled(cacheable = true)
    public static List<User> getServiceAgents() {
        return new UserSelector().getAgents();
    }

    @AuraEnabled
    public static List<Service_Appointment__c> getServiceAppointments(Id agentId, String status, Date startDate, Date endDate) {
        //Используем динамический SOQL что бы избежать сложных условий и нескольких SOQL запросов на каждый случай

        String query = 'SELECT Id, Name, Customer__c, Customer__r.Name, Appointment_Date_Time__c, Status__c, Description__c ' +
                       'FROM Service_Appointment__c ' +
                       'WHERE Service_Agent__c = :agentId ';
        
        if (String.isNotBlank(status)) {
            query += 'AND Status__c = :status ';
        }

        if (startDate != null) {
            DateTime startDt = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            query += 'AND Appointment_Date_Time__c >= :startDt ';
        }
        if (endDate != null) {
            DateTime endDt = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 999));
            query += 'AND Appointment_Date_Time__c <= :endDt ';
        }

        query += 'WITH SECURITY_ENFORCED ORDER BY Appointment_Date_Time__c ASC LIMIT 100';

        return Database.query(query);
    }

    @AuraEnabled
    public static void updateServiceAppointments(List<Map<String, String>> changes) {
        List<Service_Appointment__c> serviceAppts = new LIst<Service_Appointment__c>();

        for (Map<String,String> change : changes) {
            Service_Appointment__c serviceAppt = new Service_Appointment__c(Id = change.get('Id'));

            if (change.containsKey('Status__c') && String.isNotBlank(change.get('Status__c'))) {
                serviceAppt.Status__c = change.get('Status__c');
            }

            if (change.containsKey('Appointment_Date_Time__c') && String.isNotBlank(change.get('Appointment_Date_Time__c'))) {
                serviceAppt.Appointment_Date_Time__c = (DateTime) JSON.deserialize(
                    '"' + change.get('Appointment_Date_Time__c') + '"', DateTime.class
                );
            }
            serviceAppts.add(serviceAppt);
        }

        if (!serviceAppts.isEmpty()) {
            update serviceAppts;
        }
    }

    @AuraEnabled
    public static void executeBulkCancel(Id agentId, String targetDateStr) {
        Date targetDate = String.isNotBlank(targetDateStr) ? Date.valueOf(targetDateStr) : Date.today();
        System.enqueueJob(new BulkStatusUpdateQueueable(agentId, targetDate, 'New', 'Cancelled', 50, 0));
    }
}
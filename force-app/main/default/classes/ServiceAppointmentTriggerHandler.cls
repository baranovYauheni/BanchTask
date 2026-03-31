public with sharing class ServiceAppointmentTriggerHandler extends BaseTriggerHandler {
    
    private IEventPublisher publisher;
    private IAppointmentService service;

    public ServiceAppointmentTriggerHandler() {
        this(new PlatformEventPublisher(), new AppointmentService());
    }

    @TestVisible
    private ServiceAppointmentTriggerHandler(IEventPublisher publisher, IAppointmentService service) {
        this.publisher = publisher;
        this.service = service;
    }

    @TestVisible
    protected override void onBeforeInsert(List<SObject> newRecords) {
        service.validateNoDoubleBooking((List<Service_Appointment__c>) newRecords, null);
    }

    @TestVisible
    protected override void onBeforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        service.validateNoDoubleBooking(
            (List<Service_Appointment__c>) newRecords, 
            (Map<Id, Service_Appointment__c>) oldMap
        );
    }

    @TestVisible
    protected override void onAfterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Service_Appointment__c> newAppts = (List<Service_Appointment__c>) newRecords;
        Map<Id, Service_Appointment__c> oldApptMap = (Map<Id, Service_Appointment__c>) oldMap;
        
        List<Change_Service_Appointment__e> events = new List<Change_Service_Appointment__e>();
        List<Service_Appointment__c> calloutsToMake = new List<Service_Appointment__c>();

        for(Service_Appointment__c newAppt : newAppts){
            Service_Appointment__c oldAppt = oldApptMap.get(newAppt.Id);
            if(newAppt.Status__c != oldAppt.Status__c){
                events.add(new Change_Service_Appointment__e(
                    Appointment_Id__c = String.valueOf(newAppt.Id),
                    Old_status__c     = oldAppt.Status__c,
                    New_Status__c     = newAppt.Status__c,
                    Changed_by_Id__c  = UserInfo.getUserId(),
                    Changed_on__c     = System.now()
                ));
                calloutsToMake.add(newAppt);
            }
        }

        if(!events.isEmpty()){
            publisher.publish(events); // OCP: works with any publisher
        }
        
        if(!calloutsToMake.isEmpty()){
            System.enqueueJob(new AppointmentCalloutQueueable(calloutsToMake));
        }
    }
}
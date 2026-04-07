import { LightningElement, track, wire } from 'lwc';
import getServiceAgents from '@salesforce/apex/AgentScheduleController.getServiceAgents';
import getAppointments from '@salesforce/apex/AgentScheduleController.getServiceAppointments';
import updateAppointments from '@salesforce/apex/AgentScheduleController.updateServiceAppointments';
import executeBulkCancel from '@salesforce/apex/AgentScheduleController.executeBulkCancel';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AgentScheduleTable extends LightningElement {
    @track agentOptions = [];
    @track appointments = [];
    @track error;

    changedRecords = {};

    selectedAgentId = '';
    selectedStatus = '';
    startDate = null;
    endDate = null;

    get hasPendingChanges() {
        return Object.keys(this.changedRecords).length > 0;
    }

    get statusOptions() {
        return [
            { label: 'New', value: 'New' },
            { label: 'Confirmed', value: 'Confirmed' },
            { label: 'Completed', value: 'Completed' },
            { label: 'Cancelled', value: 'Cancelled' }
        ];
    }

    get statusFilterOptions() {
        return [{ label: 'All', value: '' }, ...this.statusOptions];
    }

    @wire(getServiceAgents)
    wiredAgents({ error, data }) {
        if (data) {
            this.agentOptions = data.map(user => ({ label: user.Name, value: user.Id }));
        } else if (error) {
            this.error = error;
        }
    }

    loadAppointments() {
        if (!this.selectedAgentId) {
            this.appointments = [];
            return;
        }
        this.changedRecords = {};

        getAppointments({
            agentId: this.selectedAgentId,
            status: this.selectedStatus,
            startDate: this.startDate,
            endDate: this.endDate
        })
            .then(result => {
                this.appointments = result.map(record => ({
                    ...record,
                    customerName: record.Customer__r ? record.Customer__r.Name : '',
                    dateInputValue: record.Appointment_Date_Time__c
                        ? record.Appointment_Date_Time__c.slice(0, 16)
                        : ''
                }));
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.appointments = [];
                this.showToast('Error loading records', error.body?.message ?? error.message, 'error');
            });
    }

    handleStatusCellChange(event) {
        const rowId = event.target.dataset.id;
        const newValue = event.detail.value;

        this.appointments = this.appointments.map(a =>
            a.Id === rowId ? { ...a, Status__c: newValue } : a
        );

        this.changedRecords = {
            ...this.changedRecords,
            [rowId]: { ...this.changedRecords[rowId], Id: rowId, Status__c: newValue }
        };
    }

    handleDateCellChange(event) {
        const rowId = event.target.dataset.id;
        const newValue = event.target.value;

        this.appointments = this.appointments.map(a =>
            a.Id === rowId ? { ...a, dateInputValue: newValue } : a
        );

        const isoValue = newValue ? new Date(newValue).toISOString() : null;
        this.changedRecords = {
            ...this.changedRecords,
            [rowId]: { ...this.changedRecords[rowId], Id: rowId, Appointment_Date_Time__c: isoValue }
        };
    }

    handleSaveAll() {
        const changes = Object.values(this.changedRecords);

        updateAppointments({ changes })
            .then(() => {
                this.showToast('Saved!', changes.length + ' record(s) updated successfully.', 'success');
                this.loadAppointments();
            })
            .catch(error => {
                this.showToast('Error saving', error.body?.message ?? error.message, 'error');
            });
    }

    handleCancelChanges() {
        this.loadAppointments();
    }


    handleAgentChange(event) {
        this.selectedAgentId = event.detail.value;
        this.loadAppointments();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.loadAppointments();
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.loadAppointments();
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.loadAppointments();
    }

    handleBulkCancel() {
        if (!this.selectedAgentId) return;
        const targetDateStr = this.startDate || new Date().toISOString().split('T')[0];

        executeBulkCancel({ agentId: this.selectedAgentId, targetDateStr: targetDateStr })
            .then(() => {
                this.showToast('Job Enqueued', 'Bulk cancel job submitted successfully for ' + targetDateStr, 'success');
                setTimeout(() => { this.loadAppointments(); }, 2000);
            })
            .catch(error => {
                this.showToast('Error', error.body?.message ?? error.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

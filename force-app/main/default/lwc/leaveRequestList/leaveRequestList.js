import { LightningElement, wire, api } from 'lwc';
import getMyLeaveRequests from '@salesforce/apex/LeaveRequestController.getMyLeaveRequests';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

const COLUMNS = [
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text', initialWidth: 160 },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date', initialWidth: 130 },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date', initialWidth: 130 },
    { label: 'Total Days', fieldName: 'Total_Days__c', type: 'number', initialWidth: 110 },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'statusBadge',
        initialWidth: 140,
        typeAttributes: {
            status: {
                fieldName: 'Status__c'
            }
        }
    },
    { label: 'Manager Comments', fieldName: 'Manager_Comments__c', type: 'text' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: getRowActions
        }
    }
];

function getRowActions(row, doneCallback) {
    const actions = [];
    if (row.Status__c === 'Pending') {
        actions.push({
            label: 'Cancel Request',
            name: 'cancel',
            iconName: 'utility:close'
        });
    }
    doneCallback(actions);
}

export default class LeaveRequestList extends LightningElement {
    columns = COLUMNS;
    leaveRequests = [];
    error;
    wiredLeaveRequestsResult;

    searchTerm = '';
    selectedStatusFilter = 'All';
    isLoading = false;

    statusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    @wire(getMyLeaveRequests)
    wiredLeaveRequests(result) {
        this.wiredLeaveRequestsResult = result;
        const { data, error } = result;
        if (data) {
            this.leaveRequests = [...data];
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.leaveRequests = [];
            console.error('Error fetching leave requests:', error);
        }
    }

    get filteredLeaveRequests() {
        return this.leaveRequests.filter(record => {
            const matchesStatus =
                this.selectedStatusFilter === 'All' ||
                record.Status__c === this.selectedStatusFilter;

            if (!matchesStatus) {
                return false;
            }

            if (!this.searchTerm) {
                return true;
            }

            const searchLower = this.searchTerm.toLowerCase();
            const leaveType = (record.Leave_Type__c || '').toLowerCase();
            const comments = (record.Manager_Comments__c || '').toLowerCase();
            const status = (record.Status__c || '').toLowerCase();

            return (
                leaveType.includes(searchLower) ||
                comments.includes(searchLower) ||
                status.includes(searchLower)
            );
        });
    }

    get hasRecords() {
        return this.filteredLeaveRequests.length > 0;
    }

    get recordCountLabel() {
        const count = this.filteredLeaveRequests.length;
        const total = this.leaveRequests.length;
        return this.selectedStatusFilter === 'All' && !this.searchTerm
            ? `${total} Total`
            : `${count} of ${total}`;
    }

    get noRecordsMessage() {
        if (this.searchTerm || this.selectedStatusFilter !== 'All') {
            return 'No leave requests match your search and filter criteria.';
        }
        return 'You haven’t submitted any leave requests yet. Use the "Apply Leave" tab to create one.';
    }

    @api
    async refreshList() {
        this.isLoading = true;
        try {
            if (this.wiredLeaveRequestsResult) {
                await refreshApex(this.wiredLeaveRequestsResult);
            }
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleFilterChange(event) {
        this.selectedStatusFilter = event.target.value;
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'cancel') {
            const confirmed = await LightningConfirm.open({
                message: 'Are you sure you want to cancel this leave request?',
                variant: 'header',
                label: 'Confirm Cancellation'
            });

            if (!confirmed) {
                return;
            }

            this.isLoading = true;
            try {
                await cancelLeaveRequest({
                    leaveRequestId: row.Id
                });

                await refreshApex(this.wiredLeaveRequestsResult);

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Request Cancelled',
                        message: 'Leave request was cancelled successfully.',
                        variant: 'success'
                    })
                );

                this.dispatchEvent(new CustomEvent('leavecancelled', { bubbles: true, composed: true }));

            } catch (error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Cancellation Failed',
                        message: error.body?.message || error.message || 'Unable to cancel leave request.',
                        variant: 'error'
                    })
                );
            } finally {
                this.isLoading = false;
            }
        }
    }
}
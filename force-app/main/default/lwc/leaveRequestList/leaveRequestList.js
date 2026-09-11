import { LightningElement, wire, api } from 'lwc';
import getMyLeaveRequests from '@salesforce/apex/LeaveRequestController.getMyLeaveRequests';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

const COLUMNS = [
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text', initialWidth: 150 },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date', initialWidth: 120 },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date', initialWidth: 120 },
    { label: 'Days', fieldName: 'Total_Days__c', type: 'number', initialWidth: 90 },
    { label: 'Period', fieldName: 'displayPeriod', type: 'text', initialWidth: 120 },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'statusBadge',
        initialWidth: 130,
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
    const isPending = row.Status__c === 'Pending';

    // Allow cancelling future or current approved leaves
    let isFutureApproved = false;
    if (row.Status__c === 'Approved' && row.Start_Date__c) {
        const todayStr = new Date().toISOString().split('T')[0];
        isFutureApproved = row.Start_Date__c >= todayStr;
    }

    if (isPending || isFutureApproved) {
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
            this.leaveRequests = data.map(record => ({
                ...record,
                displayPeriod: record.Is_Half_Day__c ? (record.Half_Day_Period__c || 'Half Day') : 'Full Day'
            }));
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
            const period = (record.displayPeriod || '').toLowerCase();

            return (
                leaveType.includes(searchLower) ||
                comments.includes(searchLower) ||
                status.includes(searchLower) ||
                period.includes(searchLower)
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
            const isApproved = row.Status__c === 'Approved';
            let confirmMessage = 'Are you sure you want to cancel this pending leave request?';
            if (isApproved) {
                const daysText = `${row.Total_Days__c} ${row.Total_Days__c === 1 ? 'day' : 'days'}`;
                confirmMessage = row.Leave_Type__c === 'Work From Home'
                    ? 'This approved Work From Home request will be cancelled. Are you sure?'
                    : `This approved leave will be cancelled and ${daysText} will be refunded to your ${row.Leave_Type__c} balance. Are you sure?`;
            }

            const confirmed = await LightningConfirm.open({
                message: confirmMessage,
                variant: 'header',
                label: isApproved ? 'Cancel Approved Leave' : 'Confirm Cancellation'
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

                let successMsg = 'Leave request was cancelled successfully.';
                if (isApproved && row.Leave_Type__c !== 'Work From Home') {
                    const daysText = `${row.Total_Days__c} ${row.Total_Days__c === 1 ? 'day' : 'days'}`;
                    successMsg = `Leave request cancelled and ${daysText} restored to your balance.`;
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Request Cancelled',
                        message: successMsg,
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
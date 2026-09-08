import { LightningElement, wire, api } from 'lwc';
import getPendingLeaveRequests from '@salesforce/apex/LeaveRequestController.getPendingLeaveRequests';
import approveLeaveRequest from '@salesforce/apex/LeaveRequestController.approveLeaveRequest';
import rejectLeaveRequest from '@salesforce/apex/LeaveRequestController.rejectLeaveRequest';

import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import RejectLeaveModal from 'c/rejectLeaveModal';

const COLUMNS = [
    {
        label: 'Employee',
        fieldName: 'employeeName',
        type: 'text',
        initialWidth: 160
    },
    {
        label: 'Leave Type',
        fieldName: 'Leave_Type__c',
        type: 'text',
        initialWidth: 150
    },
    {
        label: 'Start Date',
        fieldName: 'Start_Date__c',
        type: 'date',
        initialWidth: 130
    },
    {
        label: 'End Date',
        fieldName: 'End_Date__c',
        type: 'date',
        initialWidth: 130
    },
    {
        label: 'Total Days',
        fieldName: 'Total_Days__c',
        type: 'number',
        initialWidth: 110
    },
    {
        label: 'Reason',
        fieldName: 'Reason__c',
        type: 'text'
    },
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
            label: 'Approve',
            name: 'approve',
            iconName: 'utility:check'
        });

        actions.push({
            label: 'Reject',
            name: 'reject',
            iconName: 'utility:close'
        });
    }

    doneCallback(actions);
}

export default class ManagerLeaveApproval extends LightningElement {
    leaveRequests = [];
    columns = COLUMNS;
    error;
    wiredPendingRequestsResult;
    searchTerm = '';
    isLoading = false;

    @wire(getPendingLeaveRequests)
    wiredPendingRequests(result) {
        this.wiredPendingRequestsResult = result;
        const { data, error } = result;

        if (data) {
            this.leaveRequests = data.map(record => ({
                ...record,
                employeeName: record.Employee__r?.Name || 'Unknown Employee'
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.leaveRequests = [];
            console.error('Pending requests wire error:', error);
        }
    }

    get filteredLeaveRequests() {
        if (!this.searchTerm) {
            return this.leaveRequests;
        }
        const lower = this.searchTerm.toLowerCase();
        return this.leaveRequests.filter(record => {
            const employee = (record.employeeName || '').toLowerCase();
            const leaveType = (record.Leave_Type__c || '').toLowerCase();
            const reason = (record.Reason__c || '').toLowerCase();
            return employee.includes(lower) || leaveType.includes(lower) || reason.includes(lower);
        });
    }

    get hasRecords() {
        return this.filteredLeaveRequests.length > 0;
    }

    get recordCountLabel() {
        const count = this.filteredLeaveRequests.length;
        const total = this.leaveRequests.length;
        return this.searchTerm ? `${count} of ${total} Pending` : `${total} Pending`;
    }

    @api
    async refreshApprovals() {
        this.isLoading = true;
        try {
            if (this.wiredPendingRequestsResult) {
                await refreshApex(this.wiredPendingRequestsResult);
            }
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        try {
            if (actionName === 'approve') {
                const confirmed = await LightningConfirm.open({
                    message: `Are you sure you want to approve this leave request for ${row.employeeName}?`,
                    label: 'Approve Leave Request',
                    variant: 'header'
                });

                if (!confirmed) {
                    return;
                }

                this.isLoading = true;
                await approveLeaveRequest({
                    leaveRequestId: row.Id
                });

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Leave Approved',
                        message: `Leave request for ${row.employeeName} approved successfully.`,
                        variant: 'success'
                    })
                );

                this.dispatchEvent(new CustomEvent('leaveapprovalprocessed', { bubbles: true, composed: true }));

            } else if (actionName === 'reject') {
                const comments = await RejectLeaveModal.open({
                    size: 'small'
                });

                if (comments === undefined) {
                    return;
                }

                this.isLoading = true;
                await rejectLeaveRequest({
                    leaveRequestId: row.Id,
                    managerComments: comments
                });

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Leave Rejected',
                        message: `Leave request for ${row.employeeName} rejected.`,
                        variant: 'success'
                    })
                );

                this.dispatchEvent(new CustomEvent('leaveapprovalprocessed', { bubbles: true, composed: true }));
            }

            await refreshApex(this.wiredPendingRequestsResult);

        } catch (error) {
            console.error('Approval/Rejection Error:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Action Failed',
                    message: error?.body?.message || error?.message || 'Failed to process the request.',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}
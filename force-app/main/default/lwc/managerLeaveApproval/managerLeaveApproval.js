import { LightningElement, wire } from 'lwc';
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
        type: 'text'
    },
    {
        label: 'Leave Type',
        fieldName: 'Leave_Type__c',
        type: 'text'
    },
    {
        label: 'Start Date',
        fieldName: 'Start_Date__c',
        type: 'date'
    },
    {
        label: 'End Date',
        fieldName: 'End_Date__c',
        type: 'date'
    },
    {
        label: 'Total Days',
        fieldName: 'Total_Days__c',
        type: 'number'
    },
    {
        label: 'Reason',
        fieldName: 'Reason__c',
        type: 'text'
    },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'text'
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                {
                    label: 'Approve',
                    name: 'approve'
                },
                {
                    label: 'Reject',
                    name: 'reject'
                }
            ]
        }
    }
];

export default class ManagerLeaveApproval extends LightningElement {

    leaveRequests = [];
    columns = COLUMNS;
    error;
    wiredPendingRequestsResult;

    @wire(getPendingLeaveRequests)
    wiredPendingRequests(result) {

        this.wiredPendingRequestsResult = result;

        const { data, error } = result;

        if (data) {

            this.leaveRequests = data.map(record => ({
                ...record,
                employeeName: record.Employee__r?.Name
            }));

            this.error = undefined;

        } else if (error) {

            this.error = error;
            this.leaveRequests = [];
        }
    }

    async handleRowAction(event) {

        const actionName = event.detail.action.name;
        const row = event.detail.row;

        try {

            if (actionName === 'approve') {

                const confirmed = await LightningConfirm.open({
                    message: 'Are you sure you want to approve this leave request?',
                    label: 'Approve Leave',
                    variant: 'header'
                });

                if (!confirmed) {
                    return;
                }

                await approveLeaveRequest({
                    leaveRequestId: row.Id
                });

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Leave request approved successfully.',
                        variant: 'success'
                    })
                );

            } else if (actionName === 'reject') {

                const comments = await RejectLeaveModal.open({
                    size: 'small'
                });
console.log('Manager Comments: ' + managerComments);
                // User closed the modal
                if (comments === undefined) {
                    return;
                }
                await rejectLeaveRequest({
                    leaveRequestId: row.Id,
                    managerComments: comments
                });

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Leave request rejected successfully.',
                        variant: 'success'
                    })
                );
            }

            await refreshApex(this.wiredPendingRequestsResult);

        } catch (error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Operation failed.',
                    variant: 'error'
                })
            );
        }
    }
}
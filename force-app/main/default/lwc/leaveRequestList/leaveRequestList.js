import { LightningElement,wire } from 'lwc';
import getMyLeaveRequests from '@salesforce/apex/LeaveRequestController.getMyLeaveRequests';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
const COLUMNS = [
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date' },
    { label: 'Total Days', fieldName: 'Total_Days__c', type: 'number' },
    {
    label: 'Status',
    fieldName: 'Status__c',
    type: 'statusBadge',
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
            label: 'Cancel',
            name: 'cancel'
        });
    }

    doneCallback(actions);
}

export default class LeaveRequestList extends LightningElement {
     columns = COLUMNS;

    leaveRequests = [];

    error;

    wiredLeaveRequestsResult;
    @wire(getMyLeaveRequests)
        wiredLeaveRequests(result) {
            this.wiredLeaveRequestsResult = result;
            const { data, error } = result;
            if (data) {
                this.leaveRequests = [...data];
                this.error=undefined;
            }
            else if (error) {
                this.error = error;
                this.leaveRequests = [];
            }
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
        
                try {
        
                    await cancelLeaveRequest({
                        leaveRequestId: row.Id
                    });
        
                    await refreshApex(this.wiredLeaveRequestsResult);
        
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Leave request cancelled successfully.',
                            variant: 'success'
                        })
                    );
        
                } catch (error) {
        
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: error.body?.message || 'Unable to cancel leave request.',
                            variant: 'error'
                        })
                    );
                }
            }
        }
        
}
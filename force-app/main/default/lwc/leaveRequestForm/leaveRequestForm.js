import { LightningElement, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';

import LEAVE_REQUEST_OBJECT from '@salesforce/schema/Leave_Request__c';
import LEAVE_TYPE_FIELD from '@salesforce/schema/Leave_Request__c.Leave_Type__c';
import NAME_FIELD from '@salesforce/schema/User.Name';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
import createLeaveRequest from '@salesforce/apex/LeaveRequestController.createLeaveRequest';
import getMyLeaveRequests from '@salesforce/apex/LeaveRequestController.getMyLeaveRequests';
import LightningConfirm from 'lightning/confirm';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeaveBalance from '@salesforce/apex/LeaveRequestController.getLeaveBalance';

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
const COLUMNS = [
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date' },
    { label: 'Total Days', fieldName: 'Total_Days__c', type: 'number' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Manager Comments', fieldName: 'Manager_Comments__c', type: 'text' },
    {
    type: 'action',
    typeAttributes: {
        rowActions: getRowActions
    }
}
];

export default class LeaveRequestForm extends LightningElement {
    
    columns = COLUMNS;
    leaveRequests = [];
    error;
    wiredLeaveRequestsResult;
    leaveBalance={Id:'',casualLeave: 0, sickLeave: 0, earnedLeave: 0};
    leaveRequest = {
        employeeId: '',
        leaveType: '',
        startDate: '',
        endDate: '',
        reason: ''
    };

 @wire(getLeaveBalance)
wiredLeaveBalance({ data, error }) {
    if (data) {
        this.leaveBalance = data;
        this.error = undefined;
        
    } else if (error) {
        this.error = error;
        this.leaveBalance = undefined;
        
    }
}
    //Get Leave records
    @wire(getMyLeaveRequests)
    wiredLeaveRequests(result) {
        this.wiredLeaveRequestsResult = result;
        const { data, error } = result;
        if (data) {
            this.leaveRequests = data;
            this.error=undefined;
        }
        else if (error) {
            this.error = error;
            this.leaveRequests = [];
        }
    }
    employeeName = '';
    leaveTypeOptions = [];

    //Get Leave Request object data
    @wire(getObjectInfo, { objectApiName: LEAVE_REQUEST_OBJECT })
    objectInfo;

    //Get Picklist values for Leave Type field
    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: LEAVE_TYPE_FIELD
    })
    wiredLeaveTypes({ data, error }) {
        if (data) {
            this.leaveTypeOptions = data.values;
        } else if (error) {
            console.error('Picklist Error:', error);
        }
    }

    // Auto population of User
    @wire(getRecord, {
        recordId: USER_ID,
        fields: [NAME_FIELD]
    })
    wiredUser({ data, error }) {
        if (data) {
            this.employeeName = data.fields.Name.value;

            this.leaveRequest = {
                ...this.leaveRequest,
                employeeId: data.id
            };
        } else if (error) {
            console.error('User Error:', error);
        }
    }

    connectedCallback() {
        console.log('Component Loaded');
    }

    handleChange(event) {
        const { name, value } = event.target;

        this.leaveRequest = {
            ...this.leaveRequest,
            [name]: value
        };
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

    async handleSubmit() {
    try {
        await createLeaveRequest({
            request: this.leaveRequest
        });

        await refreshApex(this.wiredLeaveRequestsResult);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Leave request submitted successfully.',
                variant: 'success'
            })
        );

                this.leaveRequest = {
            employeeId: this.leaveRequest.employeeId,
            leaveType: '',
            startDate: null,
            endDate: null,
            reason: ''
        };

    } catch (error) {

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Error',
            message: error.body?.message || 'Failed to submit leave request.',
            variant: 'error'
        })
    );

    console.error(error);
}
}

}
import { LightningElement, wire, api } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LEAVE_REQUEST_OBJECT from '@salesforce/schema/Leave_Request__c';
import LEAVE_TYPE_FIELD from '@salesforce/schema/Leave_Request__c.Leave_Type__c';
import NAME_FIELD from '@salesforce/schema/User.Name';
import USER_ID from '@salesforce/user/Id';
import createLeaveRequest from '@salesforce/apex/LeaveRequestController.createLeaveRequest';
import getLeaveBalance from '@salesforce/apex/LeaveRequestController.getLeaveBalance';

export default class LeaveRequestForm extends LightningElement {
    employeeName = '';
    leaveTypeOptions = [];
    leaveBalance = null;
    wiredLeaveBalanceResult;
    isSubmitting = false;
    calculatedDays = 0;

    leaveRequest = {
        employeeId: '',
        leaveType: '',
        startDate: '',
        endDate: '',
        reason: ''
    };

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

    // Leave Balance Wire
    @wire(getLeaveBalance)
    wiredBalance(result) {
        this.wiredLeaveBalanceResult = result;
        const { data, error } = result;
        if (data) {
            this.leaveBalance = data;
        } else if (error) {
            console.error('Leave Balance Error:', error);
            this.leaveBalance = null;
        }
    }

    // Get Leave Request object info for picklist
    @wire(getObjectInfo, { objectApiName: LEAVE_REQUEST_OBJECT })
    objectInfo;

    // Get Picklist values for Leave Type field
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

    get todayDate() {
        return new Date().toISOString().slice(0, 10);
    }

    get casualBalance() {
        return this.leaveBalance?.Casual_Leave__c ?? 0;
    }

    get sickBalance() {
        return this.leaveBalance?.Sick_Leave__c ?? 0;
    }

    get annualBalance() {
        return (
            this.leaveBalance?.Annual_Leave__c ??
            this.leaveBalance?.Earned_Leave__c ??
            0
        );
    }

    get durationText() {
        if (this.calculatedDays <= 0) {
            return '';
        }
        return `${this.calculatedDays} ${this.calculatedDays === 1 ? 'day' : 'days'}`;
    }

    get isDateRangeInvalid() {
        if (!this.leaveRequest.startDate || !this.leaveRequest.endDate) {
            return false;
        }
        return new Date(this.leaveRequest.startDate) > new Date(this.leaveRequest.endDate);
    }

    get isSubmitDisabled() {
        return (
            this.isSubmitting ||
            this.isDateRangeInvalid ||
            !this.leaveRequest.leaveType ||
            !this.leaveRequest.startDate ||
            !this.leaveRequest.endDate ||
            !this.leaveRequest.reason?.trim()
        );
    }

    @api
    async refreshBalance() {
        if (this.wiredLeaveBalanceResult) {
            await refreshApex(this.wiredLeaveBalanceResult);
        }
    }

    handleChange(event) {
        const { name, value } = event.target;
        this.leaveRequest = {
            ...this.leaveRequest,
            [name]: value
        };

        if (name === 'startDate' || name === 'endDate') {
            this.calculateDuration();
        }
    }

    calculateDuration() {
        if (this.leaveRequest.startDate && this.leaveRequest.endDate) {
            const start = new Date(this.leaveRequest.startDate);
            const end = new Date(this.leaveRequest.endDate);
            const diffTime = end.getTime() - start.getTime();
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
            this.calculatedDays = diffDays > 0 ? diffDays : 0;
        } else {
            this.calculatedDays = 0;
        }
    }

    handleReset() {
        this.leaveRequest = {
            employeeId: this.leaveRequest.employeeId,
            leaveType: '',
            startDate: '',
            endDate: '',
            reason: ''
        };
        this.calculatedDays = 0;
    }

    async handleSubmit() {
        const allValid = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (!allValid || this.isDateRangeInvalid) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Incomplete Form',
                    message: 'Please resolve all required fields and date errors before submitting.',
                    variant: 'warning'
                })
            );
            return;
        }

        this.isSubmitting = true;
        try {
            await createLeaveRequest({
                request: this.leaveRequest
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Application Submitted',
                    message: 'Your leave request has been submitted successfully for approval.',
                    variant: 'success'
                })
            );

            this.handleReset();

            if (this.wiredLeaveBalanceResult) {
                await refreshApex(this.wiredLeaveBalanceResult);
            }

            // Notify parent / siblings of the new leave request
            this.dispatchEvent(new CustomEvent('leaverequestcreated', { bubbles: true, composed: true }));

        } catch (error) {
            const errorMsg =
                error?.body?.message ||
                error?.message ||
                'An unexpected error occurred while submitting your leave request.';

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Submission Failed',
                    message: errorMsg,
                    variant: 'error'
                })
            );
            console.error('Leave submission error:', error);
        } finally {
            this.isSubmitting = false;
        }
    }
}
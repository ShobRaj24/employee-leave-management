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

    halfDayPeriodOptions = [
        { label: 'First Half (Morning)', value: 'First Half' },
        { label: 'Second Half (Afternoon)', value: 'Second Half' }
    ];

    leaveRequest = {
        employeeId: '',
        leaveType: '',
        startDate: '',
        endDate: '',
        reason: '',
        isHalfDay: false,
        halfDayPeriod: 'First Half'
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

    get startDateLabel() {
        return this.leaveRequest.isHalfDay ? 'Leave Date' : 'Start Date';
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
        if (this.leaveRequest.isHalfDay) {
            if (!this.leaveRequest.startDate) {
                return '';
            }
            if (this.calculatedDays <= 0) {
                return '0 working days (Weekend selected)';
            }
            return `0.5 working day (${this.leaveRequest.halfDayPeriod || 'First Half'})`;
        }
        if (this.calculatedDays <= 0) {
            return '';
        }
        return `${this.calculatedDays} working ${this.calculatedDays === 1 ? 'day' : 'days'}`;
    }

    get isDateRangeInvalid() {
        if (this.leaveRequest.isHalfDay) {
            return false;
        }
        if (!this.leaveRequest.startDate || !this.leaveRequest.endDate) {
            return false;
        }
        return new Date(this.leaveRequest.startDate) > new Date(this.leaveRequest.endDate);
    }

    get isSubmitDisabled() {
        const hasHalfDayPeriod = !this.leaveRequest.isHalfDay || !!this.leaveRequest.halfDayPeriod;
        return (
            this.isSubmitting ||
            this.isDateRangeInvalid ||
            this.calculatedDays <= 0 ||
            !this.leaveRequest.leaveType ||
            !this.leaveRequest.startDate ||
            !this.leaveRequest.endDate ||
            !hasHalfDayPeriod ||
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
        const { name, value, type, checked } = event.target;
        const fieldValue = type === 'checkbox' ? checked : value;

        this.leaveRequest = {
            ...this.leaveRequest,
            [name]: fieldValue
        };

        if (name === 'isHalfDay') {
            if (fieldValue) {
                this.leaveRequest.endDate = this.leaveRequest.startDate;
                if (!this.leaveRequest.halfDayPeriod) {
                    this.leaveRequest.halfDayPeriod = 'First Half';
                }
            }
            this.calculateDuration();
        } else if (name === 'startDate') {
            if (this.leaveRequest.isHalfDay) {
                this.leaveRequest.endDate = fieldValue;
            }
            this.calculateDuration();
        } else if (name === 'endDate' || name === 'halfDayPeriod') {
            this.calculateDuration();
        }
    }

    calculateDuration() {
        if (this.leaveRequest.isHalfDay) {
            if (this.leaveRequest.startDate) {
                const [sYear, sMonth, sDay] = this.leaveRequest.startDate.split('-').map(Number);
                const d = new Date(sYear, sMonth - 1, sDay);
                const day = d.getDay(); // 0 = Sun, 6 = Sat
                this.calculatedDays = (day === 0 || day === 6) ? 0 : 0.5;
            } else {
                this.calculatedDays = 0;
            }
            return;
        }

        if (this.leaveRequest.startDate && this.leaveRequest.endDate) {
            const [sYear, sMonth, sDay] = this.leaveRequest.startDate.split('-').map(Number);
            const [eYear, eMonth, eDay] = this.leaveRequest.endDate.split('-').map(Number);
            const start = new Date(sYear, sMonth - 1, sDay);
            const end = new Date(eYear, eMonth - 1, eDay);

            if (start > end) {
                this.calculatedDays = 0;
                return;
            }

            let workingDays = 0;
            const cur = new Date(start);
            while (cur <= end) {
                const day = cur.getDay(); // 0 = Sunday, 6 = Saturday
                if (day !== 0 && day !== 6) {
                    workingDays++;
                }
                cur.setDate(cur.getDate() + 1);
            }
            this.calculatedDays = workingDays;
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
            reason: '',
            isHalfDay: false,
            halfDayPeriod: 'First Half'
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
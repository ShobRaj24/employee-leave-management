/**
 * ============================================================================
 * Class Name : LeaveRequestValidator
 *
 * Purpose:
 *     Performs all validations related to Leave Requests before they are saved.
 *
 * Responsibilities:
 *     - Validate mandatory fields
 *     - Validate business rules
 *     - Throw meaningful exceptions when validation fails
 *
 * Notes:
 *     - This class DOES NOT perform DML.
 *     - This class DOES NOT perform SOQL.
 *     - It is reusable from LWC, Flow, Batch Apex, REST APIs, etc.
 * ============================================================================
 */
public with sharing class LeaveRequestValidator {

    /**
     * Validates a Leave Request record.
     *
     * @param leaveRequest
     *        The Leave_Request__c record received from the UI.
     *
     * @throws AuraHandledException
     *        Thrown when any validation fails.
     */
    public static void validateLeaveRequest(Leave_Request__c leaveRequest) {

        //--------------------------------------------------------------------------
        // Check whether the request itself exists.
        //--------------------------------------------------------------------------
        if (leaveRequest == null) {
            throw new AuraHandledException(
                'Leave request cannot be empty.'
            );
        }

        //--------------------------------------------------------------------------
        // Employee is mandatory.
        //--------------------------------------------------------------------------
        if (leaveRequest.Employee__c == null) {
            throw new AuraHandledException(
                'Employee is required.'
            );
        }

        //--------------------------------------------------------------------------
        // Leave Type is mandatory.
        //--------------------------------------------------------------------------
        if (String.isBlank(leaveRequest.Leave_Type__c)) {
            throw new AuraHandledException(
                'Please select a Leave Type.'
            );
        }

        //--------------------------------------------------------------------------
        // Start Date is mandatory.
        //--------------------------------------------------------------------------
        if (leaveRequest.Start_Date__c == null) {
            throw new AuraHandledException(
                'Start Date is required.'
            );
        }

        //--------------------------------------------------------------------------
        // End Date is mandatory.
        //--------------------------------------------------------------------------
        if (leaveRequest.End_Date__c == null) {
            throw new AuraHandledException(
                'End Date is required.'
            );
        }

        //--------------------------------------------------------------------------
        // Start Date cannot be after End Date.
        //--------------------------------------------------------------------------
        if (leaveRequest.Start_Date__c > leaveRequest.End_Date__c) {
            throw new AuraHandledException(
                'Start Date cannot be later than End Date.'
            );
        }

        //--------------------------------------------------------------------------
        // Reason is mandatory.
        //--------------------------------------------------------------------------
        if (String.isBlank(leaveRequest.Reason__c)) {
            throw new AuraHandledException(
                'Reason is required.'
            );
        }

    }

}
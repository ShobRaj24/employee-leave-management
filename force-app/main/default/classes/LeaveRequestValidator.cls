/**
 * ============================================================================
 * Class Name : LeaveRequestValidator
 *
 * Purpose:
 *     Performs all validations related to Leave Requests.
 * ============================================================================
 */
public with sharing class LeaveRequestValidator {

    /**
     * Validates a new leave request.
     */
    public static void validateLeaveRequest(
        Leave_Request__c leaveRequest,
        Leave_Balance__c leaveBalance
    ) {

        validateRequestExists(leaveRequest);
        validateRequiredFields(leaveRequest);
        validateDates(leaveRequest);
        validateLeaveBalance(leaveRequest, leaveBalance);
    }

    /**
     * Validates leave balance before manager approval.
     */
    public static void validateLeaveBalanceForApproval(
        Leave_Request__c leaveRequest,
        Leave_Balance__c leaveBalance
    ) {
        validateLeaveBalance(leaveRequest, leaveBalance);
    }

    /**
     * Ensures request is not null.
     */
    private static void validateRequestExists(
        Leave_Request__c leaveRequest
    ) {
        if (leaveRequest == null) {
            throw new AuraHandledException(
                'Leave request cannot be empty.'
            );
        }
    }

    /**
     * Validates mandatory fields.
     */
    private static void validateRequiredFields(
        Leave_Request__c leaveRequest
    ) {

        if (leaveRequest.Employee__c == null) {
            throw new AuraHandledException(
                'Employee is required.'
            );
        }

        if (String.isBlank(leaveRequest.Leave_Type__c)) {
            throw new AuraHandledException(
                'Please select a Leave Type.'
            );
        }

        if (leaveRequest.Start_Date__c == null) {
            throw new AuraHandledException(
                'Start Date is required.'
            );
        }

        if (leaveRequest.End_Date__c == null) {
            throw new AuraHandledException(
                'End Date is required.'
            );
        }

        if (String.isBlank(leaveRequest.Reason__c)) {
            throw new AuraHandledException(
                'Reason is required.'
            );
        }
    }

    /**
     * Validates date rules.
     */
    private static void validateDates(
        Leave_Request__c leaveRequest
    ) {

        if (leaveRequest.Start_Date__c > leaveRequest.End_Date__c) {
            throw new AuraHandledException(
                'Start Date cannot be later than End Date.'
            );
        }
    }

    /**
     * Validates available leave balance.
     */
    /**
 * Validates available leave balance.
 */
private static void validateLeaveBalance(
    Leave_Request__c leaveRequest,
    Leave_Balance__c leaveBalance
) {

    if (leaveBalance == null) {
        throw new AuraHandledException(
            'Leave balance record not found.'
        );
    }

    Decimal availableBalance;

    if (leaveRequest.Leave_Type__c == LeaveRequestConstants.CASUAL_LEAVE) {
        availableBalance = leaveBalance.Casual_Leave__c;
    }
    else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.SICK_LEAVE) {
        availableBalance = leaveBalance.Sick_Leave__c;
    }
    else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.EARNED_LEAVE) {
        availableBalance = leaveBalance.Earned_Leave__c;
    }
    else {
        throw new AuraHandledException('Invalid leave type.');
    }

    if (leaveRequest.Total_Days__c > availableBalance) {
        throw new AuraHandledException(
            'Insufficient ' +
            leaveRequest.Leave_Type__c +
            ' balance. Available: ' +
            availableBalance +
            ' day(s).'
        );
    }
}
}
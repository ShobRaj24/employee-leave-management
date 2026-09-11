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
     * Creates an AuraHandledException with the message preserved for LWC.
     */
    public static AuraHandledException createException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * Validates basic request details and dates before total days calculation.
     */
    public static void validateBasicDetails(Leave_Request__c leaveRequest) {
        validateRequestExists(leaveRequest);
        validateRequiredFields(leaveRequest);
        validateDates(leaveRequest);
        validateHalfDayRules(leaveRequest);
    }

    /**
     * Validates a complete new leave request including balance and working days.
     */
    public static void validateLeaveRequest(
        Leave_Request__c leaveRequest,
        Leave_Balance__c leaveBalance
    ) {
        validateBasicDetails(leaveRequest);
        validateWorkingDays(leaveRequest);
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
    private static void validateRequestExists(Leave_Request__c leaveRequest) {
        if (leaveRequest == null) {
            throw createException('Leave request cannot be empty.');
        }
    }

    /**
     * Validates mandatory fields.
     */
    private static void validateRequiredFields(Leave_Request__c leaveRequest) {
        if (leaveRequest.Employee__c == null) {
            throw createException('Employee is required.');
        }

        if (String.isBlank(leaveRequest.Leave_Type__c)) {
            throw createException('Please select a Leave Type.');
        }

        if (leaveRequest.Start_Date__c == null) {
            throw createException('Start Date is required.');
        }

        if (leaveRequest.End_Date__c == null) {
            throw createException('End Date is required.');
        }

        if (String.isBlank(leaveRequest.Reason__c)) {
            throw createException('Reason is required.');
        }
    }

    /**
     * Validates date rules (not in past, start <= end).
     */
    private static void validateDates(Leave_Request__c leaveRequest) {
        if (leaveRequest.Start_Date__c > leaveRequest.End_Date__c) {
            throw createException('Start Date cannot be later than End Date.');
        }

        if (leaveRequest.Start_Date__c < Date.today()) {
            throw createException('Leave cannot be requested for past dates.');
        }
    }

    /**
     * Validates half-day rules (single day constraint, period selection, working day).
     */
    private static void validateHalfDayRules(Leave_Request__c leaveRequest) {
        if (leaveRequest.Is_Half_Day__c != true) {
            return;
        }

        if (leaveRequest.Start_Date__c != leaveRequest.End_Date__c) {
            throw createException('Half-day leave must be for a single day. Start Date and End Date must be identical.');
        }

        if (String.isBlank(leaveRequest.Half_Day_Period__c) ||
            (leaveRequest.Half_Day_Period__c != LeaveRequestConstants.HALF_DAY_FIRST &&
             leaveRequest.Half_Day_Period__c != LeaveRequestConstants.HALF_DAY_SECOND)) {
            throw createException('Please select a valid half-day period (First Half or Second Half).');
        }

        if (LeaveRequestService.calculateWorkingDays(leaveRequest.Start_Date__c, leaveRequest.End_Date__c) == 0) {
            throw createException('Half-day leave cannot be taken on a weekend.');
        }
    }

    /**
     * Validates that the requested period contains at least one working day.
     */
    public static void validateWorkingDays(Leave_Request__c leaveRequest) {
        if (leaveRequest.Total_Days__c == null || leaveRequest.Total_Days__c <= 0) {
            throw createException(
                'The selected date range does not contain any working days (weekends are excluded).'
            );
        }
    }

    /**
     * Validates available leave balance.
     * Work From Home does not consume leave balance.
     */
    public static void validateLeaveBalance(
        Leave_Request__c leaveRequest,
        Leave_Balance__c leaveBalance
    ) {
        // Work From Home does not deduct from any leave balance
        if (leaveRequest.Leave_Type__c == LeaveRequestConstants.WORK_FROM_HOME) {
            return;
        }

        if (leaveBalance == null) {
            throw createException('Leave balance record not found for this employee.');
        }

        Decimal availableBalance;

        if (leaveRequest.Leave_Type__c == LeaveRequestConstants.CASUAL_LEAVE) {
            availableBalance = leaveBalance.Casual_Leave__c;
        }
        else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.SICK_LEAVE) {
            availableBalance = leaveBalance.Sick_Leave__c;
        }
        else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.EARNED_LEAVE) {
            availableBalance = leaveBalance.Annual_Leave__c;
        }
        else {
            throw createException('Invalid leave type: ' + leaveRequest.Leave_Type__c);
        }

        if (availableBalance == null || leaveRequest.Total_Days__c > availableBalance) {
            throw createException(
                'Insufficient ' +
                leaveRequest.Leave_Type__c +
                ' balance. Available: ' +
                (availableBalance != null ? availableBalance : 0) +
                ' day(s).'
            );
        }
    }
}
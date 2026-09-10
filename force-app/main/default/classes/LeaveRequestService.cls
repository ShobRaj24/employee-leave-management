/**
 * Handles business logic for Leave Requests.
 */
public with sharing class LeaveRequestService {

    /**
     * Creates an AuraHandledException with the message preserved for LWC.
     */
    public static AuraHandledException createException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * Calculates working days between two dates, excluding Saturdays and Sundays.
     */
    public static Decimal calculateWorkingDays(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || startDate > endDate) {
            return 0;
        }

        Integer workingDays = 0;
        Date cur = startDate;
        // Jan 7, 1900 was a Sunday
        Date referenceSunday = Date.newInstance(1900, 1, 7);

        while (cur <= endDate) {
            Integer dayOfWeek = Math.mod(Math.abs(referenceSunday.daysBetween(cur)), 7);
            // 0 = Sunday, 6 = Saturday
            if (dayOfWeek != 0 && dayOfWeek != 6) {
                workingDays++;
            }
            cur = cur.addDays(1);
        }
        return workingDays;
    }

    /**
     * Creates a new leave request.
     *
     * @param request Request received from the UI.
     * @return Id of the created Leave Request.
     */
    public static Id createLeaveRequest(LeaveRequestDTO request) {
        Leave_Request__c leaveRequest = mapToLeaveRequest(request);

        // Validate basic fields before computing dates to prevent NullPointerException
        LeaveRequestValidator.validateBasicDetails(leaveRequest);
        calculateTotalDays(leaveRequest);

        Leave_Balance__c leaveBalance = getLeaveBalance(leaveRequest.Employee__c);
        LeaveRequestValidator.validateLeaveRequest(leaveRequest, leaveBalance);

        checkOverlappingLeave(leaveRequest);
        applyDefaultValues(leaveRequest);
        saveLeaveRequest(leaveRequest);

        LeaveNotificationService.notifyOnSubmission(leaveRequest);

        return leaveRequest.Id;
    }

    /**
     * Returns all leave requests for the logged-in employee.
     */
    public static List<Leave_Request__c> getMyLeaveRequests() {
        return [
            SELECT
                Id,
                Leave_Type__c,
                Start_Date__c,
                End_Date__c,
                Total_Days__c,
                Status__c,
                Manager_Comments__c,
                CreatedDate
            FROM Leave_Request__c
            WHERE Employee__c = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Maps the request object to a Leave Request record.
     */
    private static Leave_Request__c mapToLeaveRequest(LeaveRequestDTO request) {
        if (request == null) {
            throw createException('Leave request cannot be empty.');
        }

        return new Leave_Request__c(
            Employee__c = request.employeeId,
            Leave_Type__c = request.leaveType,
            Start_Date__c = request.startDate,
            End_Date__c = request.endDate,
            Reason__c = request.reason
        );
    }

    /**
     * Calculates the working leave days (excluding weekends).
     */
    private static void calculateTotalDays(Leave_Request__c leaveRequest) {
        leaveRequest.Total_Days__c = calculateWorkingDays(
            leaveRequest.Start_Date__c,
            leaveRequest.End_Date__c
        );
    }

    /**
     * Applies default values before saving.
     */
    private static void applyDefaultValues(Leave_Request__c leaveRequest) {
        leaveRequest.Status__c = LeaveRequestConstants.STATUS_PENDING;
        leaveRequest.Applied_Date__c = Date.today();
    }

    /**
     * Persists the Leave Request.
     */
    private static void saveLeaveRequest(Leave_Request__c leaveRequest) {
        insert leaveRequest;
    }

    /**
     * Cancels a pending or future approved leave request.
     * Restores deducted balance if cancelling an approved leave.
     */
    public static void cancelLeaveRequest(Id leaveRequestId) {
        Leave_Request__c leaveRequest = [
            SELECT Id,
                   Employee__c,
                   Employee__r.Name,
                   Employee__r.ManagerId,
                   Leave_Type__c,
                   Start_Date__c,
                   End_Date__c,
                   Total_Days__c,
                   Status__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
            LIMIT 1
        ];

        Id currentUserId = UserInfo.getUserId();
        Boolean isOwner = (leaveRequest.Employee__c == currentUserId);
        Boolean isManager = (leaveRequest.Employee__r != null && leaveRequest.Employee__r.ManagerId == currentUserId);
        Boolean isAdmin = isSystemAdmin();

        if (!isOwner && !isManager && !isAdmin) {
            throw createException('You are not authorized to cancel this leave request.');
        }

        if (leaveRequest.Status__c == LeaveRequestConstants.STATUS_CANCELLED) {
            throw createException('This leave request is already cancelled.');
        }

        if (leaveRequest.Status__c == LeaveRequestConstants.STATUS_REJECTED) {
            throw createException('Rejected leave requests cannot be cancelled.');
        }

        List<SObject> recordsToUpdate = new List<SObject>();
        Boolean wasApproved = (leaveRequest.Status__c == LeaveRequestConstants.STATUS_APPROVED);

        if (wasApproved) {
            if (leaveRequest.Start_Date__c < Date.today()) {
                throw createException('Cannot cancel an approved leave request that has already started or is in the past.');
            }

            // Restore leave balance (WFH does not consume balance)
            if (leaveRequest.Leave_Type__c != LeaveRequestConstants.WORK_FROM_HOME) {
                Leave_Balance__c balance = getLeaveBalance(leaveRequest.Employee__c);
                if (balance != null) {
                    restoreLeaveBalance(leaveRequest, balance);
                    recordsToUpdate.add(balance);
                }
            }
        }

        leaveRequest.Status__c = LeaveRequestConstants.STATUS_CANCELLED;
        recordsToUpdate.add(leaveRequest);

        update recordsToUpdate;

        LeaveNotificationService.notifyOnCancellation(leaveRequest, wasApproved);
    }

    /**
     * Returns all pending leave requests for manager review.
     */
    public static List<Leave_Request__c> getPendingLeaveRequests() {
        Set<Id> employeeIds = getManagedEmployeeIds();
        if (employeeIds.isEmpty()) {
            return new List<Leave_Request__c>();
        }

        return [
            SELECT
                Id,
                Employee__c,
                Employee__r.Name,
                Leave_Type__c,
                Start_Date__c,
                End_Date__c,
                Total_Days__c,
                Reason__c,
                Status__c,
                Manager_Comments__c,
                CreatedDate
            FROM Leave_Request__c
            WHERE Employee__c IN :employeeIds
              AND Status__c = :LeaveRequestConstants.STATUS_PENDING
            ORDER BY CreatedDate DESC
        ];
    }

    private static Set<Id> getManagedEmployeeIds() {
        Set<Id> employeeIds = new Set<Id>();
        for (User employee : [
            SELECT Id
            FROM User
            WHERE ManagerId = :UserInfo.getUserId()
        ]) {
            employeeIds.add(employee.Id);
        }
        return employeeIds;
    }

    private static void checkOverlappingLeave(Leave_Request__c leaveRequest) {
        List<Leave_Request__c> overlappingRequests = [
            SELECT Id
            FROM Leave_Request__c
            WHERE Employee__c = :leaveRequest.Employee__c
              AND Status__c IN (
                  :LeaveRequestConstants.STATUS_PENDING,
                  :LeaveRequestConstants.STATUS_APPROVED
              )
              AND Start_Date__c <= :leaveRequest.End_Date__c
              AND End_Date__c >= :leaveRequest.Start_Date__c
            LIMIT 1
        ];

        if (!overlappingRequests.isEmpty()) {
            throw createException(
                'You already have a pending or approved leave request for some of these dates.'
            );
        }
    }

    /**
     * Approves a pending leave request.
     * Enforces manager authorization and audit trail.
     */
    public static void approveLeaveRequest(Id leaveRequestId) {
        Leave_Request__c leaveRequest = [
            SELECT Id,
                   Employee__c,
                   Employee__r.ManagerId,
                   Leave_Type__c,
                   Total_Days__c,
                   Status__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
            LIMIT 1
        ];

        validateManagerAuthorization(leaveRequest, 'approve');

        if (leaveRequest.Status__c == LeaveRequestConstants.STATUS_APPROVED) {
            throw createException('This leave request has already been approved.');
        }

        if (leaveRequest.Status__c != LeaveRequestConstants.STATUS_PENDING) {
            throw createException('Only pending leave requests can be approved.');
        }

        List<SObject> recordsToUpdate = new List<SObject>();

        // Work From Home does not consume leave balance
        if (leaveRequest.Leave_Type__c != LeaveRequestConstants.WORK_FROM_HOME) {
            Leave_Balance__c leaveBalance = getLeaveBalance(leaveRequest.Employee__c);
            LeaveRequestValidator.validateLeaveBalanceForApproval(leaveRequest, leaveBalance);
            deductLeaveBalance(leaveRequest, leaveBalance);
            recordsToUpdate.add(leaveBalance);
        }

        leaveRequest.Status__c = LeaveRequestConstants.STATUS_APPROVED;
        leaveRequest.Approved_By__c = UserInfo.getUserId();
        recordsToUpdate.add(leaveRequest);

        update recordsToUpdate;

        LeaveNotificationService.notifyOnApproval(leaveRequest);
    }

    /**
     * Rejects a pending leave request with manager comments.
     * Enforces manager authorization.
     */
    public static void rejectLeaveRequest(
        Id leaveRequestId,
        String managerComments
    ) {
        if (String.isBlank(managerComments) || String.isBlank(managerComments.trim())) {
            throw createException('Manager comments are required when rejecting a leave request.');
        }

        Leave_Request__c leaveRequest = [
            SELECT Id,
                   Employee__c,
                   Employee__r.ManagerId,
                   Status__c,
                   Manager_Comments__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
            LIMIT 1
        ];

        validateManagerAuthorization(leaveRequest, 'reject');

        if (leaveRequest.Status__c != LeaveRequestConstants.STATUS_PENDING) {
            throw createException('Only pending leave requests can be rejected.');
        }

        leaveRequest.Status__c = LeaveRequestConstants.STATUS_REJECTED;
        leaveRequest.Manager_Comments__c = managerComments.trim();

        update leaveRequest;

        LeaveNotificationService.notifyOnRejection(leaveRequest);
    }

    private static void validateManagerAuthorization(Leave_Request__c leaveRequest, String action) {
        Id currentUserId = UserInfo.getUserId();
        Id managerId = leaveRequest.Employee__r?.ManagerId;

        Boolean isManager = (managerId != null && managerId == currentUserId);
        Boolean isAdmin = isSystemAdmin();

        if (!isManager && !isAdmin) {
            throw createException(
                'You are not authorized to ' + action + ' this leave request. Only the designated manager can perform this action.'
            );
        }
    }

    private static Boolean isSystemAdmin() {
        List<User> users = [
            SELECT Profile.PermissionsModifyAllData, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (users.isEmpty()) {
            return false;
        }
        return users[0].Profile.PermissionsModifyAllData == true ||
               (users[0].Profile.Name != null && users[0].Profile.Name.contains('Admin'));
    }

    public static Leave_Balance__c getLeaveBalance() {
        return getLeaveBalance(UserInfo.getUserId());
    }

    private static Leave_Balance__c getLeaveBalance(Id employeeId) {
        List<Leave_Balance__c> balances = [
            SELECT Id,
                   Employee__c,
                   Casual_Leave__c,
                   Sick_Leave__c,
                   Annual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employeeId
            LIMIT 1
        ];

        return balances.isEmpty() ? null : balances[0];
    }

    /**
     * Deducts leave balance after approval.
     */
    private static void deductLeaveBalance(
        Leave_Request__c leaveRequest,
        Leave_Balance__c leaveBalance
    ) {
        if (leaveRequest.Leave_Type__c == LeaveRequestConstants.WORK_FROM_HOME) {
            return;
        }

        if (leaveRequest.Leave_Type__c == LeaveRequestConstants.CASUAL_LEAVE) {
            leaveBalance.Casual_Leave__c -= leaveRequest.Total_Days__c;
        }
        else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.SICK_LEAVE) {
            leaveBalance.Sick_Leave__c -= leaveRequest.Total_Days__c;
        }
        else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.EARNED_LEAVE) {
            leaveBalance.Annual_Leave__c -= leaveRequest.Total_Days__c;
        }
        else {
            throw createException('Invalid leave type: ' + leaveRequest.Leave_Type__c);
        }
    }

    /**
     * Restores leave balance after cancelling an approved leave request.
     */
    private static void restoreLeaveBalance(
        Leave_Request__c leaveRequest,
        Leave_Balance__c leaveBalance
    ) {
        if (leaveRequest.Leave_Type__c == LeaveRequestConstants.WORK_FROM_HOME) {
            return;
        }

        if (leaveRequest.Leave_Type__c == LeaveRequestConstants.CASUAL_LEAVE) {
            leaveBalance.Casual_Leave__c = (leaveBalance.Casual_Leave__c != null ? leaveBalance.Casual_Leave__c : 0) + leaveRequest.Total_Days__c;
        }
        else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.SICK_LEAVE) {
            leaveBalance.Sick_Leave__c = (leaveBalance.Sick_Leave__c != null ? leaveBalance.Sick_Leave__c : 0) + leaveRequest.Total_Days__c;
        }
        else if (leaveRequest.Leave_Type__c == LeaveRequestConstants.EARNED_LEAVE) {
            leaveBalance.Annual_Leave__c = (leaveBalance.Annual_Leave__c != null ? leaveBalance.Annual_Leave__c : 0) + leaveRequest.Total_Days__c;
        }
    }
}
 
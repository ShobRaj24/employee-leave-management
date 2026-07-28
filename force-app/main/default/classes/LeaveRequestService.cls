/**
 * Handles business logic for Leave Requests.
 */
public with sharing class LeaveRequestService {

    /**
     * Creates a new leave request.
     *
     * @param request Request received from the UI.
     * @return Id of the created Leave Request.
     */
    public static Id createLeaveRequest(LeaveRequestDTO request) {

    
    Leave_Request__c leaveRequest = mapToLeaveRequest(request);

    LeaveRequestValidator.validateLeaveRequest(leaveRequest);

    calculateTotalDays(leaveRequest);
    applyDefaultValues(leaveRequest);
    saveLeaveRequest(leaveRequest);

    return leaveRequest.Id;
}
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

        return new Leave_Request__c(
            Employee__c = request.employeeId,
            Leave_Type__c = request.leaveType,
            Start_Date__c = request.startDate,
            End_Date__c = request.endDate,
            Reason__c = request.reason
        );
    }

    /**
     * Calculates the total leave days.
     */
    private static void calculateTotalDays(Leave_Request__c leaveRequest) {

        leaveRequest.Total_Days__c =
            leaveRequest.Start_Date__c.daysBetween(leaveRequest.End_Date__c) + 1;
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

    public static void cancelLeaveRequest(Id leaveRequestId) {

    Leave_Request__c leaveRequest = [
    SELECT Id, Status__c
    FROM Leave_Request__c
    WHERE Id = :leaveRequestId
      AND Employee__c = :UserInfo.getUserId()
    LIMIT 1
];

    if (leaveRequest.Status__c != 'Pending') {
        throw new AuraHandledException(
            'Only pending leave requests can be cancelled.'
        );
    }

    leaveRequest.Status__c = 'Cancelled';
    update leaveRequest;
}
/**
 * Returns all pending leave requests for manager review.
 *
 * @return List of pending leave requests.
 */
public static List<Leave_Request__c> getPendingLeaveRequests() {

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
            CreatedDate
        FROM Leave_Request__c
        WHERE Status__c = 'Pending'
        ORDER BY CreatedDate DESC
    ];
}
/**
 * Approves a pending leave request.
 */
public static void approveLeaveRequest(Id leaveRequestId) {

    Leave_Request__c leaveRequest = [
        SELECT Id, Status__c
        FROM Leave_Request__c
        WHERE Id = :leaveRequestId
        LIMIT 1
    ];

    if (leaveRequest.Status__c != 'Pending') {
        throw new AuraHandledException(
            'Only pending leave requests can be approved.'
        );
    }

    leaveRequest.Status__c = 'Approved';

    update leaveRequest;
}

/**
 * Rejects a pending leave request.
 */
public static void rejectLeaveRequest(
    Id leaveRequestId,
    String managerComments
) {
System.debug('Manager Comments: ' + managerComments);
    Leave_Request__c leaveRequest = [
        SELECT Id, Status__c, Manager_Comments__c
        FROM Leave_Request__c
        WHERE Id = :leaveRequestId
        LIMIT 1
    ];

    if (leaveRequest.Status__c != 'Pending') {
        throw new AuraHandledException(
            'Only pending leave requests can be rejected.'
        );
    }

    leaveRequest.Status__c = 'Rejected';
    leaveRequest.Manager_Comments__c = managerComments;

    update leaveRequest;
}
}

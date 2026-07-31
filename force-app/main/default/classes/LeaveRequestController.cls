/**
 * Exposes Leave Request operations to Lightning Web Components.
 */
public with sharing class LeaveRequestController {

    /**
     * Creates a new leave request.
     *
     * @param request Leave request details from the UI.
     * @return Id of the created Leave Request.
     */
    @AuraEnabled
    public static Id createLeaveRequest(LeaveRequestDTO request) {
        return LeaveRequestService.createLeaveRequest(request);
    }

    /**
     * Returns all leave requests for the logged-in employee.
     *
     * @return List of Leave Request records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getMyLeaveRequests() {
        return LeaveRequestService.getMyLeaveRequests();
    }

    /**
 * Cancels a pending leave request.
 *
 * @param leaveRequestId Id of the leave request.
 */
@AuraEnabled
public static void cancelLeaveRequest(Id leaveRequestId) {
    LeaveRequestService.cancelLeaveRequest(leaveRequestId);
}
@AuraEnabled(cacheable=true)
public static List<Leave_Request__c> getPendingLeaveRequests() {
    return LeaveRequestService.getPendingLeaveRequests();
}

@AuraEnabled
public static void approveLeaveRequest(Id leaveRequestId) {
    LeaveRequestService.approveLeaveRequest(leaveRequestId);
}

@AuraEnabled
public static void rejectLeaveRequest(Id leaveRequestId,String managerComments) {
    LeaveRequestService.rejectLeaveRequest(leaveRequestId, managerComments);
}

@AuraEnabled(cacheable=true)
public static Leave_Balance__c getLeaveBalance() {
    return LeaveRequestService.getLeaveBalance();
}
}
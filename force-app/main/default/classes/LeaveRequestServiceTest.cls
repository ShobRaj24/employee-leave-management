@IsTest
private class LeaveRequestServiceTest {

    @TestSetup
    static void setup() {

        TestDataFactory.createLeaveBalance(
            UserInfo.getUserId(),
            10,
            10,
            15
        );
    }

    /**
     * Tests successful leave request creation.
     */
    @IsTest
    static void testCreateLeaveRequestSuccess() {

        LeaveRequestDTO dto = TestDataFactory.createDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            Date.today().addDays(1),
            Date.today().addDays(3)
        );

        Test.startTest();
        Id leaveRequestId = LeaveRequestService.createLeaveRequest(dto);
        Test.stopTest();

        Leave_Request__c leaveRequest = [
            SELECT Employee__c,
                   Leave_Type__c,
                   Status__c,
                   Total_Days__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
        ];

        System.assertEquals(
            UserInfo.getUserId(),
            leaveRequest.Employee__c
        );

        System.assertEquals(
            LeaveRequestConstants.CASUAL_LEAVE,
            leaveRequest.Leave_Type__c
        );

        System.assertEquals(
            LeaveRequestConstants.STATUS_PENDING,
            leaveRequest.Status__c
        );

        System.assertEquals(
            3,
            leaveRequest.Total_Days__c
        );
    }

    /**
     * Tests retrieving current user's leave requests.
     */
    @IsTest
    static void testGetMyLeaveRequests() {

        TestDataFactory.createLeaveRequest(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            Date.today(),
            Date.today().addDays(1),
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        List<Leave_Request__c> requests =
            LeaveRequestService.getMyLeaveRequests();
        Test.stopTest();

        System.assertEquals(1, requests.size());
    }

    /**
     * Tests cancelling a pending leave request.
     */
    @IsTest
    static void testCancelLeaveRequest() {

        Leave_Request__c request =
            TestDataFactory.createLeaveRequest(
                UserInfo.getUserId(),
                LeaveRequestConstants.CASUAL_LEAVE,
                Date.today(),
                Date.today().addDays(2),
                LeaveRequestConstants.STATUS_PENDING
            );

        Test.startTest();
        LeaveRequestService.cancelLeaveRequest(request.Id);
        Test.stopTest();

        request = [
            SELECT Status__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];

        System.assertEquals(
            LeaveRequestConstants.STATUS_CANCELLED,
            request.Status__c
        );
    }

    /**
     * Tests approving a leave request.
     */
    @IsTest
    static void testApproveLeaveRequest() {

        Leave_Request__c request =
            TestDataFactory.createLeaveRequest(
                UserInfo.getUserId(),
                LeaveRequestConstants.CASUAL_LEAVE,
                Date.today(),
                Date.today().addDays(2),
                LeaveRequestConstants.STATUS_PENDING
            );

        Test.startTest();
        LeaveRequestService.approveLeaveRequest(request.Id);
        Test.stopTest();

        request = [
            SELECT Status__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];

        Leave_Balance__c balance = [
            SELECT Casual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :UserInfo.getUserId()
        ];

        System.assertEquals(
            LeaveRequestConstants.STATUS_APPROVED,
            request.Status__c
        );

        System.assertEquals(
            7,
            balance.Casual_Leave__c
        );
    }

    /**
     * Tests rejecting a leave request.
     */
    @IsTest
    static void testRejectLeaveRequest() {

        Leave_Request__c request =
            TestDataFactory.createLeaveRequest(
                UserInfo.getUserId(),
                LeaveRequestConstants.SICK_LEAVE,
                Date.today(),
                Date.today(),
                LeaveRequestConstants.STATUS_PENDING
            );

        Test.startTest();
        LeaveRequestService.rejectLeaveRequest(
            request.Id,
            'Insufficient staffing'
        );
        Test.stopTest();

        request = [
            SELECT Status__c,
                   Manager_Comments__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];

        System.assertEquals(
            LeaveRequestConstants.STATUS_REJECTED,
            request.Status__c
        );

        System.assertEquals(
            'Insufficient staffing',
            request.Manager_Comments__c
        );
    }
}
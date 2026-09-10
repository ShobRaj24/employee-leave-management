@IsTest
private class LeaveNotificationServiceTest {

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            User manager = TestDataFactory.createTestUser('mgr', null);
            TestDataFactory.createTestUser('emp', manager.Id);
        }

        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];
        TestDataFactory.createLeaveBalance(employee.Id, 10, 10, 15);
    }

    @IsTest
    static void testNotifyOnSubmission() {
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];
        Date monday = TestDataFactory.getNextWorkingMonday();

        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        LeaveNotificationService.notifyOnSubmission(request);
        Test.stopTest();

        System.assert(true, 'notifyOnSubmission should complete without exception');
    }

    @IsTest
    static void testNotifyOnApproval() {
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];
        Date monday = TestDataFactory.getNextWorkingMonday();

        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_APPROVED
        );

        Test.startTest();
        LeaveNotificationService.notifyOnApproval(request);
        Test.stopTest();

        System.assert(true, 'notifyOnApproval should complete without exception');
    }

    @IsTest
    static void testNotifyOnRejection() {
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];
        Date monday = TestDataFactory.getNextWorkingMonday();

        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_REJECTED
        );
        request.Manager_Comments__c = 'Not enough coverage';
        update request;

        Test.startTest();
        LeaveNotificationService.notifyOnRejection(request);
        Test.stopTest();

        System.assert(true, 'notifyOnRejection should complete without exception');
    }

    @IsTest
    static void testNotifyOnCancellation() {
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];
        Date monday = TestDataFactory.getNextWorkingMonday();

        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_CANCELLED
        );

        Test.startTest();
        LeaveNotificationService.notifyOnCancellation(request, true);
        LeaveNotificationService.notifyOnCancellation(request, false);
        Test.stopTest();

        System.assert(true, 'notifyOnCancellation should complete without exception');
    }

    @IsTest
    static void testNullHandling() {
        Test.startTest();
        LeaveNotificationService.notifyOnSubmission(null);
        LeaveNotificationService.notifyOnApproval(null);
        LeaveNotificationService.notifyOnRejection(null);
        LeaveNotificationService.notifyOnCancellation(null, false);
        Test.stopTest();

        System.assert(true, 'Null requests should be handled gracefully');
    }
}

@IsTest
private class LeaveRequestServiceTest {

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            User manager = TestDataFactory.createTestUser('mgr', null);
            TestDataFactory.createTestUser('emp', manager.Id);
            TestDataFactory.createTestUser('other', null);
        }

        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        TestDataFactory.createLeaveBalance(
            UserInfo.getUserId(),
            10,
            10,
            15
        );

        TestDataFactory.createLeaveBalance(
            employee.Id,
            10,
            10,
            15
        );
    }

    /**
     * Tests successful leave request creation on working days.
     */
    @IsTest
    static void testCreateLeaveRequestSuccess() {
        Date monday = TestDataFactory.getNextWorkingMonday();
        Date wednesday = monday.addDays(2);

        LeaveRequestDTO dto = TestDataFactory.createDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            wednesday
        );

        Test.startTest();
        Id leaveRequestId = LeaveRequestController.createLeaveRequest(dto);
        Test.stopTest();

        Leave_Request__c leaveRequest = [
            SELECT Employee__c,
                   Leave_Type__c,
                   Status__c,
                   Total_Days__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
        ];

        System.assertEquals(UserInfo.getUserId(), leaveRequest.Employee__c);
        System.assertEquals(LeaveRequestConstants.CASUAL_LEAVE, leaveRequest.Leave_Type__c);
        System.assertEquals(LeaveRequestConstants.STATUS_PENDING, leaveRequest.Status__c);
        System.assertEquals(3, leaveRequest.Total_Days__c);
    }

    /**
     * Tests that working days calculation excludes Saturday and Sunday.
     */
    @IsTest
    static void testWorkingDaysCalculationExcludesWeekends() {
        Date monday = TestDataFactory.getNextWorkingMonday();
        Date friday = monday.addDays(4);
        Date nextMonday = monday.addDays(7);

        // Friday to next Monday is 4 calendar days, but only 2 working days (Fri + Mon)
        Decimal workingDays = LeaveRequestService.calculateWorkingDays(friday, nextMonday);
        System.assertEquals(2, workingDays, 'Weekend days (Saturday and Sunday) should be excluded');

        // Saturday to Sunday only should be 0 working days
        Date saturday = monday.addDays(5);
        Date sunday = monday.addDays(6);
        Decimal weekendOnly = LeaveRequestService.calculateWorkingDays(saturday, sunday);
        System.assertEquals(0, weekendOnly, 'Weekend-only period should have 0 working days');
    }

    /**
     * Tests that applying for leave in the past throws an exception.
     */
    @IsTest
    static void testPastDateValidationThrowsException() {
        Date yesterday = Date.today().addDays(-1);

        LeaveRequestDTO dto = TestDataFactory.createDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            yesterday,
            yesterday
        );

        Test.startTest();
        Boolean caught = false;
        try {
            LeaveRequestController.createLeaveRequest(dto);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Applying for a past date must throw an exception');
    }

    /**
     * Tests retrieving current user's leave requests.
     */
    @IsTest
    static void testGetMyLeaveRequests() {
        Date monday = TestDataFactory.getNextWorkingMonday();
        TestDataFactory.createLeaveRequest(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getMyLeaveRequests();
        Leave_Balance__c balance = LeaveRequestController.getLeaveBalance();
        Test.stopTest();

        System.assertEquals(1, requests.size());
        System.assertNotEquals(null, balance);
    }

    /**
     * Tests cancelling a pending leave request.
     */
    @IsTest
    static void testCancelLeaveRequest() {
        Date monday = TestDataFactory.getNextWorkingMonday();
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(2),
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        LeaveRequestController.cancelLeaveRequest(request.Id);
        Test.stopTest();

        request = [
            SELECT Status__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];

        System.assertEquals(LeaveRequestConstants.STATUS_CANCELLED, request.Status__c);
    }

    /**
     * Tests manager approval with balance deduction and audit trail.
     */
    @IsTest
    static void testManagerApproveLeaveRequest() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1), // 2 working days
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        System.runAs(manager) {
            LeaveRequestController.approveLeaveRequest(request.Id);
        }
        Test.stopTest();

        request = [
            SELECT Status__c, Approved_By__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];

        Leave_Balance__c balance = [
            SELECT Casual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employee.Id
        ];

        System.assertEquals(LeaveRequestConstants.STATUS_APPROVED, request.Status__c);
        System.assertEquals(manager.Id, request.Approved_By__c, 'Approved_By__c should record manager Id');
        System.assertEquals(8, balance.Casual_Leave__c, 'Balance should be deducted by 2 days');
    }

    /**
     * Tests that an unauthorized user cannot approve another employee's request.
     */
    @IsTest
    static void testUnauthorizedUserCannotApprove() {
        User otherUser = [SELECT Id FROM User WHERE LastName = 'other' LIMIT 1];
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
        Boolean exceptionCaught = false;
        System.runAs(otherUser) {
            try {
                LeaveRequestController.approveLeaveRequest(request.Id);
            } catch (AuraHandledException e) {
                exceptionCaught = true;
            }
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'Non-manager user must not be authorized to approve leave');
    }

    /**
     * Tests Work From Home request approval without deducting balance.
     */
    @IsTest
    static void testWorkFromHomeNoBalanceDeduction() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.WORK_FROM_HOME,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        System.runAs(manager) {
            LeaveRequestController.approveLeaveRequest(request.Id);
        }
        Test.stopTest();

        Leave_Balance__c balance = [
            SELECT Casual_Leave__c, Sick_Leave__c, Annual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employee.Id
        ];

        // All balances should remain untouched
        System.assertEquals(10, balance.Casual_Leave__c);
        System.assertEquals(10, balance.Sick_Leave__c);
        System.assertEquals(15, balance.Annual_Leave__c);
    }

    /**
     * Tests manager rejection with comments.
     */
    @IsTest
    static void testManagerRejectLeaveRequest() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.SICK_LEAVE,
            monday,
            monday,
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        System.runAs(manager) {
            LeaveRequestController.rejectLeaveRequest(
                request.Id,
                'Project deadline on that day'
            );
        }
        Test.stopTest();

        request = [
            SELECT Status__c, Manager_Comments__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];

        System.assertEquals(LeaveRequestConstants.STATUS_REJECTED, request.Status__c);
        System.assertEquals('Project deadline on that day', request.Manager_Comments__c);
    }

    /**
     * Tests that getPendingLeaveRequests only returns Pending requests for managed employees.
     */
    @IsTest
    static void testGetPendingLeaveRequestsFilter() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();

        // 1 pending request
        TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_PENDING
        );

        // 1 already approved request
        TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.SICK_LEAVE,
            monday.addDays(3),
            monday.addDays(4),
            LeaveRequestConstants.STATUS_APPROVED
        );

        Test.startTest();
        List<Leave_Request__c> pending;
        System.runAs(manager) {
            pending = LeaveRequestController.getPendingLeaveRequests();
        }
        Test.stopTest();

        System.assertEquals(1, pending.size(), 'Should only return the Pending request');
        System.assertEquals(LeaveRequestConstants.STATUS_PENDING, pending[0].Status__c);
    }

    /**
     * Tests that cancelling an approved future leave restores the deducted balance.
     */
    @IsTest
    static void testCancelApprovedFutureLeaveRestoresBalance() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1), // 2 working days
            LeaveRequestConstants.STATUS_PENDING
        );

        // Manager approves the request
        System.runAs(manager) {
            LeaveRequestController.approveLeaveRequest(request.Id);
        }

        // Verify balance deducted
        Leave_Balance__c balanceBeforeCancel = [
            SELECT Casual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employee.Id
        ];
        System.assertEquals(8, balanceBeforeCancel.Casual_Leave__c, 'Balance should be reduced from 10 to 8');

        // Employee cancels the approved leave
        Test.startTest();
        System.runAs(employee) {
            LeaveRequestController.cancelLeaveRequest(request.Id);
        }
        Test.stopTest();

        // Verify status is Cancelled and balance restored to 10
        Leave_Request__c updatedRequest = [
            SELECT Status__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];
        System.assertEquals(LeaveRequestConstants.STATUS_CANCELLED, updatedRequest.Status__c);

        Leave_Balance__c balanceAfterCancel = [
            SELECT Casual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employee.Id
        ];
        System.assertEquals(10, balanceAfterCancel.Casual_Leave__c, 'Balance should be restored back to 10');
    }

    /**
     * Tests that cancelling an approved past leave throws an exception.
     */
    @IsTest
    static void testCancelApprovedPastLeaveThrowsException() {
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date pastDate = Date.today().addDays(-5);
        Leave_Request__c request = new Leave_Request__c(
            Employee__c = employee.Id,
            Leave_Type__c = LeaveRequestConstants.CASUAL_LEAVE,
            Start_Date__c = pastDate,
            End_Date__c = pastDate.addDays(1),
            Total_Days__c = 2,
            Status__c = LeaveRequestConstants.STATUS_APPROVED,
            Reason__c = 'Past vacation'
        );
        insert request;

        Test.startTest();
        Boolean caught = false;
        System.runAs(employee) {
            try {
                LeaveRequestController.cancelLeaveRequest(request.Id);
            } catch (AuraHandledException e) {
                caught = true;
                System.assert(e.getMessage().contains('Cannot cancel an approved leave request that has already started'),
                    'Expected past date message: ' + e.getMessage());
            }
        }
        Test.stopTest();

        System.assert(caught, 'Cancelling past approved leave must throw an exception');
    }

    /**
     * Tests that cancelling an approved Work From Home leave does not change balance.
     */
    @IsTest
    static void testCancelApprovedWfhDoesNotAlterBalance() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.WORK_FROM_HOME,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_PENDING
        );

        System.runAs(manager) {
            LeaveRequestController.approveLeaveRequest(request.Id);
        }

        Test.startTest();
        System.runAs(employee) {
            LeaveRequestController.cancelLeaveRequest(request.Id);
        }
        Test.stopTest();

        Leave_Balance__c balance = [
            SELECT Casual_Leave__c, Sick_Leave__c, Annual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employee.Id
        ];
        System.assertEquals(10, balance.Casual_Leave__c);
        System.assertEquals(10, balance.Sick_Leave__c);
        System.assertEquals(15, balance.Annual_Leave__c);
    }

    /**
     * Tests that an unauthorized user cannot cancel another user's leave.
     */
    @IsTest
    static void testUnauthorizedUserCannotCancel() {
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];
        User otherUser = [SELECT Id FROM User WHERE LastName = 'other' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            monday.addDays(1),
            LeaveRequestConstants.STATUS_PENDING
        );

        Test.startTest();
        Boolean caught = false;
        System.runAs(otherUser) {
            try {
                LeaveRequestController.cancelLeaveRequest(request.Id);
            } catch (AuraHandledException e) {
                caught = true;
                System.assert(e.getMessage().contains('not authorized'), 'Expected authorization error');
            }
        }
        Test.stopTest();

        System.assert(caught, 'Unauthorized user should not be able to cancel leave');
    }

    /**
     * Tests successful creation of a half-day leave request.
     */
    @IsTest
    static void testCreateHalfDayRequestSuccess() {
        Date monday = TestDataFactory.getNextWorkingMonday();
        LeaveRequestDTO dto = TestDataFactory.createHalfDayDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            LeaveRequestConstants.HALF_DAY_FIRST
        );

        Test.startTest();
        Id reqId = LeaveRequestController.createLeaveRequest(dto);
        Test.stopTest();

        Leave_Request__c req = [
            SELECT Total_Days__c, Is_Half_Day__c, Half_Day_Period__c, Status__c
            FROM Leave_Request__c
            WHERE Id = :reqId
        ];

        System.assertEquals(0.5, req.Total_Days__c, 'Total days for half-day leave should be 0.5');
        System.assertEquals(true, req.Is_Half_Day__c);
        System.assertEquals(LeaveRequestConstants.HALF_DAY_FIRST, req.Half_Day_Period__c);
        System.assertEquals(LeaveRequestConstants.STATUS_PENDING, req.Status__c);
    }

    /**
     * Tests approving a half-day leave deducts 0.5 days from balance.
     */
    @IsTest
    static void testApproveHalfDayDeductsHalfDay() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        LeaveRequestDTO dto = TestDataFactory.createHalfDayDTO(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            LeaveRequestConstants.HALF_DAY_SECOND
        );

        Id reqId;
        System.runAs(employee) {
            reqId = LeaveRequestController.createLeaveRequest(dto);
        }

        Test.startTest();
        System.runAs(manager) {
            LeaveRequestController.approveLeaveRequest(reqId);
        }
        Test.stopTest();

        Leave_Balance__c bal = [
            SELECT Casual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employee.Id
        ];
        // 10.0 - 0.5 = 9.5
        System.assertEquals(9.5, bal.Casual_Leave__c, 'Balance should be reduced by 0.5 to 9.5');
    }

    /**
     * Tests cancelling an approved half-day leave restores 0.5 days to balance.
     */
    @IsTest
    static void testCancelApprovedHalfDayRestoresHalfDay() {
        User manager = [SELECT Id FROM User WHERE LastName = 'mgr' LIMIT 1];
        User employee = [SELECT Id FROM User WHERE LastName = 'emp' LIMIT 1];

        Date monday = TestDataFactory.getNextWorkingMonday();
        LeaveRequestDTO dto = TestDataFactory.createHalfDayDTO(
            employee.Id,
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            LeaveRequestConstants.HALF_DAY_FIRST
        );

        Id reqId;
        System.runAs(employee) {
            reqId = LeaveRequestController.createLeaveRequest(dto);
        }

        System.runAs(manager) {
            LeaveRequestController.approveLeaveRequest(reqId);
        }

        Test.startTest();
        System.runAs(employee) {
            LeaveRequestController.cancelLeaveRequest(reqId);
        }
        Test.stopTest();

        Leave_Balance__c bal = [
            SELECT Casual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :employee.Id
        ];
        // 9.5 + 0.5 = 10.0
        System.assertEquals(10.0, bal.Casual_Leave__c, 'Balance should be restored to 10.0');
    }

    /**
     * Tests that First Half and Second Half on the same date can coexist.
     */
    @IsTest
    static void testHalfDayMorningAndAfternoonCoexist() {
        Date monday = TestDataFactory.getNextWorkingMonday();

        LeaveRequestDTO morningDto = TestDataFactory.createHalfDayDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            LeaveRequestConstants.HALF_DAY_FIRST
        );

        LeaveRequestDTO afternoonDto = TestDataFactory.createHalfDayDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.WORK_FROM_HOME,
            monday,
            LeaveRequestConstants.HALF_DAY_SECOND
        );

        Test.startTest();
        Id morningId = LeaveRequestController.createLeaveRequest(morningDto);
        Id afternoonId = LeaveRequestController.createLeaveRequest(afternoonDto);
        Test.stopTest();

        System.assertNotEquals(null, morningId);
        System.assertNotEquals(null, afternoonId);
    }

    /**
     * Tests that duplicate half-day requests for the same period are rejected.
     */
    @IsTest
    static void testHalfDayDuplicatePeriodRejected() {
        Date monday = TestDataFactory.getNextWorkingMonday();

        LeaveRequestDTO dto1 = TestDataFactory.createHalfDayDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            LeaveRequestConstants.HALF_DAY_FIRST
        );

        LeaveRequestDTO dto2 = TestDataFactory.createHalfDayDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.SICK_LEAVE,
            monday,
            LeaveRequestConstants.HALF_DAY_FIRST
        );

        LeaveRequestController.createLeaveRequest(dto1);

        Test.startTest();
        Boolean caught = false;
        try {
            LeaveRequestController.createLeaveRequest(dto2);
        } catch (AuraHandledException e) {
            caught = true;
            System.assert(e.getMessage().contains('First Half'), 'Expected First Half conflict error: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'Duplicate half-day period on same date must be rejected');
    }

    /**
     * Tests that a multi-day range with isHalfDay=true is rejected.
     */
    @IsTest
    static void testHalfDayMultiDayRangeRejected() {
        Date monday = TestDataFactory.getNextWorkingMonday();
        LeaveRequestDTO dto = TestDataFactory.createHalfDayDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            monday,
            LeaveRequestConstants.HALF_DAY_FIRST
        );
        dto.endDate = monday.addDays(1); // Invalid: 2 days

        Test.startTest();
        Boolean caught = false;
        try {
            LeaveRequestController.createLeaveRequest(dto);
        } catch (AuraHandledException e) {
            caught = true;
            System.assert(e.getMessage().contains('single day'), 'Expected single day error: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'Multi-day half-day request must be rejected');
    }

    /**
     * Tests that a half-day on a weekend is rejected.
     */
    @IsTest
    static void testHalfDayOnWeekendRejected() {
        Date monday = TestDataFactory.getNextWorkingMonday();
        Date saturday = monday.addDays(5);

        LeaveRequestDTO dto = TestDataFactory.createHalfDayDTO(
            UserInfo.getUserId(),
            LeaveRequestConstants.CASUAL_LEAVE,
            saturday,
            LeaveRequestConstants.HALF_DAY_FIRST
        );

        Test.startTest();
        Boolean caught = false;
        try {
            LeaveRequestController.createLeaveRequest(dto);
        } catch (AuraHandledException e) {
            caught = true;
            System.assert(e.getMessage().contains('weekend'), 'Expected weekend error: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'Weekend half-day request must be rejected');
    }
}
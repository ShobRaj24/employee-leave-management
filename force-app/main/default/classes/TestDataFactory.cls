@IsTest
public class TestDataFactory {

    /**
     * Creates a Leave Balance record for a user.
     */
    public static Leave_Balance__c createLeaveBalance(
        Id employeeId,
        Decimal casual,
        Decimal sick,
        Decimal annual
    ) {
        Leave_Balance__c balance = new Leave_Balance__c(
            Employee__c = employeeId,
            Casual_Leave__c = casual,
            Sick_Leave__c = sick,
            Annual_Leave__c = annual
        );

        insert balance;
        return balance;
    }

    /**
     * Creates a Leave Request.
     */
    public static Leave_Request__c createLeaveRequest(
        Id employeeId,
        String leaveType,
        Date startDate,
        Date endDate,
        String status
    ) {
        Decimal workingDays = LeaveRequestService.calculateWorkingDays(startDate, endDate);

        Leave_Request__c leaveRequest = new Leave_Request__c(
            Employee__c = employeeId,
            Leave_Type__c = leaveType,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Total_Days__c = workingDays > 0 ? workingDays : 1,
            Applied_Date__c = Date.today(),
            Status__c = status,
            Reason__c = 'Vacation Leave'
        );

        insert leaveRequest;
        return leaveRequest;
    }

    /**
     * Creates a DTO for testing createLeaveRequest().
     */
    public static LeaveRequestDTO createDTO(
        Id employeeId,
        String leaveType,
        Date startDate,
        Date endDate
    ) {
        LeaveRequestDTO dto = new LeaveRequestDTO();
        dto.employeeId = employeeId;
        dto.leaveType = leaveType;
        dto.startDate = startDate;
        dto.endDate = endDate;
        dto.reason = 'Vacation Leave';
        return dto;
    }

    /**
     * Finds the next future Monday to ensure deterministic working day test ranges.
     */
    public static Date getNextWorkingMonday() {
        Date d = Date.today().addDays(1);
        Date refSunday = Date.newInstance(1900, 1, 7);
        while (Math.mod(Math.abs(refSunday.daysBetween(d)), 7) != 1) { // 1 = Monday
            d = d.addDays(1);
        }
        return d;
    }

    /**
     * Creates a test user, optionally assigning a manager, and assigns Leave Management permissions.
     */
    public static User createTestUser(String alias, Id managerId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueKey = String.valueOf(System.currentTimeMillis()) + Math.abs(Crypto.getRandomInteger());
        User u = new User(
            FirstName = 'Test',
            LastName = alias,
            Email = alias + '_' + uniqueKey + '@test.com',
            Username = alias + '_' + uniqueKey + '@testleavemgmt.org',
            Alias = alias.substring(0, Math.min(alias.length(), 8)),
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ManagerId = managerId
        );
        insert u;

        List<PermissionSet> ps = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Leave_Management_User'
            LIMIT 1
        ];
        if (!ps.isEmpty()) {
            insert new PermissionSetAssignment(
                AssigneeId = u.Id,
                PermissionSetId = ps[0].Id
            );
        }

        return u;
    }
}
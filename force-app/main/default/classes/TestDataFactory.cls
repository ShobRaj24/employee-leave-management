@IsTest
public class TestDataFactory {

    /**
     * Creates a Leave Balance record for a user.
     */
    public static Leave_Balance__c createLeaveBalance(
        Id employeeId,
        Decimal casual,
        Decimal sick,
        Decimal earned
    ) {

        Leave_Balance__c balance = new Leave_Balance__c(
            Employee__c = employeeId,
            Casual_Leave__c = casual,
            Sick_Leave__c = sick,
            Earned_Leave__c = earned
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

        Leave_Request__c leaveRequest = new Leave_Request__c(
            Employee__c = employeeId,
            Leave_Type__c = leaveType,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Total_Days__c = startDate.daysBetween(endDate) + 1,
            Applied_Date__c = Date.today(),
            Status__c = status,
            Reason__c = 'Medical Leave'
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
        dto.reason = 'Medical Leave';

        return dto;
    }
}
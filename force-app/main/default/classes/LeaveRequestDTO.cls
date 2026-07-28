public class LeaveRequestDTO {

    @AuraEnabled
    public Id employeeId { get; set; }

    @AuraEnabled
    public String leaveType { get; set; }

    @AuraEnabled
    public Date startDate { get; set; }

    @AuraEnabled
    public Date endDate { get; set; }

    @AuraEnabled
    public String reason { get; set; }
}
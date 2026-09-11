/**
 * Batch and Schedulable Apex job for year-end leave balance rollover and quota replenishment.
 *
 * Policies:
 * - Annual Leave: Rolls over unused days up to maxAnnualRollover (default: 5.0) and adds annualLeaveAllocation (default: 15.0).
 * - Casual Leave: Resets to casualLeaveAllocation (default: 12.0), no carry-forward.
 * - Sick Leave: Resets to sickLeaveAllocation (default: 10.0).
 */
public with sharing class LeaveAccrualBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    private Decimal maxAnnualRollover;
    private Decimal annualLeaveAllocation;
    private Decimal casualLeaveAllocation;
    private Decimal sickLeaveAllocation;

    public Integer recordsProcessed = 0;
    public Integer recordsFailed = 0;

    /**
     * Default constructor uses standard corporate leave policy defaults.
     */
    public LeaveAccrualBatch() {
        this(
            LeaveRequestConstants.MAX_ANNUAL_ROLLOVER,
            LeaveRequestConstants.ANNUAL_LEAVE_ALLOCATION,
            LeaveRequestConstants.CASUAL_LEAVE_ALLOCATION,
            LeaveRequestConstants.SICK_LEAVE_ALLOCATION
        );
    }

    /**
     * Parametrized constructor for customized rollover caps and allocations.
     */
    public LeaveAccrualBatch(
        Decimal maxAnnualRollover,
        Decimal annualLeaveAllocation,
        Decimal casualLeaveAllocation,
        Decimal sickLeaveAllocation
    ) {
        this.maxAnnualRollover = maxAnnualRollover != null ? maxAnnualRollover : LeaveRequestConstants.MAX_ANNUAL_ROLLOVER;
        this.annualLeaveAllocation = annualLeaveAllocation != null ? annualLeaveAllocation : LeaveRequestConstants.ANNUAL_LEAVE_ALLOCATION;
        this.casualLeaveAllocation = casualLeaveAllocation != null ? casualLeaveAllocation : LeaveRequestConstants.CASUAL_LEAVE_ALLOCATION;
        this.sickLeaveAllocation = sickLeaveAllocation != null ? sickLeaveAllocation : LeaveRequestConstants.SICK_LEAVE_ALLOCATION;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   Employee__c,
                   Casual_Leave__c,
                   Sick_Leave__c,
                   Annual_Leave__c
            FROM Leave_Balance__c
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Leave_Balance__c> scope) {
        for (Leave_Balance__c balance : scope) {
            // 1. Annual Leave rollover: max cap + new allocation
            Decimal existingAnnual = balance.Annual_Leave__c != null ? balance.Annual_Leave__c : 0;
            Decimal rolledOver = Math.max(0, Math.min(existingAnnual, this.maxAnnualRollover));
            balance.Annual_Leave__c = rolledOver + this.annualLeaveAllocation;

            // 2. Casual Leave: resets to new allocation
            balance.Casual_Leave__c = this.casualLeaveAllocation;

            // 3. Sick Leave: resets to new allocation
            balance.Sick_Leave__c = this.sickLeaveAllocation;
        }

        Database.SaveResult[] results = Database.update(scope, false);
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                recordsProcessed++;
            } else {
                recordsFailed++;
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Accrual Batch Error: ' + err.getMessage());
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'LeaveAccrualBatch finished. Processed: ' + recordsProcessed + ', Failed: ' + recordsFailed
        );
    }

    /**
     * Schedulable execute method.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LeaveAccrualBatch(), 200);
    }
}

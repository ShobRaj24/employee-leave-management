/**
 * =============================================================================
 * Class Name : LeaveRequestConstants
 *
 * Purpose:
 *     Stores all application constants used throughout the Leave Management
 *     application.
 *
 * Why use constants?
 *     - Avoid hardcoded values ("magic strings")
 *     - Easier maintenance
 *     - Better readability
 *     - Prevents typing mistakes
 *
 * Example:
 *     Instead of:
 *         leave.Status__c = 'Pending';
 *
 *     We write:
 *         leave.Status__c = LeaveRequestConstants.STATUS_PENDING;
 *
 * =============================================================================
 */
public class LeaveRequestConstants {

    /*
     * ---------------------------------------------------------
     * Leave Status Values
     * ---------------------------------------------------------
     */

    public static final String STATUS_PENDING = 'Pending';

    public static final String STATUS_APPROVED = 'Approved';

    public static final String STATUS_REJECTED = 'Rejected';

    public static final String STATUS_CANCELLED = 'Cancelled';

    /*
     * ---------------------------------------------------------
     * Leave Types
     * ---------------------------------------------------------
     */

    public static final String CASUAL_LEAVE = 'Casual Leave';

    public static final String SICK_LEAVE = 'Sick Leave';

    public static final String EARNED_LEAVE = 'Earned Leave';

    public static final String WORK_FROM_HOME = 'Work From Home';

    /*
     * ---------------------------------------------------------
     * Half Day Periods
     * ---------------------------------------------------------
     */

    public static final String HALF_DAY_FIRST = 'First Half';

    public static final String HALF_DAY_SECOND = 'Second Half';

    /*
     * ---------------------------------------------------------
     * Year-End Rollover & Accrual Policy Defaults
     * ---------------------------------------------------------
     */

    public static final Decimal MAX_ANNUAL_ROLLOVER = 5.0;

    public static final Decimal ANNUAL_LEAVE_ALLOCATION = 15.0;

    public static final Decimal CASUAL_LEAVE_ALLOCATION = 12.0;

    public static final Decimal SICK_LEAVE_ALLOCATION = 10.0;

}
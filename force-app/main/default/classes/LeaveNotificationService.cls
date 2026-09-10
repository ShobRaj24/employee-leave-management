/**
 * Service for sending Leave Management notifications via:
 * 1. In-App Bell notifications (Messaging.CustomNotification)
 * 2. Chatter FeedItem (record feed)
 * 3. SingleEmailMessage (standard email)
 *
 * All dispatches are wrapped defensively in try-catch blocks to ensure that notification
 * failures never roll back core business transactions.
 */
public with sharing class LeaveNotificationService {

    private static final String NOTIF_TYPE_DEV_NAME = 'Leave_Notification';

    /**
     * Notifies the manager when an employee submits a new leave request.
     */
    public static void notifyOnSubmission(Leave_Request__c leaveRequest) {
        if (leaveRequest == null) return;

        Leave_Request__c req = getEnrichedRequest(leaveRequest.Id);
        if (req == null || req.Employee__r?.ManagerId == null) {
            return;
        }

        Id managerId = req.Employee__r.ManagerId;
        String employeeName = req.Employee__r.Name;
        String title = 'New Leave Request: ' + employeeName;
        String body = employeeName + ' has submitted a ' + req.Leave_Type__c +
                      ' request for ' + req.Total_Days__c + ' day(s) from ' +
                      formatDate(req.Start_Date__c) + ' to ' + formatDate(req.End_Date__c) + '.' +
                      (String.isNotBlank(req.Reason__c) ? ' Reason: ' + req.Reason__c : '');

        sendNotification(title, body, req.Id, managerId);
    }

    /**
     * Notifies the employee when their leave request is approved.
     */
    public static void notifyOnApproval(Leave_Request__c leaveRequest) {
        if (leaveRequest == null) return;

        Leave_Request__c req = getEnrichedRequest(leaveRequest.Id);
        if (req == null || req.Employee__c == null) {
            return;
        }

        String approverName = UserInfo.getName();
        String title = 'Leave Request Approved';
        String body = 'Your ' + req.Leave_Type__c + ' request for ' +
                      req.Total_Days__c + ' day(s) from ' + formatDate(req.Start_Date__c) +
                      ' to ' + formatDate(req.End_Date__c) + ' was approved by ' + approverName + '.';

        sendNotification(title, body, req.Id, req.Employee__c);
    }

    /**
     * Notifies the employee when their leave request is rejected.
     */
    public static void notifyOnRejection(Leave_Request__c leaveRequest) {
        if (leaveRequest == null) return;

        Leave_Request__c req = getEnrichedRequest(leaveRequest.Id);
        if (req == null || req.Employee__c == null) {
            return;
        }

        String rejecterName = UserInfo.getName();
        String title = 'Leave Request Rejected';
        String body = 'Your ' + req.Leave_Type__c + ' request for ' +
                      req.Total_Days__c + ' day(s) from ' + formatDate(req.Start_Date__c) +
                      ' to ' + formatDate(req.End_Date__c) + ' was rejected by ' + rejecterName + '.' +
                      (String.isNotBlank(req.Manager_Comments__c) ? ' Comments: ' + req.Manager_Comments__c : '');

        sendNotification(title, body, req.Id, req.Employee__c);
    }

    /**
     * Notifies the manager when an employee cancels a leave request.
     */
    public static void notifyOnCancellation(Leave_Request__c leaveRequest, Boolean wasApproved) {
        if (leaveRequest == null) return;

        Leave_Request__c req = getEnrichedRequest(leaveRequest.Id);
        if (req == null || req.Employee__r?.ManagerId == null) {
            return;
        }

        Id managerId = req.Employee__r.ManagerId;
        String employeeName = req.Employee__r.Name;
        String priorState = wasApproved ? 'approved' : 'pending';
        String title = 'Leave Request Cancelled: ' + employeeName;
        String body = employeeName + ' cancelled their ' + priorState + ' ' + req.Leave_Type__c +
                      ' request for ' + req.Total_Days__c + ' day(s) (' +
                      formatDate(req.Start_Date__c) + ' to ' + formatDate(req.End_Date__c) + ').' +
                      (wasApproved && req.Leave_Type__c != LeaveRequestConstants.WORK_FROM_HOME ? ' Quota has been refunded.' : '');

        sendNotification(title, body, req.Id, managerId);
    }

    private static Leave_Request__c getEnrichedRequest(Id reqId) {
        if (reqId == null) return null;
        List<Leave_Request__c> listReq = [
            SELECT Id,
                   Employee__c,
                   Employee__r.Name,
                   Employee__r.ManagerId,
                   Employee__r.Manager.Name,
                   Leave_Type__c,
                   Start_Date__c,
                   End_Date__c,
                   Total_Days__c,
                   Reason__c,
                   Status__c,
                   Manager_Comments__c
            FROM Leave_Request__c
            WHERE Id = :reqId
            LIMIT 1
        ];
        return listReq.isEmpty() ? null : listReq[0];
    }

    private static void sendNotification(String title, String body, Id targetRecordId, Id recipientUserId) {
        if (recipientUserId == null) return;

        // 1. In-App Bell Notification
        sendBellNotification(title, body, targetRecordId, recipientUserId);

        // 2. Chatter Feed Item
        sendChatterPost(body, targetRecordId);

        // 3. Email Notification (wrapped safely)
        sendEmail(title, body, recipientUserId);
    }

    private static void sendBellNotification(String title, String body, Id targetRecordId, Id recipientUserId) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = :NOTIF_TYPE_DEV_NAME
                LIMIT 1
            ];
            if (!notifTypes.isEmpty()) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle(title);
                notification.setBody(body);
                notification.setNotificationTypeId(notifTypes[0].Id);
                notification.setTargetId(targetRecordId != null ? targetRecordId : recipientUserId);
                notification.send(new Set<String>{ recipientUserId });
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to send CustomNotification: ' + e.getMessage());
        }
    }

    private static void sendChatterPost(String body, Id targetRecordId) {
        if (targetRecordId == null) return;
        try {
            FeedItem post = new FeedItem();
            post.ParentId = targetRecordId;
            post.Body = body;
            insert post;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to post Chatter FeedItem: ' + e.getMessage());
        }
    }

    private static void sendEmail(String subject, String body, Id recipientUserId) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(recipientUserId);
            mail.setSaveAsActivity(false);
            mail.setSubject(subject);
            mail.setPlainTextBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to send email: ' + e.getMessage());
        }
    }

    private static String formatDate(Date d) {
        if (d == null) return '';
        return DateTime.newInstance(d.year(), d.month(), d.day()).format('yyyy-MM-dd');
    }
}

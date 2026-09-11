@IsTest
private class LeaveAccrualBatchTest {

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            User emp1 = TestDataFactory.createTestUser('empOne', null);
            User emp2 = TestDataFactory.createTestUser('empTwo', null);
        }

        User emp1 = [SELECT Id FROM User WHERE LastName = 'empOne' LIMIT 1];
        User emp2 = [SELECT Id FROM User WHERE LastName = 'empTwo' LIMIT 1];

        // emp1 has 8.0 annual leaves (should be capped at 5.0 + 15.0 = 20.0)
        TestDataFactory.createLeaveBalance(emp1.Id, 3.0, 2.0, 8.0);

        // emp2 has 2.0 annual leaves (should roll over 2.0 + 15.0 = 17.0)
        TestDataFactory.createLeaveBalance(emp2.Id, 0.0, 5.0, 2.0);
    }

    @IsTest
    static void testYearEndAccrualBatchStandardRollover() {
        Test.startTest();
        LeaveAccrualBatch batch = new LeaveAccrualBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        User emp1 = [SELECT Id FROM User WHERE LastName = 'empOne' LIMIT 1];
        User emp2 = [SELECT Id FROM User WHERE LastName = 'empTwo' LIMIT 1];

        Leave_Balance__c b1 = [
            SELECT Casual_Leave__c, Sick_Leave__c, Annual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :emp1.Id
        ];
        // 8 was capped at 5 + 15 allocation = 20
        System.assertEquals(20.0, b1.Annual_Leave__c, 'Annual leave should be capped at 5 rollover + 15 new');
        System.assertEquals(12.0, b1.Casual_Leave__c, 'Casual leave should reset to 12');
        System.assertEquals(10.0, b1.Sick_Leave__c, 'Sick leave should reset to 10');

        Leave_Balance__c b2 = [
            SELECT Casual_Leave__c, Sick_Leave__c, Annual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :emp2.Id
        ];
        // 2 + 15 allocation = 17
        System.assertEquals(17.0, b2.Annual_Leave__c, 'Annual leave should roll over 2 + 15 new');
        System.assertEquals(12.0, b2.Casual_Leave__c, 'Casual leave should reset to 12');
        System.assertEquals(10.0, b2.Sick_Leave__c, 'Sick leave should reset to 10');
    }

    @IsTest
    static void testCustomParametersConstructor() {
        User emp1 = [SELECT Id FROM User WHERE LastName = 'empOne' LIMIT 1];

        Test.startTest();
        // Custom: 10 max rollover, 20 annual, 14 casual, 12 sick
        LeaveAccrualBatch batch = new LeaveAccrualBatch(10.0, 20.0, 14.0, 12.0);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Leave_Balance__c b1 = [
            SELECT Casual_Leave__c, Sick_Leave__c, Annual_Leave__c
            FROM Leave_Balance__c
            WHERE Employee__c = :emp1.Id
        ];
        // 8 < 10 cap, so all 8 rolls over + 20 allocation = 28
        System.assertEquals(28.0, b1.Annual_Leave__c);
        System.assertEquals(14.0, b1.Casual_Leave__c);
        System.assertEquals(12.0, b1.Sick_Leave__c);
    }

    @IsTest
    static void testSchedulableExecution() {
        Test.startTest();
        String cronExp = '0 0 0 1 1 ? 2099';
        String jobId = System.schedule('TestLeaveAccrualBatchSched', cronExp, new LeaveAccrualBatch());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled successfully');
    }

    @IsTest
    static void testControllerRunBatchAsAdmin() {
        Test.startTest();
        Boolean isAdmin = LeaveRequestController.isCurrentUserAdmin();
        System.assert(isAdmin, 'Running test user should have admin privileges');

        String jobId = LeaveRequestController.runYearEndAccrualBatch();
        System.assertNotEquals(null, jobId, 'Batch job ID should be returned');
        Test.stopTest();
    }
}

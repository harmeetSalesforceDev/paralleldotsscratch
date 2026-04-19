@isTest
private class ShelfwatchSchedulerTest {
    private static List<ParallelDots__Shelfwatch_Mapping__c> createMappings(Integer count) {
        List<ParallelDots__Shelfwatch_Mapping__c> mappings = new List<ParallelDots__Shelfwatch_Mapping__c>();
        for (Integer i = 0; i < count; i++) {
            mappings.add(new ParallelDots__Shelfwatch_Mapping__c(
                Name                                  = 'Test Mapping ' + i,
                ParallelDots__Salesforce_Object__c    = 'Account',
                ParallelDots__Shelfwatch_Object__c    = 'ShelfwatchObject' + i,
                ParallelDots__Mapping_JSON__c         = '{}',
                ParallelDots__Required_Fields__c      = 'Name',
                ParallelDots__Salesforce_Fields__c    = 'Name',
                ParallelDots__Last_Sync_Time__c       = System.now()
            ));
        }
        insert mappings;
        return mappings;
    }

    @isTest
    static void testExecuteWithMappings() {
        createMappings(3);

        Test.startTest();
            ShelfwatchScheduler scheduler = new ShelfwatchScheduler();
            SchedulableContext sc         = null; 
            scheduler.execute(sc);
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status
            FROM   AsyncApexJob
            WHERE  JobType = 'BatchApex'
        ];
    }
}
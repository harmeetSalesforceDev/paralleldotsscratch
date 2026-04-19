global class ShelfwatchScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        try {
            List<ParallelDots__Shelfwatch_Mapping__c> mappings = [
                SELECT Id,
                       ParallelDots__Salesforce_Object__c,
                       ParallelDots__Shelfwatch_Object__c,
                       ParallelDots__Mapping_JSON__c,
                       ParallelDots__Required_Fields__c,
                       ParallelDots__Salesforce_Fields__c,
                       ParallelDots__Last_Sync_Time__c
                FROM   ParallelDots__Shelfwatch_Mapping__c
                WHERE  ParallelDots__Is_Auto_Active__c = true
                WITH   SECURITY_ENFORCED
                ORDER BY Name ASC
            ];

            if (!mappings.isEmpty()) {
                // Fire only the first batch — rest will chain from finish()
                ShelfWatchSyncBatch.fireNext(mappings, 0, System.now());
            }
        } catch (Exception e) {
            System.debug('ShelfwatchScheduler failed: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        }
    }
}
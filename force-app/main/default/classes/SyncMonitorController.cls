public with sharing class SyncMonitorController {

    @AuraEnabled
    public static List<Map<String,String>> getMappingOptions() {
        List<Map<String,String>> options = new List<Map<String,String>>();
        for (ParallelDots__Shelfwatch_Mapping__c m : [
            SELECT Id, Name, ParallelDots__Salesforce_Object__c, ParallelDots__Shelfwatch_Object__c
            FROM ParallelDots__Shelfwatch_Mapping__c
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
        ]) {
            options.add(new Map<String,String>{
                'label' => m.Name + ' (' + m.ParallelDots__Salesforce_Object__c + ' → ' + m.ParallelDots__Shelfwatch_Object__c + ')',
                'value' => m.Id
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<ParallelDots__Shelfwatch_Sync_Log__c> getSyncLogsByMapping(Id mappingId) {
        return [
            SELECT Id,
                   Name,
                   ParallelDots__Status__c,
                   ParallelDots__Batch_Job_Id__c,
                   ParallelDots__Start_Time__c,
                   ParallelDots__End_Time__c,
                   ParallelDots__Total_Processed__c,
                   ParallelDots__Total_Synced__c,
                   ParallelDots__Error_Messages__c
            FROM ParallelDots__Shelfwatch_Sync_Log__c
            WHERE ParallelDots__Shelfwatch_Mapping__c = :mappingId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }
}
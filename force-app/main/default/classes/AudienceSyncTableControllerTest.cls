@isTest
private class AudienceSyncTableControllerTest {
    
    private static ParallelDots__Shelfwatch_Mapping__c insertMapping(
        String shelfObject,
        String sfObject,
        Decimal unmappedFields,
        String batchJobId
    ) {
        ParallelDots__Shelfwatch_Mapping__c m = new ParallelDots__Shelfwatch_Mapping__c(
            Name                                  = shelfObject + ' Mapping',
            ParallelDots__Shelfwatch_Object__c    = shelfObject,
            ParallelDots__Salesforce_Object__c    = sfObject,
            ParallelDots__Mapping_JSON__c         = JSON.serialize(new Map<String,String>{'sf_name' => 'Name'}),
            ParallelDots__Salesforce_Fields__c    = JSON.serialize(new List<String>{'Name'}),
            ParallelDots__Required_Fields__c      = JSON.serialize(new List<String>{'Name'}),
            ParallelDots__Unmapped_Fields__c      = unmappedFields,
            ParallelDots__Last_Sync_Time__c       = System.now()
        );
        if (batchJobId != null) {
            m.ParallelDots__BatchJobId__c = batchJobId;
        }
        insert m;
        return m;
    }
    
    private static ParallelDots__Shelfwatch_Mapping__c insertMapping(String shelfObject) {
        return insertMapping(shelfObject, 'Account', 2, null);
    }
    
    @isTest
    static void testGetMappingRecords_ReturnsAllMappings() {
        insertMapping('EntityA');
        insertMapping('EntityB');
        
        Test.startTest();
        List<AudienceSyncTableController.MappingWrapper> results =
            AudienceSyncTableController.getMappingRecords();
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Result list should not be null');
        System.assert(results.size() >= 2, 'Should return at least the two inserted mappings');
    }
    
    @isTest
    static void testGetMappingRecords_NullUnmappedFieldsDefaultsToZero() {
        insertMapping('NullUnmappedEntity', 'Account', null, null);
        
        Test.startTest();
        List<AudienceSyncTableController.MappingWrapper> results =
            AudienceSyncTableController.getMappingRecords();
        Test.stopTest();
        
        AudienceSyncTableController.MappingWrapper found = null;
        for (AudienceSyncTableController.MappingWrapper w : results) {
            if (w.entityName == 'NullUnmappedEntity') {
                found = w;
                break;
            }
        }
        
        System.assertNotEquals(null, found, 'Wrapper should be found');
        System.assertEquals(0, found.unmappedFields, 'Null unmappedFields should default to 0');
    }
    
    @isTest
    static void testDeleteMapping_DeletesExistingRecord() {
        ParallelDots__Shelfwatch_Mapping__c rec = insertMapping('DeleteEntity');
        
        Test.startTest();
        AudienceSyncTableController.deleteMapping(rec.Id);
        Test.stopTest();
        
        List<ParallelDots__Shelfwatch_Mapping__c> remaining = [
            SELECT Id FROM ParallelDots__Shelfwatch_Mapping__c WHERE Id = :rec.Id
        ];
        System.assertEquals(0, remaining.size(), 'Record should be deleted');
    }
    
    /*@isTest
static void testDeleteMapping_NullIdDoesNotThrow() {
try {
Test.startTest();
AudienceSyncTableController.deleteMapping(null);
Test.stopTest();
System.assert(true, 'Null Id should return silently without exception');
} catch (Exception e) {
System.assert(false, 'Should not throw for null Id: ' + e.getMessage());
}
}*/
    
    @isTest
    static void testGetMappingById_ReturnsCorrectFields() {
        ParallelDots__Shelfwatch_Mapping__c rec = insertMapping('GetByIdEntity', 'Lead', 1, null);
        
        Test.startTest();
        Map<String,Object> result = AudienceSyncTableController.getMappingById(rec.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result map should not be null');
        System.assertEquals('Lead',          result.get('sfObject'),       'sfObject should match');
        System.assertEquals('GetByIdEntity', result.get('shelfObject'),    'shelfObject should match');
        System.assertNotEquals(null,          result.get('mappingJSON'),    'mappingJSON should not be null');
        System.assertNotEquals(null,          result.get('sfFields'),       'sfFields should not be null');
        System.assertNotEquals(null,          result.get('requiredFields'), 'requiredFields should not be null');
    }
    
    /*@isTest
static void testGetMappingById_ReturnsNullForNullId() {
Test.startTest();
Map<String,Object> result = AudienceSyncTableController.getMappingById(null);
Test.stopTest();

System.assertEquals(null, result, 'Should return null when Id is null');
}*/
    
    @isTest
    static void testSyncNow_EnqueuesBatchJob() {
        ParallelDots__Shelfwatch_Mapping__c rec = insertMapping('SyncNowEntity');
        
        Test.startTest();
        AudienceSyncTableController.syncNow(rec.Id);
        Test.stopTest();
        
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status
            FROM   AsyncApexJob
            WHERE  JobType = 'BatchApex'
        ];
        System.assert(!jobs.isEmpty(), 'A batch job should be enqueued by syncNow');
    }
    
    @isTest
    static void testUpdateAutoSync_UpdatesIsActiveField() {
        ParallelDots__Shelfwatch_Mapping__c existing = insertMapping('AutoSyncTestEntity');
        
        Test.startTest();
        AudienceSyncTableController.updateAutoSync(existing.Id, true);
        Test.stopTest();
        
        ParallelDots__Shelfwatch_Mapping__c updated = [
            SELECT ParallelDots__Is_Auto_Active__c
            FROM   ParallelDots__Shelfwatch_Mapping__c
            WHERE  Id = :existing.Id
        ];
        
        System.assertEquals(true, updated.ParallelDots__Is_Auto_Active__c, 'Is_Auto_Active should be set to true');
    }
    
}
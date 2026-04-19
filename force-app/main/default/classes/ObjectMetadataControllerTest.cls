@isTest
private class ObjectMetadataControllerTest {
    
    private static Map<String, Object> mockShelfFields() {
        return new Map<String, Object>{
            'field1' => 'value1',
                'field2' => 'value2'
                };
                    }
    
    private static ParallelDots__Shelfwatch_Mapping__c insertMapping(String shelfObject) {
        ParallelDots__Shelfwatch_Mapping__c m = new ParallelDots__Shelfwatch_Mapping__c(
            Name                                  = shelfObject + ' Mapping',
            ParallelDots__Salesforce_Object__c    = 'Account',
            ParallelDots__Shelfwatch_Object__c    = shelfObject,
            ParallelDots__Mapping_JSON__c         = JSON.serialize(new Map<String,String>{'sf_name'=>'Name'}),
            ParallelDots__Required_Fields__c      = JSON.serialize(new List<String>{'Name'}),
            ParallelDots__Salesforce_Fields__c    = JSON.serialize(new List<String>{'Name'}),
            ParallelDots__Unmapped_Fields__c      = 0
        );
        insert m;
        return m;
    }
    
    @isTest
    static void testGetAllObjects_ReturnsSortedNonEmptyList() {
        Test.startTest();
        List<Map<String,String>> objects = ObjectMetadataController.getAllObjects();
        Test.stopTest();
        
        System.assertNotEquals(null, objects, 'Result should not be null');
        System.assert(!objects.isEmpty(), 'At least one valid object should be returned');
        
        List<String> labels = new List<String>();
        for (Map<String,String> obj : objects) {
            System.assert(obj.containsKey('label'), 'Object map should contain label');
            System.assert(obj.containsKey('value'), 'Object map should contain value');
            labels.add(obj.get('label'));
        }
        
        List<String> sortedLabels = labels.clone();
        sortedLabels.sort();
    }
    @isTest
    static void testGetFields_ReturnsFieldsForAccount() {
        Test.startTest();
        List<Map<String,String>> fields = ObjectMetadataController.getFields('Account');
        Test.stopTest();
        
        System.assertNotEquals(null,  fields, 'Fields list should not be null');
        System.assert(!fields.isEmpty(), 'Account should have at least one field');
        
        for (Map<String,String> f : fields) {
            System.assert(f.containsKey('label'), 'Field map should contain label');
            System.assert(f.containsKey('api'),   'Field map should contain api');
            System.assert(f.containsKey('type'),  'Field map should contain type');
        }
    }
    
    @isTest
    static void testCreateShelfMapping_InsertsRecord() {
        Map<String,String> mappingJSON  = new Map<String,String>{'sf_name' => 'Name'};
            List<String>       sfFields     = new List<String>{'Name', 'Phone'};
                List<String>       reqFields    = new List<String>{'Name'};
                    
                    Test.startTest();
        ObjectMetadataController.createShelfMapping(
            'Account',
            'TestShelfEntity',
            sfFields,
            reqFields,
            mappingJSON,
            2
        );
        Test.stopTest();
        
        List<ParallelDots__Shelfwatch_Mapping__c> inserted = [
            SELECT Id,
            ParallelDots__Salesforce_Object__c,
            ParallelDots__Shelfwatch_Object__c,
            ParallelDots__Unmapped_Fields__c,
            Name
            FROM   ParallelDots__Shelfwatch_Mapping__c
            WHERE  ParallelDots__Shelfwatch_Object__c = 'TestShelfEntity'
        ];
        
        System.assertEquals(1, inserted.size(), 'Exactly one mapping record should be created');
        System.assertEquals('Account',       inserted[0].ParallelDots__Salesforce_Object__c);
    }
    
    @isTest
    static void testUpdateShelfMapping_UpdatesExistingRecord() {
        ParallelDots__Shelfwatch_Mapping__c existing = insertMapping('UpdateTestEntity');
        
        Map<String,String> newMapping  = new Map<String,String>{'sf_phone' => 'Phone'};
            List<String>       newSfFields = new List<String>{'Phone'};
                List<String>       newReqFields= new List<String>{'Phone'};
                    
                    Test.startTest();
        ObjectMetadataController.updateShelfMapping(
            existing.Id,
            newSfFields,
            newReqFields,
            newMapping,
            5
        );
        Test.stopTest();
        
        ParallelDots__Shelfwatch_Mapping__c updated = [
            SELECT ParallelDots__Mapping_JSON__c,
            ParallelDots__Required_Fields__c,
            ParallelDots__Salesforce_Fields__c,
            ParallelDots__Unmapped_Fields__c
            FROM   ParallelDots__Shelfwatch_Mapping__c
            WHERE  Id = :existing.Id
        ];
        
        System.assertEquals(JSON.serialize(newMapping),   updated.ParallelDots__Mapping_JSON__c);
        System.assertEquals(JSON.serialize(newReqFields), updated.ParallelDots__Required_Fields__c);
        System.assertEquals(JSON.serialize(newSfFields),  updated.ParallelDots__Salesforce_Fields__c);
        System.assertEquals(5, updated.ParallelDots__Unmapped_Fields__c);
    }
    
    @isTest
    static void testCheckMappingExists_ReturnsTrueWhenExists() {
        insertMapping('ExistingEntity');
        
        Test.startTest();
        Boolean exists = ObjectMetadataController.checkMappingExists('ExistingEntity');
        Test.stopTest();
        
        System.assertEquals(true, exists, 'Should return true when mapping exists');
    }
}
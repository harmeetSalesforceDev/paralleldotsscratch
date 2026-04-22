public with sharing class ObjectMetadataController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getAllObjects() {
        List<Map<String,String>> objects = new List<Map<String,String>>();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        for (String objName : gd.keySet()) {
            if (isValidObject(objName, gd)) {
                Schema.DescribeSObjectResult d = gd.get(objName).getDescribe();
                objects.add(new Map<String,String>{
                    'label' => d.getLabel(),      
                    'value' => d.getName()         
                });
            }
        }
        return objects;
        
    }

    private static Boolean isValidObject(String objName, Map<String, Schema.SObjectType> gd) {
        Schema.DescribeSObjectResult d = gd.get(objName).getDescribe();
        if (!d.isQueryable()) {
            return false;
        }
        if (d.isDeprecatedAndHidden()) {
            return false;
        }
        if (!d.isCreateable()) {
            return false;
        }
        if (d.getKeyPrefix() == null) {
            return false;
        }
        if (d.isCustomSetting()) {
            return false;
        }
        if (objName.endsWith('ChangeEvent')) {
            return false;
        }
        if (objName.endsWith('History')) {
            return false;
        }
        if (objName.endsWith('Share')) {
            return false;
        }
        if (objName.endsWith('Feed')) {
            return false;
        }
        return true;
    }

	@AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getFields(String objectName){

        Map<String,Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe().get(objectName)
            .getDescribe()
            .fields.getMap();

        List<Map<String,String>> fields = new List<Map<String,String>>();

        for(Schema.SObjectField f : fieldMap.values()){
            Schema.DescribeFieldResult d = f.getDescribe();
            if(d.getName() == 'Id' || d.getName() == 'IsDeleted'){
                continue;
            }
            fields.add(new Map<String,String>{
                'label' => d.getLabel(),
                'api'   => d.getName(),
                'type'  => String.valueOf(d.getType())
            });
        }

        return fields;
    }

    @AuraEnabled
    public static Map<String,Object> getShelfFields(String entity){
        return ShelfWatchApiService.handleSelectedEntity(entity);
    }

    @AuraEnabled
    public static void createShelfMapping(
        String sfObject,
        String shelfObject,
        List<String> sfFields,
        List<String> requiredFields,
        Map<String,String> mappingJSON,
        Integer unmappedCount
    ){
        ParallelDots__Shelfwatch_Mapping__c rec =
            new ParallelDots__Shelfwatch_Mapping__c();

        rec.ParallelDots__Mapping_JSON__c = JSON.serialize(mappingJSON);
        rec.ParallelDots__Required_Fields__c = JSON.serialize(requiredFields);
        rec.ParallelDots__Salesforce_Fields__c = JSON.serialize(sfFields);
        rec.ParallelDots__Salesforce_Object__c = sfObject;
        rec.ParallelDots__Shelfwatch_Object__c = shelfObject != null ? shelfObject : 'custom';
        rec.ParallelDots__Unmapped_Fields__c = unmappedCount;
        rec.Name = sfObject + ' ' + (shelfObject != null ? shelfObject : 'custom') + ' Mapping';
        rec.ParallelDots__First_Time_Mapping__c = true;

        List<SObject> sanitizedRecords =
            Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<ParallelDots__Shelfwatch_Mapping__c>{rec}
            ).getRecords();

        insert as user sanitizedRecords;
    }
    
    @AuraEnabled
    public static void updateShelfMapping(
        Id recordId,
        List<String> sfFields,
        List<String> requiredFields,
        Map<String,String> mappingJSON,
        Integer unmappedCount
    ){
        ParallelDots__Shelfwatch_Mapping__c rec = new ParallelDots__Shelfwatch_Mapping__c(Id = recordId);
        rec.ParallelDots__Mapping_JSON__c      = JSON.serialize(mappingJSON);
        rec.ParallelDots__Required_Fields__c   = JSON.serialize(requiredFields);
        rec.ParallelDots__Salesforce_Fields__c = JSON.serialize(sfFields);
        rec.ParallelDots__Unmapped_Fields__c   = unmappedCount;
        rec.ParallelDots__Last_Sync_Time__c    = null;
        rec.ParallelDots__BatchJobId__c = null;
        rec.ParallelDots__Total_Synced_Records__c     = null;
        rec.ParallelDots__Total_Processed_Records__c  = null;
        rec.ParallelDots__Sync_Status__c = null;
        rec.ParallelDots__First_Time_Mapping__c = true;

        List<SObject> sanitized =
            Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<ParallelDots__Shelfwatch_Mapping__c>{rec}
            ).getRecords();

        update as user sanitized;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkMappingExists(String shelfObject) {
        if (shelfObject == null) {
            return false;
        }
        List<ParallelDots__Shelfwatch_Mapping__c> existing = [
            SELECT Id FROM ParallelDots__Shelfwatch_Mapping__c
            WHERE ParallelDots__Shelfwatch_Object__c = :shelfObject
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return !existing.isEmpty();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getShelfObjectOptions() {
        Map<String, Object> apiRes = ShelfWatchApiService.getShelfObjectTypes();
        List<Map<String, String>> options = new List<Map<String, String>>();
        if ((Boolean) apiRes.get('isAuthorize')) {
            Map<String, Object> resultMap = (Map<String, Object>) apiRes.get('result');
            List<Object> objs = (List<Object>) resultMap.get('object_types');
            for (Object obj : objs) {
                String value = String.valueOf(obj);
                options.add(new Map<String, String>{
                    'label' => formatLabel(value),
                    'value' => value
                });
            }
        } else {
            throw new AuraHandledException((String) apiRes.get('error'));
        }
        return options;
    }

    private static String formatLabel(String apiName) {
        List<String> parts = apiName.split('_');
        for (Integer i = 0; i < parts.size(); i++) {
            parts[i] = parts[i].substring(0,1).toUpperCase() + parts[i].substring(1);
        }
        return String.join(parts, ' ');
    }
}
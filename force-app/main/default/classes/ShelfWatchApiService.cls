/** *  @description ShelfWatchApiService Working for API service the shelfwatch api */
public with sharing class ShelfWatchApiService {
    public class PayloadAttributes {
        /** * @description List<SObject> records defined  */
        @AuraEnabled
        public List<SObject> records{get;set;}
        /** * @description  Map<String, String> fieldMapping defined  */
        @AuraEnabled
        public Map<String, String> fieldMapping{get;set;}
       /** * @description List<String> entityFields defined  */
       @AuraEnabled
        public List<String> entityFields{get;set;}
       /** * @description String entity defined  */
       @AuraEnabled
        public String entity{get;set;}
        /** * @description String entity defined  */
       @AuraEnabled
        public String sObjectEntity{get;set;}
		
       @AuraEnabled
        public Boolean saveSyncTime{get;set;}
    }
    /**
     * @description Method to get the schema discovery fields for the entity
     * @param selectedEntity String
     * @return Map<String,Object>
     */
    @AuraEnabled
    public static Map<String,Object> handleSelectedEntity(String selectedEntity){
        try{
            Map<String,Object> result = new Map<String,Object>();
            if(selectedEntity != null && selectedEntity != ''){
                result = callSchemaDiscovery(selectedEntity);
            }
            return result;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
     public static Map<String,Object> exportPayloadCreation(Map<String,Object> ingestBody){
        try{
        String jsonString = JSON.serialize(ingestBody);
        System.debug('ingestBody: ' + ingestBody);
        PayloadAttributes payload = (PayloadAttributes) JSON.deserialize(jsonString, PayloadAttributes.class);
        String query = 'SELECT ' + String.join(payload.fieldMapping.values(), ',') + ' FROM ' + payload.sObjectEntity + ' LIMIT 5';
        List<SObject> users = Database.query(query);
        payload.records = users;       
            Map<String, Object> body = new Map<String, Object>{
            'object_type'       => payload.entity,
            'source'            => 'salesforce',
            'external_id_field' => 'user_id'
        };
        List<Map<String,Object>> DataPayload = new List<Map<String,Object>>();
        DataPayload = buildDynamicPayload(payload);
        body.put('records' , DataPayload);
        System.debug(JSON.serializePretty(body));
        Map<String,Object> ingestResponse = callIngestData(JSON.serialize(body) , payload.entity);
        return ingestResponse;

        }catch(Exception e){
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static List<Map<String, Object>> buildDynamicPayload(PayloadAttributes payload) {
        List<Map<String, Object>> outputList = new List<Map<String, Object>>();
        DateTime currentTime = System.now();
        String timeStamp     = currentTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        For(SObject rec : payload.records) {
            Map<String, Object> recordMap = new Map<String, Object>();
            Map<String, Object> metadata  = new Map<String, Object>();
            for (String externalField : payload.fieldMapping.keySet()) {
                String sfField = payload.fieldMapping.get(externalField);
                String value = '';
                try {
                    value = (rec.get(sfField) == null) ? '' : String.valueOf(rec.get(sfField));
                } 
                catch (Exception e) {
                    System.debug('Skipping fields : ' + sfField + ' | ' + e.getMessage());
                    continue;
                }
                
                if (payload.entityFields.contains(externalField)) {
                    recordMap.put(externalField, value);
                } else {
                    metadata.put(externalField, value);
                }
            }
        recordMap.put('external_id_field' , 'Id');
        recordMap.put('Id' , rec.get('Id'));
        recordMap.put('IsDeleted' , rec.get('IsDeleted'));
        metadata.put('timeStamp' , timeStamp);
        recordMap.put('metadata', metadata);
        outputList.add(recordMap);
        }
        return outputList;
    }
    /**
     * @description Method to get the schema discovery fields for the entity
     * @param entity String
     * @return Map<String,Object>
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private static Map<String,Object> callSchemaDiscovery(String entity) {
        ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
        Http http                                         = new Http();
        HttpRequest request                               = new HttpRequest();
        ShelfWatchAuthService.AuthResponse auth           = ShelfWatchAuthService.getAccessToken();
        Map<String,Object> responseObj                    = new Map<String,Object>();
        responseObj.put('isAuthorize' , false);
        if(!auth.isAuthorize){
            responseObj.put('errorMessage' , auth.error + ' ' + auth.message);
            return responseObj;
        }
        request.setEndpoint('callout:ShelfWatch_API/v1/ingest/schema/' + entity);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-Org-Id', shelfCred.ParallelDots__Org_Id__c);
        request.setHeader('X-Project-Id', shelfCred.ParallelDots__Project_Id__c);
        request.setHeader('Authorization', 'Bearer ' + auth.accessToken);
        HttpResponse response = http.send(request);
        Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
        if (response.getStatusCode() == 200) {
            responseObj.put('isAuthorize' , true);
            responseObj.put('result' , result);
        } else {
            responseObj.put('errorMessage' , response.getStatusCode() + ' ' + (String)result.get('message'));
        }
    System.debug(responseObj);
    return responseObj;
    }

     /**
     * @description Method to get the schema discovery fields for the entity
     * @param entity String
     * @return Map<String,Object>
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private static Map<String,Object> callIngestData(String body , String entity) {
        ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
        Http http                                         = new Http();
        HttpRequest request                               = new HttpRequest();
        ShelfWatchAuthService.AuthResponse auth           = ShelfWatchAuthService.getAccessToken();
        Map<String,Object> responseObj                    = new Map<String,Object>();
        responseObj.put('isAuthorize' , false);
        if(!auth.isAuthorize){
            responseObj.put('errorMessage' , auth.error + ' ' + auth.message);
            return responseObj;
        }
        request.setEndpoint('callout:ShelfWatch_API/v1/ingest/' + entity);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-Org-Id', shelfCred.ParallelDots__Org_Id__c);
        request.setHeader('X-Project-Id', shelfCred.ParallelDots__Project_Id__c);
        request.setHeader('Authorization', 'Bearer ' + auth.accessToken);
        request.setBody(body);
        HttpResponse response = http.send(request);
        Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
        if (response.getStatusCode() == 202) {
            System.debug(JSON.serializePretty(response.getBody()));
            responseObj.put('isAuthorize' , true);
            responseObj.put('result' , result);
        } else {
            responseObj.put('errorMessage' , response.getStatusCode() + ' ' + (String)result.get('message'));
        }
    System.debug(responseObj);
    return responseObj;
    }



}
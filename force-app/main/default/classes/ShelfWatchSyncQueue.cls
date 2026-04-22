/** *  @description ShelfWatchSyncQueue Working for API service the shelfwatch api */
public with sharing class ShelfWatchSyncQueue implements Queueable , Database.AllowsCallouts {
    /** * @description ShelfWatchApiService.PayloadAttributes payload defined  */
    private Map<String, Object> body;
    private String entity;
    private String recordId;     
    private Integer recordCount;
    private Id syncLogId;
    private String accessToken;
    /** * @description ShelfWatchSyncQueue constructor defined  */
    /*public ShelfWatchSyncQueue(Map<String, Object> body , String entity, String recordId, Integer recordCount, Id syncLogId , String accessToken) {
        this.body        = body;
        this.entity      = entity;
        this.recordId    = recordId;     
        this.recordCount = recordCount;
        this.syncLogId   = syncLogId;
        this.accessToken = accessToken;
    }*/
    private Map<String, Object> config;
    
    public ShelfWatchSyncQueue(Map<String, Object> config) {
        this.config = config;
        this.body        = (Map<String, Object>) config.get('body');
        this.entity      = (String) config.get('entity');
        this.recordId    = (String) config.get('recordId');
        this.recordCount = (Integer) config.get('recordCount');
        this.syncLogId   = (Id) config.get('syncLogId');
        this.accessToken = (String) config.get('accessToken');
    }
    public void execute(QueueableContext context) {
        Boolean apiSuccess = false;
        try {
            Map<String,Object> ingestResponse = callIngestData(JSON.serialize(body) , entity);
            apiSuccess = ingestResponse.get('isAuthorize') == true
                && ingestResponse.containsKey('result');
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }finally{
            updateSyncedCounter(apiSuccess);
        }
    }
    
    private void updateSyncedCounter(Boolean apiSuccess) {
        System.debug('apiSuccess: ' + apiSuccess + ' | recordId: ' + recordId + ' | recordCount: ' + recordCount);

        if (apiSuccess) {
            try {
                ParallelDots__Shelfwatch_Mapping__c rec = [
                    SELECT Id,
                        ParallelDots__Total_Synced_Records__c,
                        ParallelDots__Total_Processed_Records__c
                    FROM   ParallelDots__Shelfwatch_Mapping__c
                    WHERE  Id = :recordId
                    LIMIT  1
                    FOR UPDATE
                ];

                Integer existingCount = rec.ParallelDots__Total_Synced_Records__c == null
                    ? 0 : Integer.valueOf(rec.ParallelDots__Total_Synced_Records__c);

                Integer newSynced = existingCount + recordCount;
                rec.ParallelDots__Total_Synced_Records__c = newSynced;

                Integer processed = rec.ParallelDots__Total_Processed_Records__c != null
                    ? Integer.valueOf(rec.ParallelDots__Total_Processed_Records__c) : 0;

                if (processed > 0 && newSynced >= processed) {
                    rec.ParallelDots__Sync_Status__c = 'Success';
                }

                update rec;

            } catch (Exception e) {
                System.debug('Failed to update mapping synced counter: ' + e.getMessage() + ' line: ' + e.getLineNumber());
            }

            if (syncLogId != null) {
                try {
                    List<ParallelDots__Shelfwatch_Sync_Log__c> logs = [
                        SELECT Id, ParallelDots__Total_Synced__c
                        FROM   ParallelDots__Shelfwatch_Sync_Log__c
                        WHERE  Id = :syncLogId
                        LIMIT  1
                        FOR UPDATE
                    ];
                    if (!logs.isEmpty()) {
                        Integer existingLogCount = logs[0].ParallelDots__Total_Synced__c == null
                            ? 0 : Integer.valueOf(logs[0].ParallelDots__Total_Synced__c);
                        logs[0].ParallelDots__Total_Synced__c = existingLogCount + recordCount;
                        update logs[0];
                    }
                } catch (Exception e) {
                    System.debug('Failed to update sync log counter: ' + e.getMessage() + ' line: ' + e.getLineNumber());
                }
            }

        } else {

            try {
                ParallelDots__Shelfwatch_Mapping__c rec = [
                    SELECT Id,
                        ParallelDots__Total_Synced_Records__c,
                        ParallelDots__Total_Processed_Records__c,
                        ParallelDots__Sync_Status__c
                    FROM   ParallelDots__Shelfwatch_Mapping__c
                    WHERE  Id = :recordId
                    LIMIT  1
                    FOR UPDATE
                ];

                Integer synced = rec.ParallelDots__Total_Synced_Records__c != null
                    ? Integer.valueOf(rec.ParallelDots__Total_Synced_Records__c) : 0;

                String failStatus = synced > 0 ? 'Partial Success' : 'Failed';
                rec.ParallelDots__Sync_Status__c = failStatus;

                update rec;

            } catch (Exception e) {
                System.debug('Failed to update mapping failure status: ' + e.getMessage() + ' line: ' + e.getLineNumber());
            }

            if (syncLogId != null) {
                try {
                    List<ParallelDots__Shelfwatch_Sync_Log__c> logs = [
                        SELECT Id, ParallelDots__Total_Synced__c
                        FROM   ParallelDots__Shelfwatch_Sync_Log__c
                        WHERE  Id = :syncLogId
                        LIMIT  1
                        FOR UPDATE
                    ];
                    if (!logs.isEmpty()) {
                        logs[0].ParallelDots__Status__c         = 'Failed';
                        logs[0].ParallelDots__Error_Messages__c = 'API call failed for entity: ' + entity
                            + '. recordCount: ' + recordCount;
                        update logs[0];
                    }
                } catch (Exception e) {
                    System.debug('Failed to update sync log failure status: ' + e.getMessage() + ' line: ' + e.getLineNumber());
                }
            }
        }
    }

     /**
     * @description Method to get the schema discovery fields for the entity
     * @param entity String
     * @return Map<String,Object>
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private Map<String,Object> callIngestData(String body , String entity) {
        ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
        Http http                                         = new Http();
        HttpRequest request                               = new HttpRequest();
        Map<String,Object> responseObj                    = new Map<String,Object>();
        responseObj.put('isAuthorize' , false);
        request.setEndpoint('callout:ShelfWatch_API/v1/ingest/' + entity);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-Org-Id', shelfCred.ParallelDots__Org_Id__c);
        request.setHeader('X-Project-Id', shelfCred.ParallelDots__Project_Id__c);
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setTimeout(120000);
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
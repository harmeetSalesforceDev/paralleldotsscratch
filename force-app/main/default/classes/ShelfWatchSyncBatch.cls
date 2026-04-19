public class ShelfWatchSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private ShelfWatchApiService.PayloadAttributes payload;
    private Map<String, Object> params;

    // Stateful tracking variables
    private Integer totalRecordsProcessed = 0;
    private Integer totalBatchesSucceeded = 0;
    private Integer totalBatchesFailed    = 0;
    private List<String> errorMessages    = new List<String>();
    private String accessToken            = '';

    // Chain control
    private List<ParallelDots__Shelfwatch_Mapping__c> allMappings;
    private Integer currentIndex;
    private Id syncLogId;
    private String retryFromId = null;
    private DateTime syncStartTime;

    public ShelfWatchSyncBatch(Map<String, Object> config) {
        this.params       = (Map<String, Object>) config.get('params');
        this.payload      = (ShelfWatchApiService.PayloadAttributes) config.get('payload');
        this.allMappings  = (List<ParallelDots__Shelfwatch_Mapping__c>) config.get('allMappings');
        this.currentIndex = (Integer) config.get('currentIndex');
        this.accessToken  = (String) config.get('accessToken');
        this.syncStartTime = config.containsKey('syncStartTime')
                            ? (DateTime) config.get('syncStartTime')
                            : System.now();
    }

    // ── Static helper to build and fire a batch for a given index ──────────
    public static Id fireNext(List<ParallelDots__Shelfwatch_Mapping__c> mappings, Integer index, DateTime syncStartTime) {
        if (index >= mappings.size()) {
            System.debug('All mappings processed. Chaining complete.');
            return null; 
        }
        
        ParallelDots__Shelfwatch_Mapping__c mapRec = mappings[index];
        ShelfWatchApiService.PayloadAttributes payload = new ShelfWatchApiService.PayloadAttributes();
        try {
            payload.entity        = mapRec.ParallelDots__Shelfwatch_Object__c;
            payload.sObjectEntity = mapRec.ParallelDots__Salesforce_Object__c;
            payload.fieldMapping  = String.isNotBlank(mapRec.ParallelDots__Mapping_JSON__c)
                ? (Map<String, String>) JSON.deserialize(mapRec.ParallelDots__Mapping_JSON__c, Map<String, String>.class)
                : new Map<String, String>();
            payload.entityFields  = String.isNotBlank(mapRec.ParallelDots__Required_Fields__c)
                ? (List<String>) JSON.deserialize(mapRec.ParallelDots__Required_Fields__c, List<String>.class)
                : new List<String>();
            payload.records       = new List<SObject>();
            payload.saveSyncTime  = true;
            
            Boolean isFirstTime = (mapRec.ParallelDots__First_Time_Mapping__c == true);
            String query = 'SELECT IsDeleted, ' + String.join(payload.fieldMapping.values(), ', ')
                + ' FROM '  + payload.sObjectEntity
                + (isFirstTime ? '' : ' WHERE LastModifiedDate > '
                   + mapRec.ParallelDots__Last_Sync_Time__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + ' ALL ROWS') + ' ';
            
            Integer recordCount = Database.countQuery(
                'SELECT COUNT() FROM ' + payload.sObjectEntity +
                (isFirstTime ? '' : ' WHERE LastModifiedDate > ' +
                 mapRec.ParallelDots__Last_Sync_Time__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''))
            );
            
            ShelfWatchAuthService.AuthResponse auth = ShelfWatchAuthService.getAccessToken();

            
            Map<String, Object> params = new Map<String, Object>{
                'query'       => query,
                'isFirstTime' => isFirstTime,
                'recordId'    => mapRec.Id,
                'recordCount' => recordCount
            };
                        
            Map<String, Object> config = new Map<String, Object>{
                     'params'        => params,
                     'payload'       => payload,
                     'allMappings'   => mappings,
                     'currentIndex'  => index,
                     'accessToken'   => auth.accessToken,
                     'syncStartTime' => syncStartTime  
            };
                                    
            Id jobId = Database.executeBatch(new ShelfWatchSyncBatch(config), 500); 
            System.debug('Fired batch for mapping [' + mapRec.Id + '] at index: ' + index);
            return jobId; 
            
        } catch (Exception e) {
            System.debug('Failed to fire batch for index ' + index + ': ' + e.getMessage());
            return fireNext(mappings, index + 1, syncStartTime); 
        }
    }
    
    // ── Batchable interface ─────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = String.valueOf(params.get('query'));
        String mappingRecordId = String.valueOf(params.get('recordId'));
        
        Integer existingCount = [
            SELECT COUNT()
            FROM ParallelDots__Shelfwatch_Sync_Log__c
            WHERE ParallelDots__Shelfwatch_Mapping__c = :mappingRecordId
        ];
        
        try {
            ParallelDots__Shelfwatch_Sync_Log__c log = new ParallelDots__Shelfwatch_Sync_Log__c(
                //Name                                = 'Sync ' + (existingCount + 1),
                ParallelDots__Shelfwatch_Mapping__c = String.valueOf(params.get('recordId')),
                ParallelDots__Status__c             = 'In Progress',
                ParallelDots__Start_Time__c         = this.syncStartTime,
                ParallelDots__Batch_Job_Id__c       = bc.getJobId(),
                ParallelDots__Total_Processed__c    = params.containsKey('recordCount')
                                          ? (Integer) params.get('recordCount') : 0
            );
            insert log;
            this.syncLogId = log.Id;
            System.debug('this.syncLogId: '+ this.syncLogId);
        } catch (Exception e) {
            System.debug('Failed to create sync log: ' + e.getMessage());
        }
        //
        try {
            Integer expectedCount = params.containsKey('recordCount')
                            ? (Integer) params.get('recordCount') : 0;
            update new ParallelDots__Shelfwatch_Mapping__c(
                Id                                       = mappingRecordId,
                ParallelDots__Sync_Status__c             = 'In Progress',
                ParallelDots__Total_Synced_Records__c    = null,
                ParallelDots__Total_Processed_Records__c = expectedCount,
                ParallelDots__BatchJobId__c              = bc.getJobId()
            );
        } catch (Exception e) {
            System.debug('Failed to set In Progress status: ' + e.getMessage());
        }
        System.debug('ShelfWatchSyncBatch started. Job Id: ' + bc.getJobId() + ' | Index: ' + currentIndex);
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            payload.records = scope;

            Map<String, Object> body = new Map<String, Object>{
                'object_type'       => (payload.entity == 'custom') ? payload.sObjectEntity : payload.entity, 
                'source'            => 'salesforce',
                'external_id_field' => 'Id'
            };

            List<Map<String, Object>> dataPayload = ShelfWatchApiService.buildDynamicPayload(payload);
            body.put('records', dataPayload);

            System.debug(JSON.serializePretty(body));
            String recordId = String.valueOf(params.get('recordId'));
            //System.enqueueJob(new ShelfWatchSyncQueue(body, payload.entity, recordId, scope.size(), syncLogId , accessToken)); 
            Map<String, Object> queueConfig = new Map<String, Object>{
                    'body'        => body,
                    'entity'      => payload.entity,
                    'recordId'    => recordId,
                    'recordCount' => scope.size(),
                    'syncLogId'   => syncLogId,
                    'accessToken' => accessToken
            };
            System.enqueueJob(new ShelfWatchSyncQueue(queueConfig));
            totalRecordsProcessed += scope.size();
            totalBatchesSucceeded++;

        } catch (Exception e) {
            totalBatchesFailed++;
            
            payload.saveSyncTime = false;//
            
            if (this.retryFromId == null && !scope.isEmpty()) {
                this.retryFromId = (String) scope[0].get('Id');
            }
            
            String errorMsg = 'Batch chunk failed | Job Id: ' + bc.getJobId()
                            + ' | Error: ' + e.getMessage()
                            + ' | Line: '  + e.getLineNumber();
            errorMessages.add(errorMsg);
            System.debug(errorMsg);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!errorMessages.isEmpty()) {
            System.debug('------- Errors -------');
            for (String err : errorMessages) {
                System.debug(err);
            }
        }
        
        String recordId = String.valueOf(params.get('recordId'));
        
        try {
            
            ParallelDots__Shelfwatch_Mapping__c mappingUpdate = new ParallelDots__Shelfwatch_Mapping__c(
                Id                                       = recordId,
                ParallelDots__BatchJobId__c              = bc.getJobId(),
                ParallelDots__Total_Processed_Records__c = totalRecordsProcessed,
                ParallelDots__First_Time_Mapping__c      = false
            );
            
            if (errorMessages.isEmpty()) {
                mappingUpdate.ParallelDots__Last_Sync_Time__c = this.syncStartTime;
            }
            
            if (retryFromId != null) {
                mappingUpdate.ParallelDots__Retry_From_Id__c = retryFromId;
            }
            
            update mappingUpdate;
            
        } catch (Exception e) {
            System.debug('Failed to update mapping record: ' + e.getMessage());
        }
        
        if (syncLogId != null) {
            try {
                update new ParallelDots__Shelfwatch_Sync_Log__c(
                    Id                               = syncLogId,
                    ParallelDots__Status__c          = errorMessages.isEmpty() ? 'Success' : 'Failed',
                    ParallelDots__End_Time__c        = System.now(),
                    ParallelDots__Total_Processed__c = totalRecordsProcessed,
                    ParallelDots__Error_Messages__c  = errorMessages.isEmpty() ? null : String.join(errorMessages, '\n')
                );
            } catch (Exception e) {
                System.debug('Failed to update sync log: ' + e.getMessage());
            }
        }
        
        if (!errorMessages.isEmpty()) {
            try {
                ParallelDots__Shelfwatch_Mapping__c current = [
                    SELECT ParallelDots__Total_Synced_Records__c
                    FROM   ParallelDots__Shelfwatch_Mapping__c
                    WHERE  Id = :recordId
                    LIMIT  1
                ];
                
                Integer synced = current.ParallelDots__Total_Synced_Records__c != null
                    ? Integer.valueOf(current.ParallelDots__Total_Synced_Records__c) : 0;
                
                String finalStatus = synced == 0 ? 'Failed'
                    : synced == totalRecordsProcessed ? 'Success'
                        : 'In Progress';
                
                update new ParallelDots__Shelfwatch_Mapping__c(
                    Id                           = recordId,
                    ParallelDots__Sync_Status__c = finalStatus
                );
                
                
            } catch (Exception e) {
                System.debug('Failed to update final sync status: ' + e.getMessage());
            }
        }
        
        fireNext(allMappings, currentIndex + 1, syncStartTime);
    }
}
public class ShelfWatchSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private ShelfWatchApiService.PayloadAttributes payload;
    private Map<String, Object> params;

    // Stateful tracking variables
    private Integer totalRecordsProcessed = 0;
    private Integer totalBatchesSucceeded = 0;
    private Integer totalBatchesFailed    = 0;
    private List<String> errorMessages    = new List<String>();

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
            payload.isFirstTime   = mapRec.ParallelDots__First_Time_Mapping__c;
            
            Boolean isFirstTime = (mapRec.ParallelDots__First_Time_Mapping__c == true) || mapRec.ParallelDots__Last_Sync_Time__c == null;

            String query = 'SELECT IsDeleted, ' + String.join(payload.fieldMapping.values(), ', ')
                + ' FROM '  + payload.sObjectEntity
                + (isFirstTime ? '' : ' WHERE LastModifiedDate > '
                   + mapRec.ParallelDots__Last_Sync_Time__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + ' ALL ROWS') + ' ';
            
            Integer recordCount = Database.countQuery(
                'SELECT COUNT() FROM ' + payload.sObjectEntity +
                (isFirstTime ? '' : ' WHERE LastModifiedDate > ' +
                 mapRec.ParallelDots__Last_Sync_Time__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''))
            );
            

            Map<String,Object> fieldMapClone = new Map<String,Object>();
            for (String externalField : payload.fieldMapping.keySet()) {
                fieldMapClone.put(externalField , '');
            }

            payload.fieldMappingClone = fieldMapClone;

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
                     'syncStartTime' => syncStartTime
            };
                                    
            Id jobId = Database.executeBatch(new ShelfWatchSyncBatch(config), 200); 
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
                ParallelDots__BatchJobId__c              = bc.getJobId(),
                ParallelDots__API_Fail__c                = false
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
                'external_id_field' => 'Id',
                'insert_only'       => payload.isFirstTime
            };

            List<Map<String, Object>> dataPayload = ShelfWatchApiService.buildDynamicPayload(payload);
            body.put('records', dataPayload);

            //System.debug(JSON.serializePretty(body));
            String recordId = String.valueOf(params.get('recordId'));
            Map<String, Object> queueConfig = new Map<String, Object>{
                    'body'        => body,
                    'entity'      => payload.entity,
                    'recordId'    => recordId,
                    'recordCount' => scope.size(),
                    'syncLogId'   => syncLogId
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
            
            ParallelDots__Shelfwatch_Mapping__c currentRec = [
                SELECT ParallelDots__API_Fail__c
                FROM   ParallelDots__Shelfwatch_Mapping__c
                WHERE  Id = :recordId LIMIT 1
            ];
            Boolean apiFailed = currentRec.ParallelDots__API_Fail__c == true;

            if (errorMessages.isEmpty() && !apiFailed) {
                mappingUpdate.ParallelDots__Last_Sync_Time__c = this.syncStartTime;
                mappingUpdate.ParallelDots__Sync_Status__c    = 'Success';
                mappingUpdate.ParallelDots__Retry_From_Id__c  = null;
            } else if (apiFailed) {
                mappingUpdate.ParallelDots__Sync_Status__c = 'Failed';
            } else {
                if (retryFromId != null) {
                    mappingUpdate.ParallelDots__Retry_From_Id__c = retryFromId;
                }
                String finalStatus = totalRecordsProcessed == 0 ? 'Failed' : 'Partial Success';
                    mappingUpdate.ParallelDots__Sync_Status__c = finalStatus;
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
        
        fireNext(allMappings, currentIndex + 1, syncStartTime);
    }
}
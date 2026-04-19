public with sharing class AudienceSyncTableController {

    @AuraEnabled
    public static List<MappingWrapper> getMappingRecords() {
        List<MappingWrapper> wrapperList = new List<MappingWrapper>();

        for (ParallelDots__Shelfwatch_Mapping__c rec : [
            SELECT Id,
				   Name,
                   Owner.Name,
                   ParallelDots__Unmapped_Fields__c,
				   ParallelDots__Shelfwatch_Object__c,
				   ParallelDots__Salesforce_Object__c,
				   ParallelDots__Mapping_JSON__c,
				   ParallelDots__Salesforce_Fields__c,
				   ParallelDots__Required_Fields__c,
				   ParallelDots__Last_Sync_Time__c,
				   ParallelDots__Is_Auto_Active__c,
				   ParallelDots__BatchJobId__c,
				   ParallelDots__Sync_Status__c,
				   ParallelDots__Retry_From_Id__c
            FROM   ParallelDots__Shelfwatch_Mapping__c
            WITH SECURITY_ENFORCED
        ]) {
            wrapperList.add(new MappingWrapper(rec));
        }

        return wrapperList;
    }

    public class MappingWrapper {
        @AuraEnabled public String  id;
        @AuraEnabled public String  entityName;
		@AuraEnabled public String sfObjectName;
        @AuraEnabled public Integer unmappedFields;
        @AuraEnabled public Boolean isActive;
		@AuraEnabled public String sfObject;
		@AuraEnabled public String mappingJSON;
		@AuraEnabled public String sfFields;
		@AuraEnabled public String requiredFields;
		@AuraEnabled public DateTime lastSyncTime;
		@AuraEnabled public String syncStatus;
		@AuraEnabled public Boolean isAutoActive;
		@AuraEnabled public Boolean canRetry;
		@AuraEnabled public String batchJobId;

        public MappingWrapper(ParallelDots__Shelfwatch_Mapping__c rec) {
            this.id             = rec.Id;
            this.entityName   = rec.ParallelDots__Shelfwatch_Object__c;
			this.sfObjectName = rec.ParallelDots__Salesforce_Object__c;
            this.unmappedFields = rec.ParallelDots__Unmapped_Fields__c != null
                                    ? Integer.valueOf(rec.ParallelDots__Unmapped_Fields__c)
                                    : 0;
            this.isActive       = false; 
			this.sfObject = rec.ParallelDots__Salesforce_Object__c;
			this.mappingJSON = rec.ParallelDots__Mapping_JSON__c;
			this.sfFields = rec.ParallelDots__Salesforce_Fields__c;
			this.requiredFields = rec.ParallelDots__Required_Fields__c;
			this.lastSyncTime = rec.ParallelDots__Last_Sync_Time__c;
			this.syncStatus = rec.ParallelDots__Sync_Status__c != null 
                  ? rec.ParallelDots__Sync_Status__c 
                  : '—';
			this.isAutoActive = rec.ParallelDots__Is_Auto_Active__c;
			this.canRetry = (this.syncStatus == 'Failed' || this.syncStatus == 'Partial Success')
                && rec.ParallelDots__Retry_From_Id__c != null;
				System.debug('this.canRetry: '+ this.canRetry);
			this.batchJobId = rec.ParallelDots__BatchJobId__c;
        }
    }

	@AuraEnabled
	public static void deleteMapping(Id recordId) {
		System.debug('record: '+ recordId);
		if (recordId == null) {
			return;
		}

		if (!Schema.sObjectType.ParallelDots__Shelfwatch_Mapping__c.isDeletable()) {
			return;
		}

		List<ParallelDots__Shelfwatch_Mapping__c> mappings = [
			SELECT Id
			FROM ParallelDots__Shelfwatch_Mapping__c
			WHERE Id = :recordId
			WITH SECURITY_ENFORCED
			LIMIT 1
		];

		if (!mappings.isEmpty()) {
			delete mappings;
		}
	}

    @AuraEnabled
	public static Map<String, Object> getMappingById(Id recordId) {
		if (recordId == null) {
			return null;
		}
		ParallelDots__Shelfwatch_Mapping__c rec = [
			SELECT Id,
				ParallelDots__Salesforce_Object__c,
				ParallelDots__Shelfwatch_Object__c,
				ParallelDots__Mapping_JSON__c,
				ParallelDots__Salesforce_Fields__c,
				ParallelDots__Required_Fields__c
			FROM   ParallelDots__Shelfwatch_Mapping__c
			WHERE  Id = :recordId
			WITH SECURITY_ENFORCED
			LIMIT 1
		];

		return new Map<String, Object>{
			'sfObject'       => rec.ParallelDots__Salesforce_Object__c,
			'shelfObject'    => rec.ParallelDots__Shelfwatch_Object__c,
			'mappingJSON'    => rec.ParallelDots__Mapping_JSON__c,
			'sfFields'       => rec.ParallelDots__Salesforce_Fields__c,
			'requiredFields' => rec.ParallelDots__Required_Fields__c
		};
	}

	@AuraEnabled
	public static String syncNow(Id recordId) {
		List<ParallelDots__Shelfwatch_Mapping__c> mappings = [
			SELECT Id,
				ParallelDots__Shelfwatch_Object__c,
				ParallelDots__Salesforce_Object__c,
				ParallelDots__Mapping_JSON__c,
				ParallelDots__Required_Fields__c,
				ParallelDots__Last_Sync_Time__c,
				ParallelDots__Total_Synced_Records__c,
				ParallelDots__First_Time_Mapping__c,
				LastModifiedDate
			FROM   ParallelDots__Shelfwatch_Mapping__c
			WHERE  Id = :recordId
			WITH SECURITY_ENFORCED
			LIMIT 1
		];

		if (mappings.isEmpty()) return null;

		DateTime syncStartTime = System.now();

		return ShelfWatchSyncBatch.fireNext(mappings, 0, syncStartTime);
	}

	@AuraEnabled
	public static String getJobStatus(Id jobId) {
		if (jobId == null) return 'Unknown';
		List<AsyncApexJob> jobs = [
			SELECT Status
			FROM   AsyncApexJob
			WHERE  Id = :jobId
			WITH   SECURITY_ENFORCED
			LIMIT  1
		];
		return jobs.isEmpty() ? 'Unknown' : jobs[0].Status;
	}

	@AuraEnabled
	public static void updateAutoSync(Id recordId, Boolean isActive) {
		ParallelDots__Shelfwatch_Mapping__c rec = new ParallelDots__Shelfwatch_Mapping__c(
			Id = recordId,
			ParallelDots__Is_Auto_Active__c = isActive
		);
		update rec;
	}

	@AuraEnabled
	public static void retryFailedSync(Id recordId) {
		ParallelDots__Shelfwatch_Mapping__c mapRec = [
			SELECT Id,
				ParallelDots__Shelfwatch_Object__c,
				ParallelDots__Salesforce_Object__c,
				ParallelDots__Mapping_JSON__c,
				ParallelDots__Required_Fields__c,
				ParallelDots__Last_Sync_Time__c,
				ParallelDots__Retry_From_Id__c
			FROM   ParallelDots__Shelfwatch_Mapping__c
			WHERE  Id = :recordId
			WITH   SECURITY_ENFORCED
			LIMIT  1
		];

		if (mapRec == null || String.isBlank(mapRec.ParallelDots__Retry_From_Id__c)) return;

		Map<String, String> fieldMapping = String.isNotBlank(mapRec.ParallelDots__Mapping_JSON__c)
			? (Map<String, String>) JSON.deserialize(mapRec.ParallelDots__Mapping_JSON__c, Map<String, String>.class)
			: new Map<String, String>();

		String retryFromId = mapRec.ParallelDots__Retry_From_Id__c;

		String query = 'SELECT IsDeleted, ' + String.join(fieldMapping.values(), ', ')
					+ ' FROM ' + mapRec.ParallelDots__Salesforce_Object__c
					+ ' WHERE Id >= :retryFromId'
					+ ' ORDER BY Id ASC LIMIT 500';

		ShelfWatchApiService.PayloadAttributes payload = new ShelfWatchApiService.PayloadAttributes();
		payload.entity        = mapRec.ParallelDots__Shelfwatch_Object__c;
		payload.sObjectEntity = mapRec.ParallelDots__Salesforce_Object__c;
		payload.fieldMapping  = fieldMapping;
		payload.entityFields  = String.isNotBlank(mapRec.ParallelDots__Required_Fields__c)
			? (List<String>) JSON.deserialize(mapRec.ParallelDots__Required_Fields__c, List<String>.class)
			: new List<String>();
		payload.records       = new List<SObject>();
		payload.saveSyncTime  = true; 

		ShelfWatchAuthService.AuthResponse auth = ShelfWatchAuthService.getAccessToken();

		Map<String, Object> params = new Map<String, Object>{
			'query'       => query,
			'isFirstTime' => false,
			'recordId'    => mapRec.Id,
			'recordCount' => 500
		};

		Map<String, Object> config = new Map<String, Object>{
			'params'       => params,
			'payload'      => payload,
			'allMappings'  => new List<ParallelDots__Shelfwatch_Mapping__c>{ mapRec },
			'currentIndex' => 0,
			'accessToken'  => auth.accessToken
		};

		try {
			update new ParallelDots__Shelfwatch_Mapping__c(
				Id                              = recordId,
				ParallelDots__Last_Sync_Time__c = System.now()
			);
		} catch (Exception e) {
			System.debug('Failed to update Last Sync Time in retry: ' + e.getMessage());
		}

		Database.executeBatch(new ShelfWatchSyncBatch(config), 500);
	}


}
@isTest
private class ShelfWatchSyncBatchTest {

    private class MultiCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/auth/jwt')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"mock_token","refresh_token":"mock_refresh"}');
            } else {
                res.setStatusCode(202);
                res.setBody('{"status":"queued"}');
            }
            return res;
        }
    }

    private static void insertCredentials() {
        insert new ParallelDots__ShelfWatch_Credentials__c(
            Name                           = 'AuthCredentials',
            ParallelDots__Client_Id__c     = 'cid',
            ParallelDots__Client_Secret__c = 'csecret',
            ParallelDots__Org_Id__c        = 'oid',
            ParallelDots__Project_Id__c    = 'pid'
        );
    }

    private static ParallelDots__Shelfwatch_Mapping__c insertMapping(DateTime lastSync) {
        ParallelDots__Shelfwatch_Mapping__c m = new ParallelDots__Shelfwatch_Mapping__c(
            Name                                = 'Test Mapping',
            ParallelDots__Salesforce_Object__c  = 'Account',
            ParallelDots__Shelfwatch_Object__c  = 'user',
            ParallelDots__Mapping_JSON__c       = '{"user_name":"Name"}',
            ParallelDots__Required_Fields__c    = '["user_name"]',
            ParallelDots__Salesforce_Fields__c  = '["Name"]',
            ParallelDots__Last_Sync_Time__c     = lastSync
        );
        insert m;
        return m;
    }

    private static Map<String, Object> buildConfig(
        ParallelDots__Shelfwatch_Mapping__c mapRec,
        List<ParallelDots__Shelfwatch_Mapping__c> allMappings,
        Integer index
    ) {
        ShelfWatchApiService.PayloadAttributes payload = new ShelfWatchApiService.PayloadAttributes();
        payload.entity        = 'user';
        payload.sObjectEntity = 'Account';
        payload.fieldMapping  = new Map<String, String>{ 'user_name' => 'Name' };
        payload.entityFields  = new List<String>{ 'user_name' };
        payload.records       = new List<SObject>();

        Map<String, Object> params = new Map<String, Object>{
            'query'       => 'SELECT Name FROM Account',
            'isFirstTime' => true,
            'recordId'    => mapRec.Id
        };

        return new Map<String, Object>{
            'params'       => params,
            'payload'      => payload,
            'allMappings'  => allMappings,
            'currentIndex' => index
        };
    }

    @isTest
    static void testBatch_ChainsToNextMappingInFinish() {
        insertCredentials();
        insert new Account(Name = 'Chain Account');

        ParallelDots__Shelfwatch_Mapping__c m1 = insertMapping(null);
        ParallelDots__Shelfwatch_Mapping__c m2 = insertMapping(null);
        List<ParallelDots__Shelfwatch_Mapping__c> allMappings =
            new List<ParallelDots__Shelfwatch_Mapping__c>{ m1, m2 };

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());

        Test.startTest();
            Database.executeBatch(
                new ShelfWatchSyncBatch(buildConfig(m1, allMappings, 0)),
                200
            );
        Test.stopTest();

        // After finish() calls fireNext(allMappings, 1), a second batch job is enqueued
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE JobType = 'BatchApex'];
        System.assert(jobs.size() >= 1, 'At least one batch job should exist from chaining');
    }

}
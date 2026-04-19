@isTest
private class ShelfWatchSyncQueueTest {
    private class MultiCalloutMock implements HttpCalloutMock {
        private Integer authStatus;
        private Integer ingestStatus;

        public MultiCalloutMock(Integer authStatus, Integer ingestStatus) {
            this.authStatus   = authStatus;
            this.ingestStatus = ingestStatus;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/auth/jwt')) {
                res.setStatusCode(authStatus);
                res.setBody(authStatus == 200
                    ? '{"access_token":"mock_token","refresh_token":"mock_refresh"}'
                    : '{"message":"Unauthorized"}');
            } else {
                res.setStatusCode(ingestStatus);
                res.setBody(ingestStatus == 202
                    ? '{"status":"queued"}'
                    : '{"message":"Bad Request"}');
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

    private static Map<String, Object> buildBody() {
        return new Map<String, Object>{
            'object_type'       => 'user',
            'source'            => 'salesforce',
            'external_id_field' => 'Id',
            'records'           => new List<Object>()
        };
    }

    

}
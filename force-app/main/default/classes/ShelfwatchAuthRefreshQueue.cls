public with sharing class ShelfwatchAuthRefreshQueue implements Queueable , Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        try{
            Map<String,Object> apiResponse                    = getAccessToken();
            Boolean isAuthorize                               = (Boolean)apiResponse.get('isAuthorize');
            ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
            if(isAuthorize && shelfCred != null){
                shelfCred.ParallelDots__Access_Token__c = (String)apiResponse.get('access_token');
                update shelfCred;
            }
        }catch(Exception e){

        }

    }
    private Map<String,Object> getAccessToken() {
        Map<String,Object> responseObj                    = new Map<String,Object>();
        responseObj.put('isAuthorize' , false);
        ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
        Http http                                         = new Http();
        HttpRequest req                                   = new HttpRequest();
        if (shelfCred == null) {
            return responseObj;
        }
        req.setEndpoint('callout:ShelfWatch_API/v1/auth/jwt');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Org-Id', shelfCred.ParallelDots__Org_Id__c);
        req.setHeader('X-Project-Id', shelfCred.ParallelDots__Project_Id__c);
        Map<String, Object> body = new Map<String, Object>{
            'client_id'     => shelfCred.ParallelDots__Client_Id__c,
            'client_secret' => shelfCred.ParallelDots__Client_Secret__c
        };
        req.setBody(JSON.serialize(body));
        HttpResponse res;
        res = http.send(req);
        Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        if (res.getStatusCode() == 200) {
            responseObj.put('isAuthorize' , true);
            responseObj.put('access_token' , (String)result.get('access_token'));
            responseObj.put('refresh_token' , (String)result.get('refresh_token'));
        } else {
            responseObj.put('error' , res.getStatusCode());
            responseObj.put('message' , (String)result.get('message'));
        }
        return responseObj;
    }

}
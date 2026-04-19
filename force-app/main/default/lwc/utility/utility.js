export function authenticationMessage(response){
    if(response){
        return { "iconName" : "utility:success" ,  "message" : "Authorized Successfully"}
    }else{
        return { "iconName" : "action:reject" , "message" : "Authentication Failed!" }
    }
}
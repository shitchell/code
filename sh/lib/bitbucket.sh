#!/usr/bin/env bash

function get-access-token() {
    :  'Request an access token from Bitbucket
        
        Using a client_id, client_secret, and an authorization code grant,
        request an access token from Bitbucket.

        @usage
            <client_id> <client_secret> <authorization_code>
        
        @arg client_id
            The client_id to use for the request
        
        @arg client_secret
            The client_secret to use for the request
        
        @arg authorization_code
            The authorization code to use for the request
        
        @stdout
            The full response from Bitbucket
    '

    local client_id=${1}
    local client_secret=${2}
    local authorization_code=${3}

    response=$(curl -v -X POST https://bitbucket.org/site/oauth2/access_token
        -d grant_type=authorization_code \
        -d client_id="${client_id}" \
        -d client_secret="${client_secret}" \
        -d code="${authorization_code}"
    )
}

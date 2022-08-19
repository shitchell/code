# using a client_id, client_secret, and an authorization code grant, request an
# access token from bitbucket 
function get-access-token() {
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
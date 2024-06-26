#!/bin/bash

set -e

## Colors
ESC_SEQ="\x1b["
C_RESET=$ESC_SEQ"39;49;00m"
C_BOLD=$ESC_SEQ"37;01m"
C_RED=$ESC_SEQ"31;01m"
C_YEL=$ESC_SEQ"33;01m"
C_BLU=$ESC_SEQ"36;01m"

function _log() {
    case $1 in
      erro) logLevel="${C_RED}[ERRO]${C_RESET}";;
      warn) logLevel="${C_YEL}[WARN]${C_RESET}";;
      *)    logLevel="${C_BOLD}[INFO]${C_RESET}";;
    esac

    echo -e "$(date +"%d-%b-%Y %H:%M:%S") ${logLevel} - ${2}"
}

function deploy() {
    RET_DEPLOY=0
    CURL_BODY_FILE=$(mktemp)
    CURL_HEADERS_FILE=$(mktemp)
    _log info "Deploying $IMAGE image to COPS $URL..."
    if CURL_RESPONSE=$(curl -L -v -s --max-time 20 -X PATCH -H 'Content-Type: application/json' --url "$URL" -d "{\"image\": \"$IMAGE\"}" --write-out '%{http_code}' -o ${CURL_BODY_FILE} 2> >(grep -v '* Expire in' 1> ${CURL_HEADERS_FILE})); then
        if grep -q '^2..' <<< ${CURL_RESPONSE}; then
            _log info "Valid response from COPS status_code:[${CURL_RESPONSE}]"
        elif grep -q '^4..' <<< ${CURL_RESPONSE}; then
            _log warn "INVALID response from COPS status_code:[${CURL_RESPONSE}]" 
            _log warn "This could be a problem with COPS or the image registry"
            _log warn "Please, verify if the image exists in the registry, and if the COPS app with that id exists"
            RET_DEPLOY=1
        else
            _log erro "INVALID response from COPS status_code:[${CURL_RESPONSE}]"
            _log erro "Maybe a problem with COPS or REPOSITORY"
            RET_DEPLOY=1
        fi
        _log info "Response body was [${C_BLU}$(cat ${CURL_BODY_FILE})${C_RESET}]"
    else
        _log erro "Can't execute CURL to deploy image ${IMAGE} to COPS [$URL]"
        RET_DEPLOY=1
    fi
    ALL_HEADERS=$(cat ${CURL_HEADERS_FILE})
    rm ${CURL_BODY_FILE} &&
        rm ${CURL_HEADERS_FILE} &&
        ((RET_DEPLOY>0)) &&
        _log erro "Execution finished with error. Print headers executions" &&
        echo "${ALL_HEADERS}" &&
        exit 1
    _log info "Continue execution..."
}

function wait() {
    _log info "Waiting $IMAGE to finish deploy in $URL..."
    if ! pip install requests==2.25.1 > pip.log 2>&1; then
        _log erro "Pip install failed!"
        cat pip.log
        exit 1
    fi
    rm -f pip.log
    python $WAIT_PATH/wait.py $IMAGE $URL $TIMEOUT
}


# Check if cops API URL is on format: <domain>/v1/apps/<uuid> or <domain>/v1/schedulers/<uuid>/deploy
uuid_pattern="[[:xdigit:]]{32}"
if [[ ${URL//-/} =~  https?:\/\/api\..*\/v1\/apps\/$uuid_pattern$ ]]; then 
    _log info "COPS API URL [${URL}] is valid with expected format [https?://api.<domain>/v1/apps/<uuid>]"
elif [[ ${URL//-/} =~ https?:\/\/api\..*\/v1\/schedulers\/$uuid_pattern\/deploy$ ]]; then
    _log info "COPS API URL [${URL}] is valid with expected format [https?://api.<domain>/v1/schedulers/<uuid>/deploy]"
else
    _log erro "COPS API URL [${URL}] is NOT valid with expected format [https?://<domain>/v1/apps/<uuid>] or [https?://<domain>/v1/schedulers/<uuid>/deploy]" && exit 1
fi

# Check timeout before start
(($TIMEOUT > 3600)) &&
    _log erro "Timeout can NOT be more than 1h [$TIMEOUT seconds]" &&
    exit 1 || true

# If docker is authenticated, check image before
DOMAIN=$(cut -d/ -f1 <<< $IMAGE)

_log info "Checking if docker is authenticated on domain $DOMAIN..."
BASIC_TOKEN=$(jq -r ".auths.\"$DOMAIN\".auth" ~/.docker/config.json 2> /dev/null || echo null)

if [[ $BASIC_TOKEN != null ]]; then
    status_code=$(curl -s -H "Authorization: Basic $BASIC_TOKEN" --write-out '%{http_code}' -o /dev/null https://$DOMAIN/v2/_catalog)
    if [[ $status_code == 200 ]]; then
        _log info "Auth token is valid. Checking if image exits [$IMAGE] ..."

        docker manifest inspect $IMAGE > /dev/null 2>&1 &&
            _log info "Image FOUND on registry [$IMAGE]. Proceed to deploy..." ||
            (_log erro "Image NOT FOUND on registry [$IMAGE]. Check if image has been pushed to registry."; exit 1)

    else
        _log warn "Auth token has expired. Unable to check image on registry [$DOMAIN]."
    fi
else
    _log warn "Auth token not found on config file for domain [$DOMAIN]. Skipping process to check if image exists on registry."
fi

deploy && wait

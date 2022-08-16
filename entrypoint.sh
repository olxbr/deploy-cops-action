#!/bin/bash

set -e

echo "IMAGE: $IMAGE"
echo "TIMEOUT: $TIMEOUT"
echo "URL: $URL"

## Colors
ESC_SEQ="\x1b["
C_RESET=$ESC_SEQ"39;49;00m"
C_BOLD=$ESC_SEQ"39;49;01m"
C_RED=$ESC_SEQ"31;01m"
C_YEL=$ESC_SEQ"33;01m"

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
    _log info "Deploying $IMAGE image to COPS $URL..."
    if CURL_RESPONSE=$(curl -v -s --max-time 10 -X PATCH -H 'Content-Type: application/json' --url "$URL" -d "{\"image\": \"$IMAGE\"}" --write-out '%{http_code}' -o ${CURL_BODY_FILE} 2> >(grep -v '* Expire in' 1>&2)); then
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
        _log info "Response body was [$(cat ${CURL_BODY_FILE})]"
    else
        _log erro "Can't execute CURL to deploy image ${IMAGE} to COPS [$URL]"
        RET_DEPLOY=1
    fi
    rm ${CURL_BODY_FILE} &&
        ((RET_DEPLOY>0)) &&
        _log erro "Execution finished with error" &&
        exit 1
    _log info "Continue execution..."
}

function wait() {
    _log info "Waiting $IMAGE to finish deploy in $URL..."
    pip install requests==2.25.1 && \
        python /wait.py $IMAGE $URL $TIMEOUT
}

## MAIN
# if (($#<3)); then
#   _log erro "Missing parameters. Expected [3] found [$#]"
#   exit 1
# fi

# Check if cops API URL is on format: <domain>/v1/apps/<uuid-namespace>
if [[ ${URL//-/} =~ /v1/apps/[[:xdigit:]]{32} ]];
  then _log info "COPS API URL [${URL}] is valid with expected format [https?://<domain>/v1/apps/<uuid-namespace>]"
  else _log erro "COPS API URL [${URL}] is NOT valid with expected format [https?://<domain>/v1/apps/<uuid-namespace>]" && exit 1
fi
deploy && wait



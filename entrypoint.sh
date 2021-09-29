#!/bin/bash

set -e

IMAGE=$1
URL=$2
TIMEOUT=$3

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
    if CURL_RESPONSE=$(curl -v -s -X PATCH -H 'Content-Type: application/json' --url "$URL" -d "{\"image\": \"$IMAGE\"}" --write-out '%{http_code}' -o ${CURL_BODY_FILE}); then
        if grep -q '2..' <<< ${CURL_RESPONSE}; then
            _log info "Valid response from COPS status_code:[${CURL_RESPONSE}]"
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
    echo Waiting $IMAGE to finish deploy in $URL...
    pip install requests==2.25.1 && \
        python /wait.py $IMAGE $URL $TIMEOUT
}

deploy && wait



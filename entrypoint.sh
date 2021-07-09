#!/bin/bash

set -e

IMAGE=$1
URL=$2
TIMEOUT=$3

function deploy() {
    echo Deploying $IMAGE image to COPS $URL...
    curl -X PATCH -H 'Content-Type: application/json' --url "$URL" -d "{\"image\": \"$IMAGE\"}"
}

function wait() {
    echo Waiting $IMAGE to finish deploy in $URL...
    pip install requests==2.25.1 && \
        python /wait.py $IMAGE $URL $TIMEOUT
}

deploy && wait



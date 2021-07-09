FROM public.ecr.aws/o5c8q0l3/python:3.7-slim

RUN apt-get upgrade && apt-get update && apt-get -qq -y install curl

COPY entrypoint.sh /entrypoint.sh
COPY wait.py /wait.py

ENTRYPOINT ["/entrypoint.sh"]

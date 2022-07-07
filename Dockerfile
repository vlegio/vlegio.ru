FROM ubuntu:20.04

LABEL maintainer="mail@jtprog.ru"

LABEL version="1.0"

WORKDIR /site

COPY . /site/

ARG SSH_PRIVATE_KEY
ARG SSH_USER
ARG SSH_HOST
ARG REMOTE_PATH

RUN DEBIAN_FRONTEND=noninteractive apt-get -y update \
    && apt-get install -y openssh-client hugo rsync git \
    && rm -rf /var/cache/apt/* \
    && mkdir -p /root/.ssh \
    && echo "Host *\n\tStrictHostKeyChecking no\n\n" > /root/.ssh/config
RUN chmod 700 /root/.ssh && ssh-keyscan -p 22 ${SSH_HOST} > /root/.ssh/known_hosts \
    && git submodule update --remote --merge \
    && echo "Генерирование страниц началось" && hugo \
    && echo "${SSH_PRIVATE_KEY}" |  tr -d ' ' | base64 --decode > /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa \
    && cp ./content/.htaccess ./public/.htaccess && cp ./content/robots.txt ./public/robots.txt \
    && echo "Запуск rsync" && rsync -avz -e "ssh -i ~/.ssh/id_rsa" --progress --delete public/ ${SSH_USER}@${SSH_HOST}:${REMOTE_PATH} \
    && echo "Завершён деплой"

#!/bin/bash

MONGODB_HOST=${MONGODB_BACKUP_PORT_27017_TCP_ADDR:-${MONGODB_BACKUP_HOST}}
MONGODB_HOST=${MONGODB_BACKUP_1_PORT_27017_TCP_ADDR:-${MONGODB_BACKUP_HOST}}

MONGODB_PORT=${MONGODB_BACKUP_PORT_27017_TCP_PORT:-${MONGODB_BACKUP_PORT}}
MONGODB_PORT=${MONGODB_BACKUP_1_PORT_27017_TCP_PORT:-${MONGODB_BACKUP_PORT}}

MONGODB_USER=${MONGODB_BACKUP_USER:-${MONGODB_BACKUP_ENV_MONGODB_USER}}
MONGODB_PASS=${MONGODB_BACKUP_PASS:-${MONGODB_BACKUP_ENV_MONGODB_PASS}}

MONGODB_DB=${MONGODB_BACKUP_DB:-${MONGODB_BACKUP_ENV_MONGODB_DB}}
MONGODB_DB=${MONGODB_BACKUP_1_DB:-${MONGODB_BACKUP_ENV_MONGODB_DB}}

[[ ( -z "${MONGODB_USER}" ) && ( -n "${MONGODB_PASS}" ) ]] && MONGODB_USER='admin'

[[ ( -n "${MONGODB_USER}" ) ]] && USER_BACKUP_STR=" --username ${MONGODB_USER}"
[[ ( -n "${MONGODB_PASS}" ) ]] && PASS_BACKUP_STR=" --password ${MONGODB_PASS}"
[[ ( -n "${MONGODB_DB}" ) ]] && DB_BACKUP_STR=" --db ${MONGODB_DB}"

MAX_BACKUPS=${MAX_BACKUPS}
BACKUP_NAME=$(date +%Y.%m.%d.%H%M%S)
BACKUP_CMD="mongodump --out /backup/${BACKUP_NAME} --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_BACKUP_STR}${PASS_BACKUP_STR}${DB_BACKUP_STR} ${EXTRA_BACKUP_OPTS}"
echo "Backup command: ${BACKUP_CMD}"
echo "=> Backup started"
if ${BACKUP_CMD} ;then

    echo "   Backup succeeded"

    if [[ -n "$S3_BACKUP" ]]; then

        echo "   Archiving and backing up dump to S3"

        echo "   Creating archive at /backup/${BACKUP_NAME}.tgz"
        tar czf "/backup/${BACKUP_NAME}.tgz" "/backup/${BACKUP_NAME}"

        echo "   Copying to S3"
        aws s3 cp "/backup/${BACKUP_NAME}.tgz" s3://$S3_BUCKET/$S3_PATH/${BACKUP_NAME}.tgz

        if [ $? == 0 ]; then
            rm "/backup/${BACKUP_NAME}.tgz"
        else
            >&2 echo "couldn't transfer /backup/${BACKUP_NAME}.tgz to S3"
        fi

    fi

else

    echo "   Backup failed"
    rm -rf /backup/${BACKUP_NAME}

fi

if [ -n "${MAX_BACKUPS}" ]; then
    while [ $(ls /backup -N1 | wc -l) -gt ${MAX_BACKUPS} ];
    do
        BACKUP_TO_BE_DELETED=$(ls /backup -N1 | sort | head -n 1)
        echo "   Deleting backup ${BACKUP_TO_BE_DELETED}"
        rm -rf /backup/${BACKUP_TO_BE_DELETED}
    done
fi
echo "=> Backup done"

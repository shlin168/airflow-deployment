#!/bin/bash
SERVICE_NAME="Webserver"
SYSTEM_TYPE=$(uname)

AIRFLOW_OPERATION="$(cd "`dirname "$0"`"/..; pwd)"
. $AIRFLOW_OPERATION/var/airflow-deployment-conf.sh
. $AIRFLOW_OPERATION/scripts/common/common.sh

export AIRFLOW_HOME=$AIRFLOW_HOME

LOG_FOLDER=$AIRFLOW_LOG/webserver
PID_FILE=$LOG_FOLDER/webserver.pid

AIRFLOW_VENV=$AIRFLOW_BASEDIR/venv
source $AIRFLOW_VENV/bin/activate

function usage() {
    echo "[Airflow]
    Usage: $(basename $0) [COMMANDS](start|stop|restart|status)
     e.g. $(basename $0) start
    COMMANDS:
        start           start airflow webserver
        stop            stop airflow webserver
        restart         restart airflow webserver
        status          check if airflow webserver running
    "
}

if [[ -f $PID_FILE ]]; then
    GUNICORN_MASTER_PID_FROM_FILE=$(cat $PID_FILE)
fi

check_airflow_gunicorn_master_process(){
    GUNICORN_MASTER_PID=$(ps -f -u $USER | grep "gunicorn: master \[airflow-webserver\]" | awk '{ print $2 }')
    if ! [[ -z $GUNICORN_MASTER_PID ]]; then
        echo "but there's another Airflow Webserver running with pid: $GUNICORN_MASTER_PID"
    else
        echo "and no other Airflow Webserver is running"
    fi
}

case "$1" in
    start)
        if [[ -z $GUNICORN_MASTER_PID_FROM_FILE ]]; then
            start_service $SERVICE_NAME
            airflow webserver --pid ${PID_FILE} \
               --stdout ${LOG_FOLDER}/webserver.stdout --stderr ${LOG_FOLDER}/webserver.stderr \
               -l ${LOG_FOLDER}/webserver.log -A ${LOG_FOLDER}/web-access.log -E ${LOG_FOLDER}/web-error.log -D
        else
            running $SERVICE_NAME
            echo "pid: $GUNICORN_MASTER_PID_FROM_FILE"
            exit
        fi
        ;;
    stop)
        if ! [[ -z $GUNICORN_MASTER_PID_FROM_FILE ]]; then
            stop_service $SERVICE_NAME
            if [[ "$SYSTEM_TYPE" == "Linux" ]]; then
                GUNICORN_WORKERS_PID=$(ps --ppid=$GUNICORN_MASTER_PID_FROM_FILE -o pid=)
            fi
            echo "kill gunicorn master, pid: $GUNICORN_MASTER_PID_FROM_FILE"
            kill $GUNICORN_MASTER_PID_FROM_FILE
            delete_file $PID_FILE

            # if not using airflow -D, the parent process of gunicorn master would be webserver (command only work in linux)
            # WEBSERVER_PID=$(ps --ppid=$GUNICORN_MASTER_PID -o pid=)

            # if using airflow -D, webserver and gunicorn master do not have relationship
            WEBSERVER_PID=$(ps -f -u $USER | grep "$AIRFLOW_VENV/bin/airflow\ webserver" | awk '{ print $2 }')

            echo "find webserver from gunicorn master to kill, pid: $WEBSERVER_PID"
            kill $WEBSERVER_PID

            if [[ -n "$GUNICORN_WORKERS_PID" ]]; then
                echo "find gunicorn workers from gunicorn master to kill, pid:"
                echo $GUNICORN_WORKERS_PID
                echo $GUNICORN_WORKERS_PID | xargs kill -9
            else
                echo "workers would be killed later since master is killed"
            fi
            exit
        else
            not_running $SERVICE_NAME
            exit
        fi
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    status)
        if ! [[ -z $GUNICORN_MASTER_PID_FROM_FILE ]]; then
            if [[ -n "$(ps -p $GUNICORN_MASTER_PID_FROM_FILE -o pid=)" ]]; then
                running $SERVICE_NAME
                echo "gunicorn master pid: $GUNICORN_MASTER_PID_FROM_FILE"
                if [[ "$SYSTEM_TYPE" == "Linux" ]]; then
                    GUNICORN_WORKERS_PID=$(ps --ppid=$GUNICORN_MASTER_PID_FROM_FILE -o pid=)
                    echo "gunicorn worker pid:"
                    echo "$GUNICORN_WORKERS_PID"
                fi
            else
                not_running $SERVICE_NAME
                echo "but $PID_FILE exist with pid: $GUNICORN_MASTER_PID_FROM_FILE"
                delete_file $PID_FILE
                check_airflow_gunicorn_master_process
            fi
        else
            not_running $SERVICE_NAME
            echo "$PID_FILE not exist"
            check_airflow_gunicorn_master_process
        fi
        exit
        ;;
    *)
        usage
        exit
        ;;
esac

if [ ! -z ${REDEPLOY_OPTS} ]; then
    echo "no service specified"
fi

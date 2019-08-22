#!/bin/bash
SERVICE_NAME="Worker(Celery)"

AIRFLOW_OPERATION="$(cd "`dirname "$0"`"/..; pwd)"
. $AIRFLOW_OPERATION/var/airflow-deployment-conf.sh
. $AIRFLOW_OPERATION/scripts/common/common.sh

export AIRFLOW_HOME=$AIRFLOW_HOME

LOG_FOLDER=$AIRFLOW_LOG/worker
PID_FILE=$LOG_FOLDER/worker.pid

AIRFLOW_VENV=$AIRFLOW_BASEDIR/venv
source $AIRFLOW_VENV/bin/activate

function usage() {
    echo "[Airflow]
    Usage: $(basename $0) [COMMANDS](start|stop|restart|status)
     e.g. $(basename $0) start
    COMMANDS:
        start           start airflow worker (celery)
        stop            stop airflow worker (celery)
        restart         restart airflow worker (celery)
        status          check if airflow worker running (celery)
    "
}

if [[ -f $PID_FILE ]]; then
    WORKER_PID_FROM_FILE=$(cat $PID_FILE)
fi

check_airflow_worker_process(){
    WORKER=$(ps -f -u $USER | grep "celeryd:\ celery" | awk '{ print $2 }')
    if ! [[ -z $WORKER ]]; then
        echo "but there's another Airflow Worker running with pid: $WORKER"
    else
        echo "and no other Airflow Worker running"
    fi
}

case "$1" in
    start)
        if [[ -z "$WORKER_PID_FROM_FILE" ]]; then
            start_service $SERVICE_NAME
            airflow worker -D --pid ${PID_FILE} -l ${LOG_FOLDER}/worker.log \
                --stdout ${LOG_FOLDER}/worker.stdout --stderr ${LOG_FOLDER}/worker.stderr
        else
            running $SERVICE_NAME
            echo "pid: $WORKER_PID_FROM_FILE"
            exit
        fi
        ;;
    stop)
        if ! [[ -z "$WORKER_PID_FROM_FILE" ]]; then
            stop_service $SERVICE_NAME
            echo "kill scheduler, pid: $WORKER_PID_FROM_FILE"
            kill $WORKER_PID_FROM_FILE
            delete_file $PID_FILE
        else
            not_running $SERVICE_NAME
        fi
        exit
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    status)
        if ! [[ -z "$WORKER_PID_FROM_FILE" ]]; then
            if [[ -n "$(ps -p $WORKER_PID_FROM_FILE -o pid=)" ]]; then
                    running $SERVICE_NAME
                    echo "worker pid: $WORKER_PID_FROM_FILE"
            else
                not_running $SERVICE_NAME
                echo "but $PID_FILE exist with pid: $WORKER_PID_FROM_FILE"
                delete_file $PID_FILE
                check_airflow_worker_process
            fi
        else
            not_running $SERVICE_NAME
            echo "$PID_FILE not exist"
            check_airflow_worker_process
        fi
        exit
        ;;
    *)
        usage
        exit
        ;;
esac

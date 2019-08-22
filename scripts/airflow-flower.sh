#!/bin/bash
SERVICE_NAME="Flower(Celery)"

AIRFLOW_OPERATION="$(cd "`dirname "$0"`"/..; pwd)"
. $AIRFLOW_OPERATION/var/airflow-deployment-conf.sh
. $AIRFLOW_OPERATION/scripts/common/common.sh

export AIRFLOW_HOME=$AIRFLOW_HOME

LOG_FOLDER=$AIRFLOW_LOG/flower
PID_FILE=$LOG_FOLDER/flower.pid

AIRFLOW_VENV=$AIRFLOW_BASEDIR/venv
source $AIRFLOW_VENV/bin/activate

function usage() {
    echo "[Airflow]
    Usage: $(basename $0) [COMMANDS](start|stop|restart|status)
     e.g. $(basename $0) start
    COMMANDS:
        start           start airflow flower (celery)
        stop            stop airflow flower (celery)
        restart         restart airflow flower (celery)
        status          check if airflow flower running (celery)
    "
}

if [[ -f $PID_FILE ]]; then
    FLOWER_PID_FROM_FILE=$(cat $PID_FILE)
fi

check_airflow_flower_process(){
    FLOWER=$(ps -f -u $USER | grep "flower\ -b" | awk '{ print $2 }')
    if ! [[ -z $WORKER ]]; then
        echo "but there's another Airflow Flower running with pid: $WORKER"
    else
        echo "and no other Airflow Flower running"
    fi
}

case "$1" in
    start)
        if [[ -z "$FLOWER_PID_FROM_FILE" ]]; then
            start_service $SERVICE_NAME
            airflow flower -D --pid ${PID_FILE} -l ${LOG_FOLDER}/flower.log \
                --stdout ${LOG_FOLDER}/flower.stdout --stderr ${LOG_FOLDER}/flower.stderr
        else
            running $SERVICE_NAME
            exit
        fi
        ;;
    stop)
        if ! [[ -z "$FLOWER_PID_FROM_FILE" ]]; then
            stop_service $SERVICE_NAME
            echo "kill flower, pid: $FLOWER_PID_FROM_FILE"
            kill $FLOWER_PID_FROM_FILE
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
        if ! [[ -z "$FLOWER_PID_FROM_FILE" ]]; then
            if [[ -n "$(ps -p $FLOWER_PID_FROM_FILE -o pid=)" ]]; then
                    running $SERVICE_NAME
                    echo "worker pid: $FLOWER_PID_FROM_FILE"
            else
                not_running $SERVICE_NAME
                echo "but $PID_FILE exist with pid: $FLOWER_PID_FROM_FILE"
                delete_file $PID_FILE
                check_airflow_flower_process
            fi
        else
            not_running $SERVICE_NAME
            echo "$PID_FILE not exist"
            check_airflow_flower_process
        fi
        exit
        ;;
    *)
        usage
        exit
        ;;
esac

#!/bin/bash
SERVICE_NAME="Scheduler"
SYSTEM_TYPE=$(uname)

AIRFLOW_OPERATION="$(cd "`dirname "$0"`"/..; pwd)"
. $AIRFLOW_OPERATION/var/airflow-deployment-conf.sh
. $AIRFLOW_OPERATION/scripts/common/common.sh

export AIRFLOW_HOME=$AIRFLOW_HOME

LOG_FOLDER=$AIRFLOW_LOG/scheduler
PID_FILE=$LOG_FOLDER/scheduler.pid

AIRFLOW_VENV=$AIRFLOW_BASEDIR/venv
source $AIRFLOW_VENV/bin/activate

function usage() {
    echo "[Airflow]
    Usage: $(basename $0) [COMMANDS](start|stop|restart|status)
     e.g. $(basename $0) start
    COMMANDS:
        start           start airflow scheduler
        stop            stop airflow scheduler
        restart         restart airflow scheduler
        status          check if airflow scheduler running
    "
}

if [[ -f $PID_FILE ]]; then
    SCHEDULER_PID_FROM_FILE=$(cat $PID_FILE)
fi

check_airflow_scheduler_process(){
    SCHEDULER=$(ps -f -u $USER | grep "airflow\ scheduler" | awk '{ print $2 }')
    if ! [[ -z $SCHEDULER ]]; then
        echo "but there's another Airflow Scheduler running with pid: $SCHEDULER"
    else
        echo "and no other Airflow Scheduler running"
    fi
}

case "$1" in
    start)
        if [[ -z "$SCHEDULER_PID_FROM_FILE" ]]; then
            start_service $SERVICE_NAME
            if [[ "$SYSTEM_TYPE" == "Linux" ]]; then
                airflow scheduler --pid ${PID_FILE} -l ${LOG_FOLDER}/scheduler.log \
                    --stdout ${LOG_FOLDER}/scheduler.stdout --stderr ${LOG_FOLDER}/scheduler.stderr -D
            else
                echo "There're some unresolved problems running scheduler as daemon service in osx"
                echo "Use nohup to start scheduler instead"
                nohup airflow scheduler > ${LOG_FOLDER}/scheduler.log 2>&1 &
                echo $! > ${PID_FILE}
            fi
        else
            running $SERVICE_NAME
            echo "pid: $SCHEDULER_PID_FROM_FILE"
            exit
        fi
        ;;
    stop)
        if ! [[ -z $SCHEDULER_PID_FROM_FILE ]]; then
            stop_service $SERVICE_NAME
            echo "kill scheduler, pid: $SCHEDULER_PID_FROM_FILE"
            kill $SCHEDULER_PID_FROM_FILE
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
        if ! [[ -z $SCHEDULER_PID_FROM_FILE ]]; then
            if [[ -n "$(ps -p $SCHEDULER_PID_FROM_FILE -o pid=)" ]]; then
                running $SERVICE_NAME
                echo "scheduler pid: $SCHEDULER_PID_FROM_FILE"
            else
                not_running $SERVICE_NAME
                echo "but $PID_FILE exist with pid: $SCHEDULER_PID_FROM_FILE"
                delete_file $PID_FILE
                check_airflow_scheduler_process
            fi
        else
            not_running $SERVICE_NAME
            echo "$PID_FILE not exist"
            check_airflow_scheduler_process
        fi
        exit
        ;;
    *)
        usage
        exit
        ;;
esac

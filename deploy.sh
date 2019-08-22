#!/bin/bash
export OPERATION_HOME="$(cd "`dirname "$0"`"; pwd)"

function usage() {
    echo "[Ansible]
    Usage: $(basename $0) -e (dev|ut|uat|[prod]) [OPTIONS]
     e.g. $(basename $0) -e ut -p 2
    COMMANDS:
        -h|--help                             Show this message
        -e|--env                              Environment
        -s|--service                          choose service to deploy (airflow|postgresql|redis)
        --keep_venv                           not remove old venv (only works when service=airflow)
        --keep_db                             not reset airflow backend db (only works when service=airflow)
        --install_from_source                 compile and build .whl from source code (only works when service=airflow)
    "
}

args=$(getopt -o he:s: --long env:,service:,keep_db,keep_venv,install_from_source,help -- "$@")

if [ $? != 0 ]; then
    echo "terminating..." >&2
    exit 1
fi
eval set -- "$args"

while true; do
    case "$1" in
    -e | --env)
        ENV="$2"
        shift 2
        ;;
    -s | --service)
        SERVICE_OPTS="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit
        ;;
    --keep_db)
        KEEP_DB="true"
        shift
        ;;
    --keep_venv)
        KEEP_VENV="true"
        shift
        ;;
    --install_from_source)
        INSTALL_FROM_SOURCE="true"
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "internal error!"
        exit 1
        ;;
    esac
done

# check exists for ENV variable
if [ -z ${ENV} ]; then
    echo "$(basename $0): missing ENV : ${ENV}"
    usage
    exit 1
fi

# check exists for SERVICE_OPTS variable
if [ -z ${SERVICE_OPTS} ]; then
    echo "$(basename $0): missing service: ${SERVICE_OPTS}"
    usage
    exit 1
fi

EXTRA_VARS=""

function build_extra_vars() {
    local NAME=$1
    local ARGS=$2
    if [ -n "${ARGS}" ] && [ "${SERVICE_OPTS}" != "airflow" ]; then
        echo "--${NAME} only works when --service=airflow, skip this argument"
    elif [ -n "${ARGS}" ]; then
        EXTRA_VARS="${EXTRA_VARS} ${NAME}=true"
    fi
}

build_extra_vars "keep_db" $KEEP_DB
build_extra_vars "keep_venv" $KEEP_VENV
build_extra_vars "install_from_source" $INSTALL_FROM_SOURCE

AIRFLOW_DEPLOY=${OPERATION_HOME}/airflow
AIRFLOW_DEPLOY_VARS=${AIRFLOW_DEPLOY}/airflow-vars
POSTGRESQL_DEPLOY=${OPERATION_HOME}/postgresql
POSTGRESQL_DEPLOY_VARS=${POSTGRESQL_DEPLOY}/postgresql-vars
REDIS_DEPLOY=${OPERATION_HOME}/redis
REDIS_DEPLOY_VARS=${REDIS_DEPLOY}/redis-vars

# run service
if [ "${SERVICE_OPTS}" = "postgresql" ]; then
    echo "deploy postgresql in ${ENV} environment"
    ansible-playbook ${POSTGRESQL_DEPLOY}/postgresql-deployment.yml --extra-vars "@${POSTGRESQL_DEPLOY_VARS}/postgresql-${ENV}.yml"

elif [ "${SERVICE_OPTS}" = "airflow" ]; then
    if [ -n "${EXTRA_VARS}" ]; then
        echo "deploy airflow in ${ENV} environment, with extra vars: ${EXTRA_VARS}"
        ansible-playbook ${AIRFLOW_DEPLOY}/airflow-deployment.yml --extra-vars "@${AIRFLOW_DEPLOY_VARS}/airflow-${ENV}.yml" --extra-vars "${EXTRA_VARS}"
    else
        echo "deploy airflow in ${ENV} environment"
        ansible-playbook ${AIRFLOW_DEPLOY}/airflow-deployment.yml --extra-vars "@${AIRFLOW_DEPLOY_VARS}/airflow-${ENV}.yml"
    fi

elif [ "${SERVICE_OPTS}" = "redis" ]; then
    echo "deploy redis in ${ENV} environment"
    ansible-playbook ${REDIS_DEPLOY}/redis-deployment.yml --extra-vars "@${REDIS_DEPLOY_VARS}/redis-${ENV}.yml"

else
    echo "$(basename $0): missing service: ${SERVICE_OPTS}"
    usage
    exit 1
fi

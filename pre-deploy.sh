#!/bin/bash
export APP_HOME="$(
    cd "$(dirname "$0")"
    pwd
)"

function usage() {
    echo "[Ansible]
    Usage: $(basename $0) -e (dev|ut|uat|[prod]) [OPTIONS]
     e.g. $(basename $0) -e ut -p 2.7
    COMMANDS:
        -h|--help                             Show this message
        -p|--python                           Python version (Default:2) e.g. --python 2.7
        -e|--env                              [Opt] Environment
        -f|--force                            Force Redeployment (delete old virtualenv)
    "
}

args=$(getopt -o hp:e:f --long env:,python:,force,help -- "$@")

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
    -p | --python)
        PYTHON_VERSION="$2"
        shift 2
        ;;
    -f | --force)
        REDEPLOY_OPTS="true"
        shift 1
        ;;
    -h | --help)
        usage
        exit
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

# # check exists for ENV variable and config
# if [[ -z ${ENV} ]]; then
#     echo "$(basename $0): missing ENV : ${ENV}"
#     usage
#     exit 1
# fi

if [[ -z ${PYTHON_VERSION} ]]; then
    echo "using default python: 2.7"
    PYTHON_VERSION=2
fi

# set pypi server config if needed
if [[ "${ENV}" == "dev" ]]; then
  PIP_OPTS=""
fi

if ([ ! -z ${REDEPLOY_OPTS} ] && [ -d ${APP_HOME}/venv ]); then
    echo "rm old virtualenv"
    rm -rf ${APP_HOME}/venv
fi

if [ ! -d ${APP_HOME}/venv ]; then
    echo "create virtualenv, python:" ${PYTHON_VERSION}
    virtualenv -p python${PYTHON_VERSION} --no-setuptools --no-wheel --no-site-packages --no-download venv
    source venv/bin/activate
    pip install --upgrade pip==18.1 ${PIP_OPTS}
    pip install setuptools wheel ${PIP_OPTS}
    pip install ansible ${PIP_OPTS}
else
    echo "virtualenv already exist, use -f to force redeploy"
fi

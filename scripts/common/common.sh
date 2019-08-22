#!/bin/bash

delete_file(){
    file=$1
    if [ -f $file ]; then
        echo "delete $file"
        rm $file
    fi
}

start_service(){
    service_name=$1
    echo "===================================="
    echo "starting Airflow $service_name ..."
    echo "===================================="
}

stop_service(){
    service_name=$1
    echo "===================================="
    echo "stopping Airflow $service_name ..."
    echo "===================================="
}

running(){
    service_name=$1
    echo "===================================="
    echo "Airflow $service_name is running"
    echo "===================================="
}

not_running(){
    service_name=$1
    echo "===================================="
    echo "Airflow $service_name is not running"
    echo "===================================="
}
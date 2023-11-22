#!/bin/bash
az login --service-principal --username "7af45c88-b300-4e6d-a5a2-c480ef6a8105" --password "1QL8Q~FilrpsQ-9OFxlYhbKVyGh2I6b~q_C5DbFK" --tenant "b11b0e93-0aec-47ed-bbaf-fc3e014e0b35"
if [ "$2" == "prod" ]; then
    echo "register prod"
    az acr login --name eurolifeaksprodregistry.azurecr.io
    docker build -t hpa_zabbix:v$1 .
    docker tag hpa_zabbix:v$1 eurolifeaksprodregistry.azurecr.io/hpa_zabbix:v$1
    docker push eurolifeaksprodregistry.azurecr.io/hpa_zabbix:v$1
elif [ "$2" == "test" ]; then  
    echo "register test"
    az acr login --name eurolifeakstestregistry.azurecr.io
    docker build -t hpa_zabbix:v$1 .
    docker tag hpa_zabbix:v$1 eurolifeakstestregistry.azurecr.io/hpa_zabbix:v$1
    docker push eurolifeakstestregistry.azurecr.io/hpa_zabbix:v$1
else
    echo ">>> Error: Unknown environment."
    exit 1
fi
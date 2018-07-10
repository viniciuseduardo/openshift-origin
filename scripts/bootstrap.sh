#!/bin/bash

PROJECT_NAME=$1
SUBSCRIPTION_ID=$2

RESOURCE_GROUP_NAME="sysmi-$PROJECT_NAME-rg"
DEPLOYMENT_NAME="sysmi-$PROJECT_NAME-deploy"

echo "Creating Deployment: Openshift on Azure "
az group deployment create --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP_NAME --subscription $SUBSCRIPTION_ID --template-file azuredeploy.json --parameters azuredeploy.parameters.json --no-wait
echo "Created Deployment: Openshift on Azure "
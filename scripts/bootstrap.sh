#!/bin/bash

PROJECT_NAME=$1
SUBSCRIPTION_ID=$2

RESOURCE_GROUP_NAME="$PROJECT_NAME-rg"
DEPLOYMENT_NAME="$PROJECT_NAME-deploy"

echo "Creating Deployment: $DEPLOYMENT_NAME"
az group deployment create --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP_NAME --subscription $SUBSCRIPTION_ID --template-file azuredeploy.json --parameters @azuredeploy.parameters.markel.json --no-wait
echo "Created Deployment: $DEPLOYMENT_NAME"
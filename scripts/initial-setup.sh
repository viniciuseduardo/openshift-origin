#!/bin/bash

PROJECT_NAME=$1
REGION_NAME=$2
SUBSCRIPTION_ID=$3
SERVICE_PRINCIPAL_ID=$4

RESOURCE_GROUP_NAME="$PROJECT_NAME-rg"
KEYVAULT_NAME="$PROJECT_NAME-kv"
SECRET_NAME="$PROJECT_NAME-sct"
SSH_KEY_NAME="$PROJECT_NAME-key"

echo "Checking Resource Group: $RESOURCE_GROUP_NAME in Region: $REGION_NAME"
CHECK_RG_EXISTS="$(az group exists --name $RESOURCE_GROUP_NAME --subscription $SUBSCRIPTION_ID)"
if [ $CHECK_RG_EXISTS = "false" ] 
then
    echo "Creating Resource Group: $RESOURCE_GROUP_NAME in Region: $REGION_NAME"
    az group create -n "$RESOURCE_GROUP_NAME" -l "$REGION_NAME" --subscription "$SUBSCRIPTION_ID"
    echo "Created Resource Group: $RESOURCE_GROUP_NAME in Region: $REGION_NAME"
    echo "Assigment Role to $RESOURCE_GROUP_NAME"
    az role assignment create --assignee "$SERVICE_PRINCIPAL_ID" --resource-group "$RESOURCE_GROUP_NAME" --role Contributor
else
    az role assignment create --assignee "$SERVICE_PRINCIPAL_ID" --resource-group "$RESOURCE_GROUP_NAME" --role Contributor
    echo "Already created Resource Group: $RESOURCE_GROUP_NAME in Region: $REGION_NAME"
fi

echo "Checking Key Vault: $KEYVAULT_NAME in Resource Group: $RESOURCE_GROUP_NAME"
CHECK_KEYVAULT_EXISTS="$(az keyvault show --name $KEYVAULT_NAME  --resource-group $RESOURCE_GROUP_NAME --subscription $SUBSCRIPTION_ID)"
if [ -z "$CHECK_KEYVAULT_EXISTS" ] 
then
    echo "Creating Key Vault: $KEYVAULT_NAME in Resource Group: $RESOURCE_GROUP_NAME"
    az keyvault create -n "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --location "$REGION_NAME" --subscription $SUBSCRIPTION_ID --enabled-for-template-deployment true 
    echo "Created Key Vault: $KEYVAULT_NAME in Resource Group: $RESOURCE_GROUP_NAME"
else
    echo "Already created Key Vault: $KEYVAULT_NAME in $RESOURCE_GROUP_NAME"
fi

echo "Checking SSH Key $SSH_KEY_NAME"
if [ -f "keys/$SSH_KEY_NAME" ]
then
    echo "Already SSH Key: $SSH_KEY_NAME"
else
    echo "Creating SSH Key $SSH_KEY_NAME"
    ssh-keygen -t rsa -f "keys/$SSH_KEY_NAME" -N ""
    echo "Created SSH Key $SSH_KEY_NAME"
fi

echo "Checking Secret in Key Vault: $KEYVAULT_NAME"
CHECK_SECRET_EXISTS="$(az keyvault secret show --name $SECRET_NAME --vault-name $KEYVAULT_NAME --subscription $SUBSCRIPTION_ID)"
if [ -z "$CHECK_SECRET_EXISTS" ] 
then
    echo "Creating Secret in Key Vault: $KEYVAULT_NAME"
    az keyvault secret set --vault-name "$KEYVAULT_NAME" -n "$SECRET_NAME" --file   keys/$SSH_KEY_NAME
    echo "Created Secret in Key Vault: $KEYVAULT_NAME"
else
    echo "Already created Secret: $SECRET_NAME in $KEYVAULT_NAME"
fi

echo "Assigment Role to $RESOURCE_GROUP_NAME"
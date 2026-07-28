#!/bin/bash
# Run this ONCE, manually, before any terraform init.
# Creates the storage account that will hold your remote state.
set -e

RESOURCE_GROUP="rg-tfstate"
STORAGE_ACCOUNT="sttfstateorg$RANDOM"   # must be globally unique across all of Azure
CONTAINER="tfstate"
LOCATION="centralindia"

az group create --name $RESOURCE_GROUP --location $LOCATION

az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2

az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT

echo ""
echo "Backend created. Put these values into environments/lab/backend.tf:"
echo "resource_group_name  = \"$RESOURCE_GROUP\""
echo "storage_account_name = \"$STORAGE_ACCOUNT\""
echo "container_name       = \"$CONTAINER\""

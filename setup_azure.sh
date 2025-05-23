#!/bin/bash
# Azure configuration script for Blob Storage and Event Grid
# Usage: ./setup_azure.sh <webapp-name>

# Source the centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <webapp-name>"
    exit 1
fi

WEBAPP_NAME=$1
STORAGE_NAME=$(get_storage_name)
WEBHOOK_ENDPOINT="https://${WEBAPP_NAME}.azurewebsites.net/api/updates"

# Ensure resource group exists
echo "Ensuring resource group exists..."
ensure_resource_group
if [ $? -ne 0 ]; then
    echo "Failed to create or verify resource group. Check permissions and Azure CLI configuration."
    exit 1
fi

# Create Blob Storage account
echo "Creating storage account: $STORAGE_NAME"
az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind BlobStorage \
  --access-tier Hot \
  --allow-blob-public-access false

# Wait for storage account to be fully provisioned
echo "Waiting for storage account provisioning to complete..."
while true; do
  state=$(az storage account show --name $STORAGE_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" -o tsv)
  if [ "$state" == "Succeeded" ]; then
    echo "Storage account provisioned."
    break
  fi
  echo "Provisioning state: $state. Waiting 5 seconds..."
  sleep 5
done

# Create container
echo "Creating container: $CONTAINER_NAME"
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_NAME \
  --auth-mode login

# Get storage account ID
STORAGE_ID=$(az storage account show --name $STORAGE_NAME --resource-group $RESOURCE_GROUP --query id --output tsv)

# Create Event Grid subscription
echo "Creating Event Grid subscription for webhook: $WEBHOOK_ENDPOINT"
az eventgrid event-subscription create \
  --name blob-events-subscription \
  --source-resource-id $STORAGE_ID \
  --endpoint-type webhook \
  --endpoint $WEBHOOK_ENDPOINT \
  --included-event-types Microsoft.Storage.BlobCreated Microsoft.Storage.BlobDeleted \
  --subject-begins-with "/blobServices/default/containers/$CONTAINER_NAME"

echo "Setup complete. Storage account: $STORAGE_NAME, Container: $CONTAINER_NAME"
#!/bin/bash
# Cleanup script to delete all Azure resources by removing the entire resource group
# Usage: ./cleanup.sh [--force]
# The --force flag skips the confirmation prompt

# Source the centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Ensure we're connected to Azure
ensure_azure_connection
if [ $? -ne 0 ]; then
    echo "Failed to authenticate with Azure CLI. Please check your credentials."
    exit 1
fi

# Check if the resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "Resource group '$RESOURCE_GROUP' does not exist. Nothing to clean up."
    exit 0
fi

# Check for --force flag
if [ "$1" != "--force" ]; then
    echo "WARNING: This will delete ALL resources in resource group '$RESOURCE_GROUP'."
    echo "This includes:"
    echo " - All storage accounts and blob containers"
    echo " - All App Service Plans and Web Apps"
    echo " - All Event Grid subscriptions"
    echo " - All other Azure resources in this resource group"
    echo ""
    echo "This action CANNOT be undone."
    echo ""
    read -p "Are you sure you want to proceed? (y/N): " confirm
    
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

echo "Deleting resource group '$RESOURCE_GROUP'..."
echo "This may take several minutes..."

# Delete the resource group
az group delete --name "$RESOURCE_GROUP" --yes

if [ $? -eq 0 ]; then
    echo "Resource group '$RESOURCE_GROUP' and all associated resources have been successfully deleted."
else
    echo "Failed to delete resource group '$RESOURCE_GROUP'. Check Azure CLI output for details."
    exit 1
fi

echo "Cleanup complete."

#!/bin/bash
# Central configuration file for environment variables
# This file should be sourced by other scripts

# Azure Resource Configuration
export RESOURCE_GROUP="gna-blob-to-kafka-rg"
export LOCATION="francecentral"
export CONTAINER_NAME="gnasri-container"
export AZURE_USERNAME=$(openssl rand -hex 4) 
export AZURE_PASSWORD=$(openssl rand -hex 4) 

# Naming conventions (with optional random suffix for uniqueness)
get_app_service_plan_name() {
    local suffix=${1:-$(openssl rand -hex 4)}
    echo "gna-asp-${suffix}"
}

get_storage_name() {
    local suffix=${1:-$(openssl rand -hex 4)}
    echo "gnablobstorage${suffix}"
}

# Kafka Configuration
export KAFKA_BOOTSTRAP_SERVERS="pkc-5roon.us-east-1.aws.confluent.cloud:9092"
export KAFKA_API_KEY="DPMLFBCUZVRUTSLU"
export KAFKA_API_SECRET="V8EkN7ucSE55FuwuOCE53x24i0rMAYpUHFzwJIX0d7yXIJuA/FB5Fhn2ohOBPqUn"
export KAFKA_TOPIC="gna-blob-events"

# Helper function to ensure Azure CLI is authenticated
ensure_azure_connection() {
    echo "Checking Azure CLI authentication..."
    if ! az account show &>/dev/null; then
        echo "Error: Not logged in to Azure CLI. Running 'az login'..."
        az login
        if [ $? -ne 0 ]; then
            echo "Azure login failed. Please run 'az login' manually."
            return 1
        fi
    fi
    echo "Azure CLI authenticated successfully."
    return 0
}

# Helper function to ensure resource group exists
ensure_resource_group() {
    # First ensure we're connected to Azure
    ensure_azure_connection || return 1
    
    if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
        echo "Creating resource group: $RESOURCE_GROUP"
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        return $?
    else
        echo "Resource group $RESOURCE_GROUP already exists."
        return 0
    fi
}

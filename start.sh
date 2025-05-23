#!/bin/bash
# Start script for Azure Blob Storage to Confluent Cloud Kafka integration
# Usage: ./start.sh <webapp-name>

# Source the centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <webapp-name>"
    exit 1
fi

WEBAPP_NAME=$1


# Deploy the webhook with retries
echo "Deploying Azure Web App..."
chmod +x deploy_webapp.sh
for i in {1..3}; do
    ./deploy_webapp.sh $WEBAPP_NAME && break
    echo "Web App deployment failed. Retrying in 10 seconds... (Attempt $i/3)"
    sleep 10
done
if [ $? -ne 0 ]; then
    echo "Web App deployment failed after retries. Check webapp_deploy.log and deploy_webapp.sh output."
    exit 1
fi

# Configure Azure resources
echo "Configuring Azure resources..."
chmod +x setup_azure.sh
STORAGE_NAME=$(./setup_azure.sh $WEBAPP_NAME | grep -oP 'Storage account: \K[^ ]+')
if [ $? -ne 0 ] || [ -z "$STORAGE_NAME" ]; then
    echo "Azure setup failed or storage account name not found. Check setup_azure.sh output and Azure CLI configuration."
    exit 1
fi
echo "Storage account name: $STORAGE_NAME"

#Test file upload
echo "Uploading test file to Blob Storage..."
export STORAGE_ACCOUNT_NAME=$STORAGE_NAME
python3 test_upload.py
if [ $? -ne 0 ]; then
    echo "Test upload failed. Check test_upload.py and Azure credentials."
    exit 1
fi


#Instructions for consuming Kafka events
echo "Setup and test upload complete!"
echo "To verify events in Kafka, run the following in a separate terminal:"
echo "export KAFKA_BOOTSTRAP_SERVERS=$KAFKA_BOOTSTRAP_SERVERS"
echo "export KAFKA_API_KEY=$KAFKA_API_KEY"
echo "export KAFKA_API_SECRET=$KAFKA_API_SECRET"
echo "export KAFKA_TOPIC=$KAFKA_TOPIC"
echo "python3 test_consumer.py"

echo "Webhook is running at: https://${WEBAPP_NAME}.azurewebsites.net/api/updates"
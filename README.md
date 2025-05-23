# Azure Blob Storage to Confluent Cloud Kafka Integration

This demo captures Azure Blob Storage creation and deletion events and forwards them to Confluent Cloud Kafka. It uses Azure Event Grid to detect blob events and a Flask-based webhook to process and forward these events to Kafka.

## Architecture Overview

```
Azure Blob Storage → Azure Event Grid → Flask Webhook → Confluent Cloud Kafka
```

## Prerequisites

- Azure CLI installed and configured
- Python 3.9+
- Confluent Cloud Kafka cluster
- Appropriate Azure permissions to create resources

## Configuration

All configuration is centralized in `config.sh`, which includes:
- Azure resource settings (resource group, location, container name)
- Kafka connection parameters
- Helper functions for resource naming and management

## Setup Process

1. **Initialize the Project**
   ```bash
   # Clone the repository and navigate to the project directory
   git clone <repository-url>
   cd blobEventWebhook
   
   # Install dependencies
   pip install -r requirements.txt
   ```

2. **Deploy the Solution**
   ```bash
   # Run the start script with your desired web app name
   ./start.sh <webapp-name>
   ```

   This script performs the following steps:
   - Installs Python dependencies
   - Deploys a Flask webhook to Azure Web App
   - Sets up Azure Blob Storage and Event Grid subscription
   - Uploads a test file to verify the setup

## Key Components

### 1. Azure Web App Deployment (`deploy_webapp.sh`)
- Creates an App Service Plan
- Deploys the Flask webhook application
- Configures environment variables for Kafka connection

### 2. Azure Resources Setup (`setup_azure.sh`)
- Creates a resource group (if it doesn't exist)
- Provisions a Blob Storage account
- Creates a container for blob storage
- Sets up an Event Grid subscription to send events to the webhook

### 3. Flask Webhook Application (`app.py`)
- Receives blob events from Event Grid
- Validates Event Grid subscriptions
- Processes blob creation/deletion events
- Forwards events to Confluent Cloud Kafka

### 4. Testing Tools
- `test_upload.py`: Uploads a test file to Azure Blob Storage
- `test_consumer.py`: Consumes events from Kafka to verify end-to-end flow

## Monitoring and Verification

1. **Verify Webhook Deployment**
   - The webhook endpoint should be accessible at `https://<webapp-name>.azurewebsites.net/api/updates`
   - A test endpoint is available at `https://<webapp-name>.azurewebsites.net/api/test`

2. **Test Event Flow**
   - Upload files to the blob container to generate creation events
   - Delete files from the blob container to generate deletion events
   - Use `test_consumer.py` to verify events are being received in Kafka

## Troubleshooting

- Check `webapp_deploy.log` for deployment issues
- Azure Web App logs can be viewed in the Azure Portal
- Ensure Azure CLI is authenticated with `az login`
- Verify Confluent Cloud credentials are correct

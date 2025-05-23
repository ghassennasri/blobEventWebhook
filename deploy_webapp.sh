#!/bin/bash
# Deploy Flask app to Azure Web App
# Usage: ./deploy_webapp.sh <webapp-name>

# Source the centralized configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <webapp-name>"
    exit 1
fi

WEBAPP_NAME=$1
APP_SERVICE_PLAN=$(get_app_service_plan_name)

# Ensure Azure connection and resource group exist
ensure_azure_connection
if [ $? -ne 0 ]; then
    echo "Failed to authenticate with Azure CLI. Please check your credentials."
    exit 1
fi

ensure_resource_group
if [ $? -ne 0 ]; then
    echo "Failed to create or verify resource group. Check permissions and Azure CLI configuration."
    exit 1
fi

# Check for required files
if [ ! -f "app.py" ] || [ ! -f "requirements.txt" ] || [ ! -f "startup.sh" ]; then
    echo "Error: app.py, requirements.txt, or startup.sh not found in current directory."
    exit 1
fi

# Create runtime.txt to specify Python version
echo "Creating runtime.txt..."
echo "python-3.9" > runtime.txt

# Validate requirements.txt locally with Python 3.9
echo "Validating requirements.txt locally with Python 3.9..."
python3.9 -m venv temp_venv
source temp_venv/bin/activate
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "Failed to install dependencies locally. Fix requirements.txt and try again."
    rm -rf temp_venv
    exit 1
fi
rm -rf temp_venv



# Check if App Service Plan exists, create if not
echo "Checking App Service Plan..."
if ! az appservice plan show --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP > /dev/null 2>&1; then
    echo "Creating App Service Plan: $APP_SERVICE_PLAN"
    az appservice plan create \
      --name $APP_SERVICE_PLAN \
      --resource-group $RESOURCE_GROUP \
      --location $LOCATION \
      --sku B1 \
      --is-linux > webapp_deploy.log 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to create App Service Plan. Check webapp_deploy.log for details."
        exit 1
    fi
else
    echo "App Service Plan $APP_SERVICE_PLAN already exists."
fi

# Check if Web App exists, create if not
echo "Checking Azure Web App: $WEBAPP_NAME"
if ! az webapp show --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1; then
    echo "Creating Azure Web App: $WEBAPP_NAME"
    az webapp create \
      --name $WEBAPP_NAME \
      --resource-group $RESOURCE_GROUP \
      --plan $APP_SERVICE_PLAN \
      --runtime "PYTHON|3.9" >> webapp_deploy.log 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to create Web App. Check webapp_deploy.log for details."
        echo "Common issues: Name already taken, insufficient permissions, or region unavailable."
        exit 1
    fi
else
    echo "Web App $WEBAPP_NAME already exists."
fi

# Ensure Python runtime and build settings
echo "Configuring Python runtime and build settings..."
az webapp config set --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP --linux-fx-version "PYTHON|3.9" >> webapp_deploy.log 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to set Python runtime. Check webapp_deploy.log for details."
    exit 1
fi
az webapp config appsettings set \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true PYTHON_VERSION=3.9 >> webapp_deploy.log 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to set build settings. Check Azure permissions."
    exit 1
fi

# Ensure startup.sh is executable
echo "Making startup.sh executable..."
chmod +x startup.sh

# Create ZIP file for deployment
echo "Creating ZIP file for deployment..."
rm -f app.zip
zip -r app.zip app.py requirements.txt startup.sh runtime.txt -x "*.csproj" "*.sln"
if [ $? -ne 0 ] || [ ! -f "app.zip" ]; then
    echo "Failed to create app.zip."
    exit 1
fi
unzip -l app.zip | grep -E "app.py|requirements.txt|startup.sh|runtime.txt"
if [ $? -ne 0 ]; then
    echo "Error: One or more required files (app.py, requirements.txt, startup.sh, runtime.txt) missing in app.zip."
    rm -f app.zip
    exit 1
fi

#set username and password for Kudu
echo "Setting Kudu credentials..."
az webapp deployment user set \
  --user-name $AZURE_USERNAME \
  --password $AZURE_PASSWORD >> webapp_deploy.log 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to set Kudu credentials. Check Azure permissions."
    exit 1
fi

# Deploy app.py and requirements.txt
echo "Deploying app.py and requirements.txt to Web App..."
az webapp deployment source config-zip \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP \
  --src app.zip >> webapp_deploy.log 2>&1
DEPLOY_STATUS=$?
if [ $DEPLOY_STATUS -ne 0 ]; then
    echo "Failed to deploy app files. Check webapp_deploy.log and Kudu logs at https://$WEBAPP_NAME.scm.azurewebsites.net/api/logstream."
    rm -f app.zip
    exit 1
fi
rm -f app.zip

# Configure the startup command
echo "Configuring startup command..."
az webapp config set \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP \
  --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 app:app" >> webapp_deploy.log 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to set startup command. Check webapp_deploy.log for details."
    exit 1
fi

# Restart Web App
echo "Restarting Web App..."
az webapp restart --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP >> webapp_deploy.log 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to restart Web App. Check Azure portal."
    exit 1
fi

# Verify Web App is running
echo "Verifying Web App creation..."
WEBAPP_STATE=$(az webapp show --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP --query state --output tsv)
if [ "$WEBAPP_STATE" != "Running" ]; then
    echo "Web App $WEBAPP_NAME is not running. Current state: $WEBAPP_STATE. Check Azure portal and webapp_deploy.log."
    exit 1
fi

# Verify app.py and requirements.txt deployment
echo "Verifying app.py and requirements.txt deployment..."
CREDENTIALS=$(az webapp deployment user show --query publishingUserName --output tsv)
if curl -s -u "$CREDENTIALS" "https://${WEBAPP_NAME}.scm.azurewebsites.net/api/vfs/site/wwwroot/app.py" > /dev/null; then
    echo "app.py successfully deployed to Web App."
else
    echo "app.py not found on Web App. Check deployment logs and Azure portal."
    exit 1
fi
if curl -s -u "$CREDENTIALS" "https://${WEBAPP_NAME}.scm.azurewebsites.net/api/vfs/site/wwwroot/requirements.txt" > /dev/null; then
    echo "requirements.txt successfully deployed to Web App."
else
    echo "requirements.txt not found on Web App. Check deployment logs and Azure portal."
    exit 1
fi

# Test webhook endpoint
echo "Testing webhook endpoint: https://${WEBAPP_NAME}.azurewebsites.net/api/updates"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST https://${WEBAPP_NAME}.azurewebsites.net/api/updates \
  -H "Content-Type: application/json" \
  -d '{"eventType":"Microsoft.EventGrid.SubscriptionValidationEvent","data":{"validationCode":"test123"}}')
echo $HTTP_CODE > webhook_test.log
if [ "$HTTP_CODE" != "200" ]; then
    echo "Webhook endpoint not responding (HTTP $HTTP_CODE). Check Web App logs in Azure portal."
    exit 1
fi

# Set environment variables for Confluent Cloud
echo "Setting environment variables..."
az webapp config appsettings set \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    KAFKA_BOOTSTRAP_SERVERS="$KAFKA_BOOTSTRAP_SERVERS" \
    KAFKA_API_KEY="$KAFKA_API_KEY" \
    KAFKA_API_SECRET="$KAFKA_API_SECRET" \
    KAFKA_TOPIC="$KAFKA_TOPIC" >> webapp_deploy.log 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to set environment variables. Check Azure permissions and Confluent Cloud credentials."
    exit 1
fi

echo "Deployment complete. Webhook URL: https://${WEBAPP_NAME}.azurewebsites.net/api/updates"
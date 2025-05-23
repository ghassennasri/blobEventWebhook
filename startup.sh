#!/bin/bash
# Startup script for Flask app on Azure Web App

# Ensure the virtual environment is set up
echo "Setting up virtual environment..."
python3.9 -m venv /home/site/wwwroot/antenv
source /home/site/wwwroot/antenv/bin/activate

# Upgrade pip and install dependencies
echo "Installing dependencies from requirements.txt..."
python3.9 -m pip install --upgrade pip
python3.9 -m pip install -r /home/site/wwwroot/requirements.txt

# Start the Flask app with Gunicorn
echo "Starting Flask app with Gunicorn..."
gunicorn --bind=0.0.0.0:8000 --timeout 600 app:app
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
import os

def upload_test_file(storage_account_name, container_name, blob_name, file_path):
    """Upload a test file to Azure Blob Storage"""
    try:
        # Authenticate using Azure credentials
        credential = DefaultAzureCredential()
        blob_service_client = BlobServiceClient(
            account_url=f"https://{storage_account_name}.blob.core.windows.net",
            credential=credential
        )

        # Get container client
        container_client = blob_service_client.get_container_client(container_name)

        # Upload file
        with open(file_path, "rb") as data:
            container_client.upload_blob(name=blob_name, data=data, overwrite=True)
        print(f"Uploaded {file_path} to {container_name}/{blob_name}")

    except Exception as e:
        print(f"Error uploading file: {e}")

if __name__ == "__main__":
    # Configuration
    storage_account = os.environ.get("STORAGE_ACCOUNT_NAME", "<your-storage-account>")
    container = os.environ.get("CONTAINER_NAME", "gnasri-container")
    test_blob = "testfile.txt"
    test_file_path = "testfile.txt"

    # Create a test file
    with open(test_file_path, "w") as f:
        f.write("This is a test file for Blob Storage events.")

    # Upload test file
    upload_test_file(storage_account, container, test_blob, test_file_path)
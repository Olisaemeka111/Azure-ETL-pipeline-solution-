#!/bin/bash

# Azure Data Factory Pipeline Deployment Script
# This script deploys Data Factory pipelines, datasets, and linked services

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check if outputs.json exists
    if [ ! -f "outputs.json" ]; then
        print_error "outputs.json not found. Please run deploy-infrastructure.sh first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to get resource information
get_resource_info() {
    print_status "Reading resource information..."
    
    RESOURCE_GROUP=$(jq -r '.resource_group_name.value' outputs.json)
    DATA_FACTORY_NAME=$(jq -r '.data_factory_name.value' outputs.json)
    STORAGE_ACCOUNT_NAME=$(jq -r '.storage_account_name.value' outputs.json)
    KEY_VAULT_NAME=$(jq -r '.key_vault_name.value' outputs.json)
    DATABRICKS_WORKSPACE_URL=$(jq -r '.databricks_workspace_url.value' outputs.json)
    SQL_SERVER_NAME=$(jq -r '.sql_server_name.value' outputs.json)
    SQL_DATABASE_NAME=$(jq -r '.sql_database_name.value' outputs.json)
    
    print_success "Resource information loaded"
}

# Function to update linked services with actual values
update_linked_services() {
    print_status "Updating linked services with actual resource values..."
    
    # Create temporary directory for updated files
    mkdir -p temp
    
    # Update linked services JSON with actual values
    cat > temp/linked-services-updated.json << EOF
{
  "name": "AzureDataLakeStorageGen2LinkedService",
  "properties": {
    "annotations": [],
    "type": "AzureBlobFS",
    "typeProperties": {
      "url": "https://${STORAGE_ACCOUNT_NAME}.dfs.core.windows.net",
      "accountKey": {
        "type": "AzureKeyVaultSecret",
        "store": {
          "referenceName": "AzureKeyVaultLinkedService",
          "type": "LinkedServiceReference"
        },
        "secretName": "datalake-storage-key"
      }
    }
  }
}

{
  "name": "AzureDatabricksLinkedService",
  "properties": {
    "annotations": [],
    "type": "AzureDatabricks",
    "typeProperties": {
      "domain": "${DATABRICKS_WORKSPACE_URL}",
      "accessToken": {
        "type": "AzureKeyVaultSecret",
        "store": {
          "referenceName": "AzureKeyVaultLinkedService",
          "type": "LinkedServiceReference"
        },
        "secretName": "databricks-access-token"
      },
      "existingClusterId": "1234-567890-abc123"
    }
  }
}

{
  "name": "AzureSqlDatabaseLinkedService",
  "properties": {
    "annotations": [],
    "type": "AzureSqlDatabase",
    "typeProperties": {
      "connectionString": {
        "type": "AzureKeyVaultSecret",
        "store": {
          "referenceName": "AzureKeyVaultLinkedService",
          "type": "LinkedServiceReference"
        },
        "secretName": "sql-connection-string"
      }
    }
  }
}

{
  "name": "AzureKeyVaultLinkedService",
  "properties": {
    "annotations": [],
    "type": "AzureKeyVault",
    "typeProperties": {
      "baseUrl": "https://${KEY_VAULT_NAME}.vault.azure.net/"
    }
  }
}
EOF
    
    print_success "Linked services updated with actual values"
}

# Function to deploy linked services
deploy_linked_services() {
    print_status "Deploying linked services..."
    
    # Deploy each linked service
    az datafactory linked-service create \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --linked-service-name "AzureKeyVaultLinkedService" \
        --properties @temp/linked-services-updated.json
    
    az datafactory linked-service create \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --linked-service-name "AzureDataLakeStorageGen2LinkedService" \
        --properties @temp/linked-services-updated.json
    
    az datafactory linked-service create \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --linked-service-name "AzureSqlDatabaseLinkedService" \
        --properties @temp/linked-services-updated.json
    
    az datafactory linked-service create \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --linked-service-name "AzureDatabricksLinkedService" \
        --properties @temp/linked-services-updated.json
    
    print_success "Linked services deployed successfully"
}

# Function to deploy datasets
deploy_datasets() {
    print_status "Deploying datasets..."
    
    # Deploy datasets
    az datafactory dataset create \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --name "RawDataDataset" \
        --properties @adf-pipelines/datasets.json
    
    print_success "Datasets deployed successfully"
}

# Function to deploy pipelines
deploy_pipelines() {
    print_status "Deploying pipelines..."
    
    # Deploy main ETL pipeline
    az datafactory pipeline create \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --name "MainETLPipeline" \
        --pipeline @adf-pipelines/main-etl-pipeline.json
    
    print_success "Pipelines deployed successfully"
}

# Function to create triggers
create_triggers() {
    print_status "Creating triggers..."
    
    # Create daily trigger
    cat > temp/daily-trigger.json << EOF
{
  "name": "DailyETLTrigger",
  "properties": {
    "description": "Daily trigger for ETL pipeline",
    "annotations": [],
    "runtimeState": "Started",
    "pipelines": [
      {
        "pipelineReference": {
          "referenceName": "MainETLPipeline",
          "type": "PipelineReference"
        },
        "parameters": {
          "processingDate": "@formatDateTime(adddays(utcnow(), -1), 'yyyy-MM-dd')"
        }
      }
    ],
    "type": "ScheduleTrigger",
    "typeProperties": {
      "recurrence": {
        "frequency": "Day",
        "interval": 1,
        "startTime": "2024-01-01T02:00:00Z",
        "endTime": "2025-12-31T23:59:59Z",
        "timeZone": "UTC"
      }
    }
  }
}
EOF
    
    # Create the trigger
    az datafactory trigger create \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --name "DailyETLTrigger" \
        --properties @temp/daily-trigger.json
    
    print_success "Triggers created successfully"
}

# Function to start triggers
start_triggers() {
    print_status "Starting triggers..."
    
    # Start the trigger
    az datafactory trigger start \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --name "DailyETLTrigger"
    
    print_success "Triggers started successfully"
}

# Function to clean up temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    
    if [ -d "temp" ]; then
        rm -rf temp
    fi
    
    print_success "Cleanup completed"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # List linked services
    print_status "Linked Services:"
    az datafactory linked-service list \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --query '[].name' -o table
    
    # List datasets
    print_status "Datasets:"
    az datafactory dataset list \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --query '[].name' -o table
    
    # List pipelines
    print_status "Pipelines:"
    az datafactory pipeline list \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --query '[].name' -o table
    
    # List triggers
    print_status "Triggers:"
    az datafactory trigger list \
        --resource-group $RESOURCE_GROUP \
        --factory-name $DATA_FACTORY_NAME \
        --query '[].name' -o table
    
    print_success "Deployment verification completed"
}

# Main deployment function
main() {
    print_status "Starting Azure Data Factory Pipeline Deployment"
    print_status "=============================================="
    
    # Check prerequisites
    check_prerequisites
    
    # Get resource information
    get_resource_info
    
    # Update linked services
    update_linked_services
    
    # Deploy components
    deploy_linked_services
    deploy_datasets
    deploy_pipelines
    create_triggers
    start_triggers
    
    # Verify deployment
    verify_deployment
    
    # Clean up
    cleanup
    
    print_success "Data Factory pipeline deployment completed successfully!"
    print_status "Next steps:"
    print_status "1. Deploy Databricks notebooks: ./deploy-databricks-notebooks.sh"
    print_status "2. Configure monitoring: ./setup-monitoring.sh"
    print_status "3. Test the pipeline execution"
}

# Run main function
main "$@"

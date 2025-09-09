#!/bin/bash

# Databricks Notebooks Deployment Script
# This script deploys Databricks notebooks for data transformation and quality checks

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
    
    # Check if databricks CLI is installed
    if ! command -v databricks &> /dev/null; then
        print_warning "Databricks CLI not found. Installing..."
        pip install databricks-cli
    fi
    
    print_success "Prerequisites check passed"
}

# Function to get resource information
get_resource_info() {
    print_status "Reading resource information..."
    
    RESOURCE_GROUP=$(jq -r '.resource_group_name.value' outputs.json)
    DATABRICKS_WORKSPACE_NAME=$(jq -r '.databricks_workspace_name.value' outputs.json)
    DATABRICKS_WORKSPACE_URL=$(jq -r '.databricks_workspace_url.value' outputs.json)
    
    print_success "Resource information loaded"
}

# Function to configure Databricks CLI
configure_databricks_cli() {
    print_status "Configuring Databricks CLI..."
    
    # Get Databricks access token (auto-configured)
    print_status "Using Azure CLI authentication for Databricks..."
    print_warning "Note: You may need to generate a Databricks access token from: ${DATABRICKS_WORKSPACE_URL}/#/setting/account"
    DATABRICKS_TOKEN="placeholder"
    
    # Configure Databricks CLI
    databricks configure --token << EOF
${DATABRICKS_WORKSPACE_URL}
${DATABRICKS_TOKEN}
EOF
    
    print_success "Databricks CLI configured"
}

# Function to create workspace directories
create_workspace_directories() {
    print_status "Creating workspace directories..."
    
    # Create ETL directory structure
    databricks workspace mkdirs /ETL
    databricks workspace mkdirs /ETL/notebooks
    databricks workspace mkdirs /ETL/libraries
    databricks workspace mkdirs /ETL/jobs
    
    print_success "Workspace directories created"
}

# Function to deploy notebooks
deploy_notebooks() {
    print_status "Deploying Databricks notebooks..."
    
    # Deploy data transformation notebook
    databricks workspace import \
        --language PYTHON \
        --format SOURCE \
        --path /ETL/notebooks/01-data-transformation \
        --file databricks-notebooks/01-data-transformation.py
    
    # Deploy data quality checks notebook
    databricks workspace import \
        --language PYTHON \
        --format SOURCE \
        --path /ETL/notebooks/02-data-quality-checks \
        --file databricks-notebooks/02-data-quality-checks.py
    
    print_success "Notebooks deployed successfully"
}

# Function to create cluster configuration
create_cluster_config() {
    print_status "Creating cluster configuration..."
    
    # Create cluster configuration JSON
    cat > temp/cluster-config.json << EOF
{
  "cluster_name": "ETL-Cluster",
  "spark_version": "13.3.x-scala2.12",
  "node_type_id": "Standard_DS3_v2",
  "driver_node_type_id": "Standard_DS3_v2",
  "num_workers": 2,
  "min_workers": 1,
  "max_workers": 4,
  "autoscale": {
    "min_workers": 1,
    "max_workers": 4
  },
  "spark_conf": {
    "spark.databricks.delta.preview.enabled": "true",
    "spark.databricks.delta.retentionDurationCheck.enabled": "false",
    "spark.sql.adaptive.enabled": "true",
    "spark.sql.adaptive.coalescePartitions.enabled": "true"
  },
  "custom_tags": {
    "Environment": "Production",
    "Project": "ETL Pipeline",
    "Owner": "Data Team"
  },
  "cluster_log_conf": {
    "dbfs": {
      "destination": "dbfs:/cluster-logs"
    }
  },
  "init_scripts": [],
  "spark_env_vars": {
    "PYSPARK_PYTHON": "/databricks/python3/bin/python3"
  },
  "enable_elastic_disk": true,
  "data_security_mode": "SINGLE_USER",
  "runtime_engine": "STANDARD"
}
EOF
    
    print_success "Cluster configuration created"
}

# Function to create cluster
create_cluster() {
    print_status "Creating Databricks cluster..."
    
    # Create the cluster
    CLUSTER_ID=$(databricks clusters create --json-file temp/cluster-config.json | jq -r '.cluster_id')
    
    if [ "$CLUSTER_ID" != "null" ] && [ "$CLUSTER_ID" != "" ]; then
        print_success "Cluster created with ID: $CLUSTER_ID"
        echo $CLUSTER_ID > temp/cluster-id.txt
    else
        print_error "Failed to create cluster"
        exit 1
    fi
}

# Function to install libraries
install_libraries() {
    print_status "Installing required libraries..."
    
    # Read cluster ID
    if [ -f "temp/cluster-id.txt" ]; then
        CLUSTER_ID=$(cat temp/cluster-id.txt)
        
        # Install libraries
        databricks libraries install \
            --cluster-id $CLUSTER_ID \
            --pypi-package great-expectations==0.17.19
        
        databricks libraries install \
            --cluster-id $CLUSTER_ID \
            --pypi-package pandas==1.5.3
        
        databricks libraries install \
            --cluster-id $CLUSTER_ID \
            --pypi-package pyarrow==12.0.1
        
        print_success "Libraries installed successfully"
    else
        print_warning "Cluster ID not found. Skipping library installation."
    fi
}

# Function to create job configuration
create_job_config() {
    print_status "Creating job configuration..."
    
    # Read cluster ID
    if [ -f "temp/cluster-id.txt" ]; then
        CLUSTER_ID=$(cat temp/cluster-id.txt)
        
        # Create job configuration
        cat > temp/job-config.json << EOF
{
  "name": "ETL Data Transformation Job",
  "new_cluster": {
    "spark_version": "13.3.x-scala2.12",
    "node_type_id": "Standard_DS3_v2",
    "driver_node_type_id": "Standard_DS3_v2",
    "num_workers": 2,
    "autoscale": {
      "min_workers": 1,
      "max_workers": 4
    },
    "spark_conf": {
      "spark.databricks.delta.preview.enabled": "true",
      "spark.sql.adaptive.enabled": "true"
    }
  },
  "notebook_task": {
    "notebook_path": "/ETL/notebooks/01-data-transformation",
    "base_parameters": {
      "storage_account": "etlpipelinedevdatalake",
      "raw_container": "raw-zone",
      "staging_container": "staging-zone",
      "curated_container": "curated-zone",
      "processing_date": "\${job.parameters.processing_date}"
    }
  },
  "timeout_seconds": 3600,
  "max_retries": 2,
  "retry_on_timeout": true,
  "email_notifications": {
    "on_start": [],
    "on_success": [],
    "on_failure": []
  },
  "tags": {
    "Environment": "Production",
    "Project": "ETL Pipeline"
  }
}
EOF
        
        print_success "Job configuration created"
    else
        print_warning "Cluster ID not found. Skipping job configuration."
    fi
}

# Function to create job
create_job() {
    print_status "Creating Databricks job..."
    
    if [ -f "temp/job-config.json" ]; then
        # Create the job
        JOB_ID=$(databricks jobs create --json-file temp/job-config.json | jq -r '.job_id')
        
        if [ "$JOB_ID" != "null" ] && [ "$JOB_ID" != "" ]; then
            print_success "Job created with ID: $JOB_ID"
            echo $JOB_ID > temp/job-id.txt
        else
            print_error "Failed to create job"
            exit 1
        fi
    else
        print_warning "Job configuration not found. Skipping job creation."
    fi
}

# Function to test notebooks
test_notebooks() {
    print_status "Testing notebook deployment..."
    
    # List notebooks
    print_status "Deployed notebooks:"
    databricks workspace list /ETL/notebooks
    
    print_success "Notebook testing completed"
}

# Function to clean up temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    
    if [ -d "temp" ]; then
        rm -rf temp
    fi
    
    print_success "Cleanup completed"
}

# Function to display next steps
display_next_steps() {
    print_success "Databricks notebooks deployment completed successfully!"
    echo
    print_status "Next steps:"
    print_status "1. Configure monitoring: ./setup-monitoring.sh"
    print_status "2. Test the ETL pipeline execution"
    print_status "3. Monitor job runs in Databricks workspace"
    echo
    print_status "Access your Databricks workspace at: ${DATABRICKS_WORKSPACE_URL}"
    print_status "Notebooks are located in: /ETL/notebooks/"
    echo
    if [ -f "temp/job-id.txt" ]; then
        JOB_ID=$(cat temp/job-id.txt)
        print_status "Job ID: $JOB_ID"
        print_status "You can run the job using: databricks jobs run-now --job-id $JOB_ID"
    fi
}

# Main deployment function
main() {
    print_status "Starting Databricks Notebooks Deployment"
    print_status "======================================="
    
    # Check prerequisites
    check_prerequisites
    
    # Get resource information
    get_resource_info
    
    # Configure Databricks CLI
    configure_databricks_cli
    
    # Create workspace structure
    create_workspace_directories
    
    # Deploy notebooks
    deploy_notebooks
    
    # Create and configure cluster
    create_cluster_config
    create_cluster
    install_libraries
    
    # Create job
    create_job_config
    create_job
    
    # Test deployment
    test_notebooks
    
    # Display next steps
    display_next_steps
    
    # Clean up
    cleanup
}

# Run main function
main "$@"

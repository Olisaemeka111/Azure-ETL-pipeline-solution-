#!/bin/bash

# Azure ETL Pipeline Infrastructure Deployment Script
# This script deploys the complete infrastructure using Terraform

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
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to validate configuration
validate_config() {
    print_status "Validating configuration..."
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        if [ -f "terraform/terraform.tfvars.example" ]; then
            cp terraform/terraform.tfvars.example terraform/terraform.tfvars
            print_warning "Please edit terraform/terraform.tfvars with your values before continuing."
            read -p "Press Enter to continue after editing the file..."
        else
            print_error "terraform.tfvars.example not found. Please create terraform.tfvars manually."
            exit 1
        fi
    fi
    
    print_success "Configuration validation passed"
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    if [ $? -eq 0 ]; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    cd ..
}

# Function to plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    
    cd terraform
    
    # Create Terraform plan
    terraform plan -out=tfplan
    
    if [ $? -eq 0 ]; then
        print_success "Terraform plan created successfully"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
    
    cd ..
}

# Function to apply Terraform deployment
apply_terraform() {
    print_status "Applying Terraform deployment..."
    
    cd terraform
    
    # Apply Terraform plan
    terraform apply tfplan
    
    if [ $? -eq 0 ]; then
        print_success "Terraform deployment completed successfully"
    else
        print_error "Terraform deployment failed"
        exit 1
    fi
    
    cd ..
}

# Function to save outputs
save_outputs() {
    print_status "Saving Terraform outputs..."
    
    cd terraform
    
    # Save outputs to file
    terraform output -json > ../outputs.json
    
    if [ $? -eq 0 ]; then
        print_success "Terraform outputs saved to outputs.json"
    else
        print_warning "Failed to save Terraform outputs"
    fi
    
    cd ..
}

# Function to configure Key Vault secrets
configure_key_vault() {
    print_status "Configuring Key Vault secrets..."
    
    # Read outputs
    if [ -f "outputs.json" ]; then
        KEY_VAULT_NAME=$(jq -r '.key_vault_name.value' outputs.json)
        STORAGE_ACCOUNT_NAME=$(jq -r '.storage_account_name.value' outputs.json)
        SQL_SERVER_NAME=$(jq -r '.sql_server_name.value' outputs.json)
        SQL_DATABASE_NAME=$(jq -r '.sql_database_name.value' outputs.json)
        
        # Get storage account key
        STORAGE_KEY=$(az storage account keys list \
            --resource-group $(jq -r '.resource_group_name.value' outputs.json) \
            --account-name $STORAGE_ACCOUNT_NAME \
            --query '[0].value' -o tsv)
        
        # Store secrets in Key Vault
        az keyvault secret set \
            --vault-name $KEY_VAULT_NAME \
            --name "datalake-storage-key" \
            --value "$STORAGE_KEY"
        
        # SQL connection string (you'll need to provide the password)
        read -s -p "Enter SQL admin password: " SQL_PASSWORD
        echo
        
        SQL_CONNECTION_STRING="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DATABASE_NAME};Persist Security Info=False;User ID=sqladmin;Password=${SQL_PASSWORD};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        
        az keyvault secret set \
            --vault-name $KEY_VAULT_NAME \
            --name "sql-connection-string" \
            --value "$SQL_CONNECTION_STRING"
        
        print_success "Key Vault secrets configured"
    else
        print_warning "outputs.json not found. Skipping Key Vault configuration."
    fi
}

# Function to create sample data
create_sample_data() {
    print_status "Creating sample data..."
    
    if [ -f "outputs.json" ]; then
        STORAGE_ACCOUNT_NAME=$(jq -r '.storage_account_name.value' outputs.json)
        RESOURCE_GROUP=$(jq -r '.resource_group_name.value' outputs.json)
        
        # Create sample CSV data
        cat > sample_data.csv << EOF
id,customer_name,email,phone,address,order_date,order_amount,product_category,processing_timestamp
1,John Doe,john.doe@email.com,555-1234,123 Main St,2024-01-15,99.99,Electronics,2024-01-15T10:00:00Z
2,Jane Smith,jane.smith@email.com,555-5678,456 Oak Ave,2024-01-15,149.50,Clothing,2024-01-15T10:01:00Z
3,Bob Johnson,bob.johnson@email.com,555-9012,789 Pine Rd,2024-01-15,75.25,Books,2024-01-15T10:02:00Z
4,Alice Brown,alice.brown@email.com,555-3456,321 Elm St,2024-01-15,200.00,Electronics,2024-01-15T10:03:00Z
5,Charlie Wilson,charlie.wilson@email.com,555-7890,654 Maple Dr,2024-01-15,89.99,Home,2024-01-15T10:04:00Z
EOF
        
        # Upload sample data to raw zone
        az storage blob upload \
            --account-name $STORAGE_ACCOUNT_NAME \
            --container-name raw-zone \
            --name "input/2024/01/15/sample_data.csv" \
            --file sample_data.csv \
            --auth-mode login
        
        # Clean up
        rm sample_data.csv
        
        print_success "Sample data created and uploaded"
    else
        print_warning "outputs.json not found. Skipping sample data creation."
    fi
}

# Main deployment function
main() {
    print_status "Starting Azure ETL Pipeline Infrastructure Deployment"
    print_status "=================================================="
    
    # Check prerequisites
    check_prerequisites
    
    # Validate configuration
    validate_config
    
    # Initialize Terraform
    init_terraform
    
    # Plan deployment
    plan_terraform
    
    # Ask for confirmation
    echo
    print_warning "This will create Azure resources that may incur costs."
    read -p "Do you want to continue with the deployment? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Apply deployment
        apply_terraform
        
        # Save outputs
        save_outputs
        
        # Configure Key Vault
        configure_key_vault
        
        # Create sample data
        create_sample_data
        
        print_success "Infrastructure deployment completed successfully!"
        print_status "Next steps:"
        print_status "1. Deploy Data Factory pipelines: ./deploy-adf-pipelines.sh"
        print_status "2. Deploy Databricks notebooks: ./deploy-databricks-notebooks.sh"
        print_status "3. Configure monitoring: ./setup-monitoring.sh"
        
    else
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

# Run main function
main "$@"

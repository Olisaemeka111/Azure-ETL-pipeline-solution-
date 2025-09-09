#!/bin/bash

# Azure ETL Pipeline - Complete Infrastructure Destruction Script
# This script destroys ALL Azure resources created for this project

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
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

# Function to check Azure login
check_azure_login() {
    print_status "Checking Azure login status..."
    if ! az account show >/dev/null 2>&1; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    print_success "Azure login verified"
}

# Function to destroy Terraform infrastructure
destroy_terraform_infrastructure() {
    print_status "Destroying Terraform-managed infrastructure..."
    
    cd terraform
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform for destruction..."
        terraform init -backend-config=backend-config.tfvars
    fi
    
    # Destroy infrastructure
    print_warning "Destroying all Terraform-managed resources..."
    terraform destroy -auto-approve
    
    print_success "Terraform infrastructure destroyed"
    cd ..
}

# Function to destroy Terraform state storage
destroy_terraform_state_storage() {
    print_status "Destroying Terraform state storage..."
    
    # Destroy the state storage resource group
    if az group show --name "rg-terraform-state" --output none 2>/dev/null; then
        print_status "Deleting Terraform state resource group..."
        az group delete --name "rg-terraform-state" --yes --no-wait
        print_success "Terraform state storage deletion initiated"
    else
        print_status "Terraform state resource group not found"
    fi
}

# Function to destroy any remaining ETL resources
destroy_etl_resources() {
    print_status "Destroying any remaining ETL resources..."
    
    # List all resource groups that might contain ETL resources
    ETL_RGS=$(az group list --query "[?contains(name, 'etl') || contains(name, 'rg-etl')].name" --output tsv)
    
    if [ -n "$ETL_RGS" ]; then
        print_warning "Found ETL-related resource groups:"
        echo "$ETL_RGS"
        
        for rg in $ETL_RGS; do
            print_status "Deleting resource group: $rg"
            az group delete --name $rg --yes --no-wait
            print_success "Deletion initiated for: $rg"
        done
    else
        print_status "No ETL resource groups found"
    fi
}

# Function to destroy any remaining Terraform state resources
destroy_remaining_terraform_resources() {
    print_status "Destroying any remaining Terraform state resources..."
    
    # List all resource groups that match Terraform state pattern
    TERRAFORM_RGS=$(az group list --query "[?contains(name, 'terraform-state')].name" --output tsv)
    
    if [ -n "$TERRAFORM_RGS" ]; then
        print_warning "Found Terraform state resource groups:"
        echo "$TERRAFORM_RGS"
        
        for rg in $TERRAFORM_RGS; do
            print_status "Deleting resource group: $rg"
            az group delete --name $rg --yes --no-wait
            print_success "Deletion initiated for: $rg"
        done
    else
        print_status "No Terraform state resource groups found"
    fi
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove Terraform files
    rm -rf terraform/.terraform/
    rm -f terraform/.terraform.lock.hcl
    rm -f terraform/terraform.tfstate*
    rm -f terraform/backend-config.tfvars
    rm -f terraform/outputs.json
    
    # Remove temporary files
    rm -rf temp/
    rm -rf tmp/
    rm -f *.log
    
    print_success "Local files cleaned up"
}

# Function to show final status
show_final_status() {
    print_status "Checking remaining resources..."
    
    # List all resource groups
    REMAINING_RGS=$(az group list --query "[].name" --output tsv)
    
    if [ -n "$REMAINING_RGS" ]; then
        print_warning "Remaining resource groups:"
        echo "$REMAINING_RGS"
    else
        print_success "No resource groups remaining"
    fi
    
    print_success "Infrastructure destruction completed!"
    print_warning "Note: Some deletions may take a few minutes to complete."
}

# Main function
main() {
    print_status "Azure ETL Pipeline - Complete Infrastructure Destruction"
    print_status "======================================================"
    echo
    
    print_warning "This will destroy ALL Azure resources created for this project!"
    print_warning "This action cannot be undone!"
    echo
    
    read -p "Are you absolutely sure you want to continue? Type 'DESTROY' to confirm: " -r
    if [ "$REPLY" != "DESTROY" ]; then
        print_status "Operation cancelled."
        exit 0
    fi
    
    echo
    print_status "Starting infrastructure destruction..."
    
    # Check Azure login
    check_azure_login
    
    # Destroy Terraform infrastructure
    destroy_terraform_infrastructure
    
    # Destroy Terraform state storage
    destroy_terraform_state_storage
    
    # Destroy any remaining ETL resources
    destroy_etl_resources
    
    # Destroy any remaining Terraform state resources
    destroy_remaining_terraform_resources
    
    # Clean up local files
    cleanup_local_files
    
    # Show final status
    show_final_status
}

# Run main function
main "$@"

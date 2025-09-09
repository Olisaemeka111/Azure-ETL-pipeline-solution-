#!/bin/bash

# Azure ETL Pipeline - Cleanup Old Resources Script
# This script helps clean up old Terraform state resources to reduce costs

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

# Function to list old Terraform state resources
list_old_resources() {
    print_status "Scanning for old Terraform state resources..."
    
    # List old resource groups
    OLD_RGS=$(az group list --query "[?contains(name, 'rg-terraform-state-') && name != 'rg-terraform-state'].name" --output tsv)
    
    if [ -n "$OLD_RGS" ]; then
        print_warning "Found old Terraform state resource groups:"
        echo "$OLD_RGS"
        echo
        
        # Show cost impact
        print_status "Cost Impact Analysis:"
        for rg in $OLD_RGS; do
            STORAGE_ACCOUNTS=$(az storage account list --resource-group $rg --query "[].name" --output tsv 2>/dev/null || echo "")
            if [ -n "$STORAGE_ACCOUNTS" ]; then
                print_warning "  Resource Group: $rg"
                print_warning "    Storage Accounts: $STORAGE_ACCOUNTS"
                print_warning "    Estimated Monthly Cost: $5-10 per storage account"
            fi
        done
        echo
    else
        print_success "No old Terraform state resources found."
        return 0
    fi
}

# Function to delete old resources
delete_old_resources() {
    print_status "Deleting old Terraform state resources..."
    
    OLD_RGS=$(az group list --query "[?contains(name, 'rg-terraform-state-') && name != 'rg-terraform-state'].name" --output tsv)
    
    if [ -n "$OLD_RGS" ]; then
        for rg in $OLD_RGS; do
            print_status "Deleting resource group: $rg"
            az group delete --name $rg --yes --no-wait
            print_success "Deletion initiated for: $rg"
        done
        
        print_success "All old resource groups deletion initiated."
        print_warning "Note: Deletion may take a few minutes to complete."
    else
        print_success "No old resources to delete."
    fi
}

# Function to show current state storage
show_current_state() {
    print_status "Current Terraform state storage:"
    
    if az group show --name "rg-terraform-state" --output none 2>/dev/null; then
        print_success "Current state resource group: rg-terraform-state"
        
        STORAGE_ACCOUNTS=$(az storage account list --resource-group "rg-terraform-state" --query "[].name" --output tsv)
        if [ -n "$STORAGE_ACCOUNTS" ]; then
            print_success "Current state storage accounts: $STORAGE_ACCOUNTS"
        fi
    else
        print_warning "No current state storage found."
    fi
}

# Function to show cost savings
show_cost_savings() {
    print_status "Cost Savings Analysis:"
    
    OLD_RGS=$(az group list --query "[?contains(name, 'rg-terraform-state-') && name != 'rg-terraform-state'].name" --output tsv)
    
    if [ -n "$OLD_RGS" ]; then
        TOTAL_OLD_RGS=$(echo "$OLD_RGS" | wc -l)
        ESTIMATED_MONTHLY_COST=$((TOTAL_OLD_RGS * 8))  # $8 per resource group with storage
        
        print_warning "Old resource groups found: $TOTAL_OLD_RGS"
        print_warning "Estimated monthly cost: $${ESTIMATED_MONTHLY_COST}"
        print_success "Potential monthly savings: $${ESTIMATED_MONTHLY_COST}"
        print_success "Annual savings: $((ESTIMATED_MONTHLY_COST * 12))"
    else
        print_success "No old resources found - no cost savings needed."
    fi
}

# Main function
main() {
    print_status "Azure ETL Pipeline - Resource Cleanup Tool"
    print_status "=========================================="
    echo
    
    case "${1:-list}" in
        "list")
            list_old_resources
            show_current_state
            show_cost_savings
            ;;
        "delete")
            list_old_resources
            echo
            print_warning "This will delete all old Terraform state resources."
            read -p "Are you sure you want to continue? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                delete_old_resources
            else
                print_status "Operation cancelled."
            fi
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  list    - List old resources and show cost impact (default)"
            echo "  delete  - Delete old resources after confirmation"
            echo "  help    - Show this help message"
            echo
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

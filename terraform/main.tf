# Production-Grade Azure ETL Pipeline Infrastructure
# This Terraform configuration creates all necessary Azure resources for a data transformation and cleansing pipeline

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
  
  backend "azurerm" {
    # Configure backend in backend-config.tfvars
    # resource_group_name  = "rg-terraform-state"
    # storage_account_name = "stterraformstate"
    # container_name       = "tfstate"
    # key                  = "etl-pipeline.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "etl_rg" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
  
  tags = var.tags
}

# Storage Account for Data Lake Gen2
resource "azurerm_storage_account" "datalake" {
  name                     = "${var.project_name}${var.environment}datalake"
  resource_group_name      = azurerm_resource_group.etl_rg.name
  location                 = azurerm_resource_group.etl_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  
  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  # Lifecycle management
  lifecycle {
    prevent_destroy = true
  }
  
  tags = var.tags
}

# Data Lake containers for different zones
resource "azurerm_storage_container" "raw_zone" {
  name                  = "raw-zone"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "staging_zone" {
  name                  = "staging-zone"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "curated_zone" {
  name                  = "curated-zone"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

# Key Vault for secrets management
resource "azurerm_key_vault" "etl_kv" {
  name                = "${var.project_name}-${var.environment}-kv"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  purge_protection_enabled = true
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    key_permissions = [
      "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore"
    ]
    
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
    
    storage_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
  }
  
  tags = var.tags
}

# Azure Data Factory
resource "azurerm_data_factory" "etl_adf" {
  name                = "${var.project_name}-${var.environment}-adf"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Azure Databricks Workspace
resource "azurerm_databricks_workspace" "etl_databricks" {
  name                = "${var.project_name}-${var.environment}-databricks"
  resource_group_name = azurerm_resource_group.etl_rg.name
  location            = azurerm_resource_group.etl_rg.location
  sku                 = "premium"
  
  managed_resource_group_name = "${var.project_name}-${var.environment}-databricks-mrg"
  
  tags = var.tags
}

# Azure SQL Database
resource "azurerm_mssql_server" "etl_sql" {
  name                         = "${var.project_name}-${var.environment}-sql"
  resource_group_name          = azurerm_resource_group.etl_rg.name
  location                     = azurerm_resource_group.etl_rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  
  minimum_tls_version = "1.2"
  
  tags = var.tags
}

resource "azurerm_mssql_database" "etl_db" {
  name           = "${var.project_name}-${var.environment}-db"
  server_id      = azurerm_mssql_server.etl_sql.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 100
  sku_name       = "S1"
  
  # Enable transparent data encryption
  transparent_data_encryption_enabled = true
  
  tags = var.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "etl_logs" {
  name                = "${var.project_name}-${var.environment}-logs"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "etl_insights" {
  name                = "${var.project_name}-${var.environment}-insights"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name
  workspace_id        = azurerm_log_analytics_workspace.etl_logs.id
  application_type    = "web"
  
  tags = var.tags
}

# Storage Account for Data Factory artifacts
resource "azurerm_storage_account" "adf_artifacts" {
  name                     = "${var.project_name}${var.environment}adfart"
  resource_group_name      = azurerm_resource_group.etl_rg.name
  location                 = azurerm_resource_group.etl_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  tags = var.tags
}

resource "azurerm_storage_container" "adf_artifacts" {
  name                  = "adf-artifacts"
  storage_account_name  = azurerm_storage_account.adf_artifacts.name
  container_access_type = "private"
}

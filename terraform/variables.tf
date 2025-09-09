# Variables for Azure ETL Pipeline Infrastructure

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "etlpipeline"
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.project_name))
    error_message = "Project name must be 3-20 characters long and contain only lowercase letters and numbers."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
  
  validation {
    condition     = can(regex("^[A-Za-z0-9 ]+$", var.location))
    error_message = "Location must be a valid Azure region name."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "ETL Pipeline"
    Environment = "Development"
    Owner       = "Data Team"
    CostCenter  = "IT"
    CreatedBy   = "Terraform"
  }
}

variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  default     = "sqladmin"
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.sql_admin_password) >= 8
    error_message = "SQL admin password must be at least 8 characters long."
  }
}

variable "databricks_cluster_node_type" {
  description = "Node type for Databricks clusters"
  type        = string
  default     = "Standard_DS3_v2"
}

variable "databricks_cluster_min_workers" {
  description = "Minimum number of workers for Databricks clusters"
  type        = number
  default     = 1
}

variable "databricks_cluster_max_workers" {
  description = "Maximum number of workers for Databricks clusters"
  type        = number
  default     = 4
}

variable "data_retention_days" {
  description = "Number of days to retain data in Log Analytics"
  type        = number
  default     = 30
  
  validation {
    condition     = var.data_retention_days >= 30 && var.data_retention_days <= 730
    error_message = "Data retention must be between 30 and 730 days."
  }
}

variable "enable_monitoring" {
  description = "Enable comprehensive monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for enhanced security"
  type        = bool
  default     = false
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses allowed to access SQL Server"
  type        = list(string)
  default     = ["0.0.0.0-255.255.255.255"]
}

variable "backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

# Outputs for Azure ETL Pipeline Infrastructure

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.etl_rg.name
}

output "resource_group_location" {
  description = "Location of the created resource group"
  value       = azurerm_resource_group.etl_rg.location
}

output "storage_account_name" {
  description = "Name of the Data Lake Storage account"
  value       = azurerm_storage_account.datalake.name
}

output "storage_account_primary_dfs_endpoint" {
  description = "Primary DFS endpoint of the Data Lake Storage account"
  value       = azurerm_storage_account.datalake.primary_dfs_endpoint
}

output "data_factory_name" {
  description = "Name of the Azure Data Factory"
  value       = azurerm_data_factory.etl_adf.name
}

output "data_factory_identity_principal_id" {
  description = "Principal ID of the Data Factory managed identity"
  value       = azurerm_data_factory.etl_adf.identity[0].principal_id
}

output "databricks_workspace_name" {
  description = "Name of the Databricks workspace"
  value       = azurerm_databricks_workspace.etl_databricks.name
}

output "databricks_workspace_url" {
  description = "URL of the Databricks workspace"
  value       = azurerm_databricks_workspace.etl_databricks.workspace_url
}

output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = azurerm_mssql_server.etl_sql.name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.etl_db.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.etl_kv.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.etl_kv.vault_uri
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.etl_logs.id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.etl_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.etl_insights.connection_string
  sensitive   = true
}

# Container names for reference
output "raw_zone_container" {
  description = "Name of the raw zone container"
  value       = azurerm_storage_container.raw_zone.name
}

output "staging_zone_container" {
  description = "Name of the staging zone container"
  value       = azurerm_storage_container.staging_zone.name
}

output "curated_zone_container" {
  description = "Name of the curated zone container"
  value       = azurerm_storage_container.curated_zone.name
}

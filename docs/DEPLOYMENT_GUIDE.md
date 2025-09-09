# Azure ETL Pipeline Deployment Guide

This guide provides step-by-step instructions for deploying the production-grade Azure ETL pipeline for data transformation and cleansing.

## Prerequisites

Before starting the deployment, ensure you have the following:

### Required Tools
- **Azure CLI** (version 2.0 or later)
- **Terraform** (version 1.0 or later)
- **Python** (version 3.8 or later)
- **jq** (for JSON processing)
- **Git** (for version control)

### Azure Requirements
- Active Azure subscription with appropriate permissions
- Contributor or Owner role on the target subscription
- Ability to create resource groups and resources

### Account Setup
1. **Azure CLI Login**:
   ```bash
   az login
   az account set --subscription "Your-Subscription-ID"
   ```

2. **Verify Permissions**:
   ```bash
   az account show
   az role assignment list --assignee $(az account show --query user.name -o tsv)
   ```

## Deployment Steps

### Step 1: Infrastructure Deployment

1. **Navigate to the project directory**:
   ```bash
   cd "Azure ETL Pipeline project"
   ```

2. **Configure Terraform variables**:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Deploy infrastructure**:
   ```bash
   ./scripts/deploy-infrastructure.sh
   ```

   This script will:
   - Validate prerequisites
   - Initialize Terraform
   - Plan the deployment
   - Apply the infrastructure
   - Configure Key Vault secrets
   - Create sample data

### Step 2: Data Factory Pipeline Deployment

1. **Deploy Data Factory components**:
   ```bash
   ./scripts/deploy-adf-pipelines.sh
   ```

   This script will:
   - Deploy linked services
   - Deploy datasets
   - Deploy pipelines
   - Create and start triggers

### Step 3: Databricks Notebooks Deployment

1. **Deploy Databricks notebooks**:
   ```bash
   ./scripts/deploy-databricks-notebooks.sh
   ```

   This script will:
   - Configure Databricks CLI
   - Create workspace directories
   - Deploy notebooks
   - Create and configure clusters
   - Install required libraries
   - Create jobs

### Step 4: Monitoring Setup

1. **Configure monitoring**:
   ```bash
   ./scripts/setup-monitoring.sh
   ```

   This script will:
   - Deploy monitoring dashboards
   - Configure alert rules
   - Set up log analytics queries

## Configuration Details

### Terraform Variables

Key variables to configure in `terraform.tfvars`:

```hcl
# Project Configuration
project_name = "etlpipeline"
environment  = "dev"
location     = "East US"

# SQL Server Configuration
sql_admin_username = "sqladmin"
sql_admin_password = "YourSecurePassword123!"

# Databricks Configuration
databricks_cluster_node_type   = "Standard_DS3_v2"
databricks_cluster_min_workers = 1
databricks_cluster_max_workers = 4

# Monitoring Configuration
data_retention_days = 30
enable_monitoring   = true
```

### Key Vault Secrets

The following secrets are automatically configured:

- `datalake-storage-key`: Storage account access key
- `sql-connection-string`: SQL Database connection string
- `databricks-access-token`: Databricks workspace access token

### Data Factory Parameters

Pipeline parameters that can be customized:

- `storageAccount`: Data Lake Storage account name
- `rawContainer`: Raw data container name
- `stagingContainer`: Staging data container name
- `curatedContainer`: Curated data container name
- `processingDate`: Date for data processing
- `qualityThreshold`: Data quality threshold (0.0-1.0)
- `notificationWebhook`: Webhook URL for notifications

## Verification

### Infrastructure Verification

1. **Check resource group**:
   ```bash
   az group show --name etlpipeline-dev-rg
   ```

2. **List all resources**:
   ```bash
   az resource list --resource-group etlpipeline-dev-rg --output table
   ```

### Data Factory Verification

1. **List pipelines**:
   ```bash
   az datafactory pipeline list --resource-group etlpipeline-dev-rg --factory-name etlpipeline-dev-adf
   ```

2. **Check trigger status**:
   ```bash
   az datafactory trigger list --resource-group etlpipeline-dev-rg --factory-name etlpipeline-dev-adf
   ```

### Databricks Verification

1. **List notebooks**:
   ```bash
   databricks workspace list /ETL/notebooks
   ```

2. **Check cluster status**:
   ```bash
   databricks clusters list
   ```

## Testing the Pipeline

### Manual Pipeline Execution

1. **Trigger pipeline manually**:
   ```bash
   az datafactory pipeline create-run \
     --resource-group etlpipeline-dev-rg \
     --factory-name etlpipeline-dev-adf \
     --name MainETLPipeline \
     --parameters processingDate=2024-01-15
   ```

2. **Monitor execution**:
   ```bash
   az datafactory pipeline-run show \
     --resource-group etlpipeline-dev-rg \
     --factory-name etlpipeline-dev-adf \
     --run-id <run-id>
   ```

### Sample Data Testing

The deployment script creates sample data in the raw zone. You can:

1. **Check sample data**:
   ```bash
   az storage blob list \
     --account-name etlpipelinedevdatalake \
     --container-name raw-zone \
     --output table
   ```

2. **Run transformation**:
   ```bash
   databricks jobs run-now --job-id <job-id>
   ```

## Monitoring and Alerting

### Azure Monitor Dashboard

Access the monitoring dashboard at:
- Azure Portal → Monitor → Dashboards → ETL Pipeline Dashboard

### Key Metrics to Monitor

1. **Pipeline Execution**:
   - Success rate
   - Execution duration
   - Failure count

2. **Data Quality**:
   - Quality scores
   - Validation results
   - Data completeness

3. **Resource Utilization**:
   - Storage usage
   - Compute utilization
   - Cost trends

### Alert Rules

Configured alerts for:
- Pipeline failures
- Data quality threshold breaches
- Storage capacity warnings
- Databricks job failures

## Troubleshooting

### Common Issues

1. **Terraform State Lock**:
   ```bash
   terraform force-unlock <lock-id>
   ```

2. **Permission Errors**:
   ```bash
   az role assignment create \
     --assignee <user-email> \
     --role "Contributor" \
     --scope /subscriptions/<subscription-id>
   ```

3. **Key Vault Access**:
   ```bash
   az keyvault set-policy \
     --name <key-vault-name> \
     --upn <user-email> \
     --secret-permissions get list set
   ```

### Log Locations

- **Terraform logs**: Check console output during deployment
- **Data Factory logs**: Azure Portal → Data Factory → Monitor
- **Databricks logs**: Databricks workspace → Clusters → Driver Logs
- **Application Insights**: Azure Portal → Application Insights → Logs

### Support Resources

- **Azure Documentation**: [docs.microsoft.com/azure](https://docs.microsoft.com/azure)
- **Terraform Azure Provider**: [registry.terraform.io/providers/hashicorp/azurerm](https://registry.terraform.io/providers/hashicorp/azurerm)
- **Databricks Documentation**: [docs.databricks.com](https://docs.databricks.com)

## Security Considerations

### Network Security
- Private endpoints (optional)
- Network security groups
- Firewall rules

### Data Security
- Encryption at rest and in transit
- Managed identities
- Key Vault integration
- PII masking

### Access Control
- Role-based access control (RBAC)
- Principle of least privilege
- Regular access reviews

## Cost Optimization

### Resource Sizing
- Right-size Databricks clusters
- Use auto-scaling
- Optimize storage tiers

### Scheduling
- Schedule pipelines during off-peak hours
- Use appropriate compute resources
- Implement data lifecycle policies

### Monitoring
- Track costs with Azure Cost Management
- Set up budget alerts
- Regular cost reviews

## Maintenance

### Regular Tasks
- Monitor pipeline performance
- Review data quality metrics
- Update dependencies
- Security patches

### Backup and Recovery
- Regular Terraform state backups
- Data Lake Storage redundancy
- SQL Database backups
- Disaster recovery planning

## Next Steps

After successful deployment:

1. **Customize the pipeline** for your specific data sources
2. **Implement additional data quality checks**
3. **Set up CI/CD pipelines** for automated deployments
4. **Configure additional monitoring** and alerting
5. **Plan for scaling** as data volumes grow

For questions or issues, refer to the troubleshooting section or contact your Azure support team.

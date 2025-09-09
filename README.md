# 🚀 Production-Grade Azure ETL Pipeline for Data Transformation & Cleansing

## Overview
This project provides a complete production-ready ETL pipeline solution in Azure for data transformation and cleansing. It includes Infrastructure as Code (Terraform), Azure Data Factory pipelines, Databricks notebooks, and comprehensive monitoring.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Raw Data      │    │   Staging Zone   │    │  Curated Zone   │
│   (ADLS Gen2)   │───▶│   (ADLS Gen2)    │───▶│   (ADLS Gen2)   │
│                 │    │                  │    │                 │
│ • CSV files     │    │ • Validated      │    │ • Parquet       │
│ • JSON files    │    │ • Profiled       │    │ • Partitioned   │
│ • Parquet files │    │ • Cleaned        │    │ • Optimized     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Azure Data     │    │   Azure          │    │  Azure SQL      │
│  Factory        │    │  Databricks      │    │  Database       │
│                 │    │                  │    │                 │
│ • Orchestration │    │ • Transformations│    │ • Final Tables  │
│ • Scheduling    │    │ • Data Quality   │    │ • Reporting     │
│ • Monitoring    │    │ • PII Masking    │    │ • Analytics     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Components

### 1. Infrastructure (Terraform)
- **Location**: `terraform/`
- Azure Data Lake Storage Gen2 (Raw, Staging, Curated zones)
- Azure Data Factory with managed identity
- Azure Databricks workspace
- Azure SQL Database
- Azure Key Vault for secrets
- Azure Monitor and Log Analytics

### 2. Data Factory Pipelines
- **Location**: `adf-pipelines/`
- Main orchestration pipeline
- Data quality validation pipeline
- Error handling and retry logic
- Parameterized configurations

### 3. Databricks Notebooks
- **Location**: `databricks-notebooks/`
- Data transformation logic
- Data quality checks using Great Expectations
- PII masking and data cleansing
- Schema validation and profiling

### 4. Monitoring & Alerting
- **Location**: `monitoring/`
- Azure Monitor dashboards
- Log Analytics queries
- Alert rules for pipeline failures

## Quick Start

### Prerequisites
- Azure CLI installed and configured (`az login`)
- Terraform >= 1.0
- Python 3.8+ (for local development)
- Azure subscription with appropriate permissions

### Deployment Steps

1. **Clone and Setup**:
   ```bash
   git clone https://github.com/Olisaemeka111/Azure-ETL-pipeline-solution-.git
   cd Azure-ETL-pipeline-solution-
   ```

2. **Deploy Infrastructure** (Automated):
   ```bash
   chmod +x scripts/deploy-infrastructure.sh
   ./scripts/deploy-infrastructure.sh
   ```
   This script will:
   - Create Terraform state storage
   - Deploy all Azure resources
   - Configure Key Vault secrets
   - Generate outputs.json for subsequent deployments

3. **Deploy Data Factory Pipelines**:
   ```bash
   chmod +x scripts/deploy-adf-pipelines.sh
   ./scripts/deploy-adf-pipelines.sh
   ```

4. **Deploy Databricks Notebooks**:
   ```bash
   chmod +x scripts/deploy-databricks-notebooks.sh
   ./scripts/deploy-databricks-notebooks.sh
   ```

### Manual Deployment (Alternative)
If you prefer manual deployment:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## Security Features
- ✅ Managed Identities for authentication
- ✅ Azure Key Vault for secrets management
- ✅ Role-based access control (RBAC)
- ✅ Network security groups
- ✅ Data encryption at rest and in transit

## Data Quality Features
- ✅ Schema validation and profiling
- ✅ Duplicate detection and removal
- ✅ Null value handling
- ✅ Data type validation and casting
- ✅ PII detection and masking
- ✅ Business rule validation

## Monitoring Features
- ✅ Pipeline execution monitoring
- ✅ Data quality metrics
- ✅ Performance monitoring
- ✅ Cost tracking
- ✅ Automated alerting

## Deployment Status

### Current Status: 🔄 **In Progress**
- ✅ **Infrastructure Scripts**: Enhanced with automated state storage creation
- ✅ **Terraform Configuration**: Fixed region consistency and naming issues
- ✅ **Git Security**: Comprehensive .gitignore added, sensitive files protected
- ✅ **GitHub Repository**: All changes committed and pushed
- 🔄 **Infrastructure Deployment**: Resources being migrated to Central US region
- ⏳ **Data Factory Pipelines**: Ready for deployment (JSON formatting fixed)
- ⏳ **Databricks Notebooks**: Ready for deployment
- ⏳ **End-to-End Testing**: Pending infrastructure completion

### Resource Groups Created:
- `rg-terraform-state-*` (Central US) - Terraform state storage
- `etlpipeline-dev-databricks-mrg` (East US) - Databricks managed resources

### Next Steps:
1. Complete infrastructure deployment in Central US
2. Deploy Azure Data Factory pipelines
3. Deploy Databricks notebooks and configure clusters
4. Test end-to-end ETL pipeline execution

## Cost Optimization
- Auto-scaling Databricks clusters
- Data Lake Storage lifecycle policies
- SQL Database elastic pools
- Scheduled pipeline execution

## Troubleshooting

### Common Issues

1. **Region Provisioning Issues**:
   - If SQL Server fails in East US, the deployment automatically uses Central US
   - All resources are configured for consistent region deployment

2. **Terraform State Issues**:
   - The deployment script automatically creates state storage
   - State files are stored securely in Azure Storage

3. **Data Factory JSON Errors**:
   - Fixed in latest version with separate JSON files for each linked service
   - Ensure outputs.json exists before running ADF deployment

4. **Permission Issues**:
   - Ensure you're logged in with `az login`
   - Verify your account has Contributor access to the subscription

### File Structure
```
├── terraform/                 # Infrastructure as Code
├── adf-pipelines/            # Data Factory configurations
├── databricks-notebooks/     # Transformation notebooks
├── monitoring/               # Monitoring configurations
├── scripts/                  # Deployment automation
├── docs/                     # Documentation
└── .gitignore               # Git ignore rules
```

## Support
- 📖 **Documentation**: See `docs/` directory for detailed guides
- 🐛 **Issues**: Create an issue in the GitHub repository
- 🔧 **Deployment Help**: Check the deployment scripts for detailed logging
- 📧 **Contact**: Repository maintainer for urgent issues

## Repository
🔗 **GitHub**: https://github.com/Olisaemeka111/Azure-ETL-pipeline-solution-

---
*Last Updated: September 2024*

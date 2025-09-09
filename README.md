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

1. **Deploy Infrastructure**:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

2. **Deploy Data Factory Pipelines**:
   ```bash
   cd ../scripts
   ./deploy-adf-pipelines.sh
   ```

3. **Deploy Databricks Notebooks**:
   ```bash
   ./deploy-databricks-notebooks.sh
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

## Prerequisites
- Azure CLI installed and configured
- Terraform >= 1.0
- Python 3.8+ (for local development)
- Azure subscription with appropriate permissions

## Cost Optimization
- Auto-scaling Databricks clusters
- Data Lake Storage lifecycle policies
- SQL Database elastic pools
- Scheduled pipeline execution

## Support
For questions or issues, please refer to the documentation in the `docs/` directory or create an issue in the repository.
# Azure-ETL-pipeline-solution-

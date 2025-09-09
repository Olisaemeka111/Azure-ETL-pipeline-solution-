# Azure ETL Pipeline - Process Flow Diagram

## 🔄 ETL Pipeline Architecture Overview

```mermaid
graph TB
    %% Data Sources
    A[External Data Sources] --> B[Raw Zone Storage]
    A1[CSV Files] --> B
    A2[API Endpoints] --> B
    A3[Database Feeds] --> B
    
    %% Storage Zones
    B[Raw Zone<br/>etlpipelinedevdatalake/raw-zone] --> C[Staging Zone<br/>etlpipelinedevdatalake/staging-zone]
    C --> D[Curated Zone<br/>etlpipelinedevdatalake/curated-zone]
    
    %% Processing Components
    E[Azure Data Factory<br/>etlpipeline-dev-adf] --> B
    E --> C
    E --> D
    
    F[Azure Databricks<br/>etlpipeline-dev-databricks] --> C
    F --> D
    
    %% Data Warehouse
    D --> G[Azure SQL Database<br/>etlpipeline-dev-db]
    
    %% Security & Configuration
    H[Azure Key Vault<br/>etlpipelinedevkvc504b5f8] --> E
    H --> F
    H --> G
    
    %% Artifacts Storage
    I[ADF Artifacts Storage<br/>etlpipelinedevadfart/adf-artifacts] --> E
    
    %% Monitoring
    J[Log Analytics<br/>etlpipeline-dev-logs] --> E
    J --> F
    J --> G
    
    K[Application Insights<br/>etlpipeline-dev-insights] --> E
    K --> F
    
    %% Styling
    classDef storage fill:#e1f5fe
    classDef compute fill:#f3e5f5
    classDef security fill:#fff3e0
    classDef monitoring fill:#e8f5e8
    
    class B,C,D,I storage
    class E,F,G compute
    class H security
    class J,K monitoring
```

## 📊 Detailed Process Flow

### **Phase 1: Data Ingestion**
```mermaid
sequenceDiagram
    participant DS as Data Sources
    participant ADF as Azure Data Factory
    participant Raw as Raw Zone Storage
    participant KV as Key Vault
    
    DS->>ADF: Data Available
    ADF->>KV: Get Storage Credentials
    KV-->>ADF: Storage Access Key
    ADF->>Raw: Store Raw Data
    Raw-->>ADF: Confirmation
    ADF->>ADF: Log Ingestion Status
```

### **Phase 2: Data Processing**
```mermaid
sequenceDiagram
    participant ADF as Azure Data Factory
    participant DB as Azure Databricks
    participant Raw as Raw Zone
    participant Staging as Staging Zone
    participant Curated as Curated Zone
    participant KV as Key Vault
    
    ADF->>DB: Trigger Processing Job
    DB->>KV: Get Storage Credentials
    KV-->>DB: Access Keys
    DB->>Raw: Read Raw Data
    Raw-->>DB: Data Stream
    DB->>Staging: Store Intermediate Results
    DB->>Curated: Store Processed Data
    DB-->>ADF: Processing Complete
```

### **Phase 3: Data Loading**
```mermaid
sequenceDiagram
    participant ADF as Azure Data Factory
    participant Curated as Curated Zone
    participant SQL as SQL Database
    participant KV as Key Vault
    
    ADF->>KV: Get SQL Credentials
    KV-->>ADF: Connection String
    ADF->>Curated: Read Processed Data
    Curated-->>ADF: Data Stream
    ADF->>SQL: Load to Data Warehouse
    SQL-->>ADF: Load Complete
    ADF->>ADF: Log Load Status
```

## 🏗️ Infrastructure Components

### **Data Flow Architecture**
```mermaid
graph LR
    subgraph "Data Sources"
        A1[CSV Files]
        A2[APIs]
        A3[Databases]
    end
    
    subgraph "Azure Data Factory"
        B1[Copy Activity]
        B2[Data Flow]
        B3[Stored Procedure]
    end
    
    subgraph "Azure Databricks"
        C1[Notebook 1: Data Cleaning]
        C2[Notebook 2: Transformation]
        C3[Notebook 3: Validation]
    end
    
    subgraph "Storage Zones"
        D1[Raw Zone]
        D2[Staging Zone]
        D3[Curated Zone]
    end
    
    subgraph "Data Warehouse"
        E1[SQL Database]
        E2[Tables & Views]
    end
    
    A1 --> B1
    A2 --> B1
    A3 --> B1
    B1 --> D1
    B2 --> C1
    C1 --> D2
    C2 --> D2
    C3 --> D3
    B3 --> E1
    D3 --> E1
```

## 🔐 Security & Access Flow

### **Authentication & Authorization**
```mermaid
graph TB
    subgraph "Identity & Access Management"
        A[Azure AD]
        B[Managed Identity]
        C[Service Principal]
    end
    
    subgraph "Secrets Management"
        D[Key Vault]
        E[Storage Keys]
        F[SQL Credentials]
        G[API Keys]
    end
    
    subgraph "Resource Access"
        H[Data Factory]
        I[Databricks]
        J[SQL Database]
        K[Storage Accounts]
    end
    
    A --> B
    A --> C
    B --> H
    B --> I
    C --> J
    C --> K
    D --> E
    D --> F
    D --> G
    E --> K
    F --> J
    G --> H
```

## 📈 Monitoring & Observability

### **Monitoring Stack**
```mermaid
graph TB
    subgraph "Data Pipeline"
        A[Data Factory]
        B[Databricks]
        C[SQL Database]
        D[Storage Accounts]
    end
    
    subgraph "Monitoring Layer"
        E[Log Analytics]
        F[Application Insights]
        G[Azure Monitor]
    end
    
    subgraph "Alerting & Dashboards"
        H[Alert Rules]
        I[Custom Dashboards]
        J[Email Notifications]
    end
    
    A --> E
    A --> F
    B --> E
    B --> F
    C --> E
    D --> E
    E --> G
    F --> G
    G --> H
    G --> I
    H --> J
```

## 🔄 Pipeline Execution Flow

### **End-to-End ETL Process**
```mermaid
stateDiagram-v2
    [*] --> DataIngestion: Trigger Event
    DataIngestion --> DataValidation: Data Available
    DataValidation --> DataCleaning: Validation Passed
    DataValidation --> ErrorHandling: Validation Failed
    DataCleaning --> DataTransformation: Cleaning Complete
    DataTransformation --> DataQuality: Transformation Complete
    DataQuality --> DataLoading: Quality Checks Passed
    DataQuality --> ErrorHandling: Quality Issues
    DataLoading --> DataWarehouse: Load Complete
    DataWarehouse --> Monitoring: Process Complete
    ErrorHandling --> DataIngestion: Retry
    ErrorHandling --> [*]: Manual Intervention
    Monitoring --> [*]: Success
```

## 📋 Pipeline Components

### **1. Data Ingestion Pipeline**
- **Trigger**: Scheduled (daily/hourly)
- **Source**: Multiple data sources
- **Destination**: Raw Zone Storage
- **Technology**: Azure Data Factory Copy Activity

### **2. Data Processing Pipeline**
- **Trigger**: Data Factory pipeline completion
- **Source**: Raw Zone Storage
- **Processing**: Databricks notebooks
- **Destination**: Staging → Curated Zone
- **Technology**: Azure Databricks + PySpark

### **3. Data Loading Pipeline**
- **Trigger**: Processing completion
- **Source**: Curated Zone Storage
- **Destination**: SQL Database
- **Technology**: Azure Data Factory + SQL Stored Procedures

### **4. Data Quality Pipeline**
- **Trigger**: After each transformation step
- **Purpose**: Data validation and quality checks
- **Technology**: Databricks + custom validation logic

## 🎯 Key Process Features

### **Data Lineage**
- **Raw Data**: Original format, unprocessed
- **Staging Data**: Cleaned and standardized
- **Curated Data**: Business-ready, validated
- **Warehouse Data**: Aggregated and optimized for analytics

### **Error Handling**
- **Retry Logic**: Automatic retry for transient failures
- **Dead Letter Queue**: Failed records for manual review
- **Alerting**: Real-time notifications for critical failures
- **Logging**: Comprehensive audit trail

### **Scalability**
- **Auto-scaling**: Databricks clusters scale based on workload
- **Parallel Processing**: Multiple data sources processed simultaneously
- **Partitioning**: Data partitioned by date and source for efficiency

---

## 📊 Performance Metrics

### **Expected Performance**
- **Data Ingestion**: 1-10 GB/hour depending on source
- **Processing Time**: 15-30 minutes for typical datasets
- **Data Loading**: 5-10 minutes for warehouse updates
- **End-to-End**: 30-60 minutes total pipeline execution

### **Monitoring KPIs**
- **Pipeline Success Rate**: >99%
- **Data Quality Score**: >95%
- **Processing Time**: <60 minutes
- **Error Rate**: <1%

---

*This process diagram represents the complete ETL pipeline architecture deployed in the Azure ETL Pipeline project, showing data flow, processing steps, and monitoring components.*

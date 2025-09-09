# Databricks notebook source
# MAGIC %md
# MAGIC # Data Transformation and Cleansing Notebook
# MAGIC 
# MAGIC This notebook performs comprehensive data transformation and cleansing operations including:
# MAGIC - Schema validation and profiling
# MAGIC - Data type conversions and standardization
# MAGIC - Duplicate detection and removal
# MAGIC - PII masking and data privacy
# MAGIC - Business rule validation
# MAGIC - Data quality scoring

# COMMAND ----------

# MAGIC %md
# MAGIC ## Configuration and Imports

# COMMAND ----------

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.window import Window
import hashlib
import re
from datetime import datetime, date
import json

# Get parameters from ADF
storage_account = dbutils.widgets.get("storage_account")
raw_container = dbutils.widgets.get("raw_container")
staging_container = dbutils.widgets.get("staging_container")
curated_container = dbutils.widgets.get("curated_container")
processing_date = dbutils.widgets.get("processing_date")

# Configuration
raw_path = f"abfss://{raw_container}@{storage_account}.dfs.core.windows.net/input"
staging_path = f"abfss://{staging_container}@{storage_account}.dfs.core.windows.net/validated"
curated_path = f"abfss://{curated_container}@{storage_account}.dfs.core.windows.net/processed"

print(f"Processing date: {processing_date}")
print(f"Raw data path: {raw_path}")
print(f"Staging path: {staging_path}")
print(f"Curated path: {curated_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Loading and Initial Validation

# COMMAND ----------

# Load raw data
try:
    raw_df = spark.read.parquet(f"{raw_path}/*")
    print(f"Loaded {raw_df.count()} records from raw data")
    
    # Display schema
    print("Raw data schema:")
    raw_df.printSchema()
    
    # Show sample data
    print("Sample raw data:")
    raw_df.show(5, truncate=False)
    
except Exception as e:
    print(f"Error loading raw data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Profiling and Quality Assessment

# COMMAND ----------

def calculate_data_quality_metrics(df):
    """Calculate comprehensive data quality metrics"""
    
    total_records = df.count()
    
    # Calculate null percentages for each column
    null_metrics = {}
    for col_name in df.columns:
        null_count = df.filter(col(col_name).isNull()).count()
        null_percentage = (null_count / total_records) * 100 if total_records > 0 else 0
        null_metrics[col_name] = {
            'null_count': null_count,
            'null_percentage': null_percentage
        }
    
    # Calculate duplicate count
    duplicate_count = df.count() - df.dropDuplicates().count()
    duplicate_percentage = (duplicate_count / total_records) * 100 if total_records > 0 else 0
    
    # Calculate overall quality score
    avg_null_percentage = sum([metrics['null_percentage'] for metrics in null_metrics.values()]) / len(null_metrics)
    quality_score = max(0, 100 - avg_null_percentage - duplicate_percentage)
    
    return {
        'total_records': total_records,
        'duplicate_count': duplicate_count,
        'duplicate_percentage': duplicate_percentage,
        'null_metrics': null_metrics,
        'quality_score': quality_score
    }

# Calculate initial quality metrics
initial_quality = calculate_data_quality_metrics(raw_df)
print("Initial Data Quality Metrics:")
print(json.dumps(initial_quality, indent=2))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Cleansing Functions

# COMMAND ----------

def clean_email(email):
    """Clean and validate email addresses"""
    if email is None:
        return None
    
    # Convert to lowercase and strip whitespace
    email = str(email).lower().strip()
    
    # Basic email validation regex
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    
    if re.match(email_pattern, email):
        return email
    else:
        return None

def clean_phone(phone):
    """Clean and standardize phone numbers"""
    if phone is None:
        return None
    
    # Remove all non-digit characters
    digits_only = re.sub(r'\D', '', str(phone))
    
    # Handle different phone number formats
    if len(digits_only) == 10:
        return f"({digits_only[:3]}) {digits_only[3:6]}-{digits_only[6:]}"
    elif len(digits_only) == 11 and digits_only[0] == '1':
        return f"({digits_only[1:4]}) {digits_only[4:7]}-{digits_only[7:]}"
    else:
        return None

def normalize_address(address):
    """Normalize address format"""
    if address is None:
        return None
    
    # Convert to uppercase and standardize common abbreviations
    address = str(address).upper().strip()
    
    # Standardize common abbreviations
    replacements = {
        ' STREET': ' ST',
        ' AVENUE': ' AVE',
        ' ROAD': ' RD',
        ' BOULEVARD': ' BLVD',
        ' DRIVE': ' DR',
        ' LANE': ' LN',
        ' COURT': ' CT',
        ' PLACE': ' PL',
        ' APARTMENT': ' APT',
        ' SUITE': ' STE',
        ' UNIT': ' UNIT'
    }
    
    for old, new in replacements.items():
        address = address.replace(old, new)
    
    return address

def mask_pii_email(email):
    """Mask email addresses for privacy"""
    if email is None:
        return None
    
    # Create hash of email for consistent masking
    email_hash = hashlib.sha256(email.encode()).hexdigest()[:8]
    return f"user_{email_hash}@masked.com"

def mask_pii_phone(phone):
    """Mask phone numbers for privacy"""
    if phone is None:
        return None
    
    # Keep first 3 and last 4 digits, mask the middle
    if len(str(phone)) >= 7:
        phone_str = str(phone)
        return f"{phone_str[:3]}***{phone_str[-4:]}"
    else:
        return "***-***-****"

# Register UDFs
clean_email_udf = udf(clean_email, StringType())
clean_phone_udf = udf(clean_phone, StringType())
normalize_address_udf = udf(normalize_address, StringType())
mask_email_udf = udf(mask_pii_email, StringType())
mask_phone_udf = udf(mask_pii_phone, StringType())

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Transformation Pipeline

# COMMAND ----------

# Start transformation pipeline
print("Starting data transformation pipeline...")

# Step 1: Remove duplicates
print("Step 1: Removing duplicates...")
deduplicated_df = raw_df.dropDuplicates()
print(f"Records after deduplication: {deduplicated_df.count()}")

# Step 2: Data type conversions and cleaning
print("Step 2: Data type conversions and cleaning...")
transformed_df = deduplicated_df.withColumn(
    "customer_name", 
    trim(upper(col("customer_name")))
).withColumn(
    "email_cleaned", 
    clean_email_udf(col("email"))
).withColumn(
    "phone_cleaned", 
    clean_phone_udf(col("phone"))
).withColumn(
    "address_normalized", 
    normalize_address_udf(col("address"))
).withColumn(
    "order_date_parsed", 
    to_date(col("order_date"), "yyyy-MM-dd")
).withColumn(
    "order_amount_decimal", 
    col("order_amount").cast(DecimalType(10, 2))
).withColumn(
    "product_category_standardized", 
    trim(upper(col("product_category")))
)

# Step 3: PII Masking
print("Step 3: Applying PII masking...")
pii_masked_df = transformed_df.withColumn(
    "email_hash", 
    mask_email_udf(col("email_cleaned"))
).withColumn(
    "phone_masked", 
    mask_phone_udf(col("phone_cleaned"))
).withColumn(
    "pii_masked", 
    lit(True)
)

# Step 4: Business rule validation
print("Step 4: Applying business rules...")
business_validated_df = pii_masked_df.filter(
    col("order_amount_decimal") > 0
).filter(
    col("order_date_parsed").isNotNull()
).filter(
    col("customer_name").isNotNull()
).filter(
    length(col("customer_name")) >= 2
)

# Step 5: Generate customer IDs
print("Step 5: Generating customer IDs...")
customer_id_df = business_validated_df.withColumn(
    "customer_id", 
    concat(
        lit("CUST_"),
        lpad(
            row_number().over(Window.orderBy("customer_name", "email_hash")), 
            6, 
            "0"
        )
    )
)

# Step 6: Calculate final data quality score
print("Step 6: Calculating final data quality score...")
final_quality = calculate_data_quality_metrics(customer_id_df)
final_quality_score = final_quality['quality_score']

quality_scored_df = customer_id_df.withColumn(
    "data_quality_score", 
    lit(final_quality_score)
).withColumn(
    "processing_timestamp", 
    current_timestamp()
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Final Data Preparation

# COMMAND ----------

# Select and rename columns for final output
final_df = quality_scored_df.select(
    col("id"),
    col("customer_id"),
    col("customer_name"),
    col("email_hash"),
    col("phone_masked"),
    col("address_normalized"),
    col("order_date_parsed").alias("order_date"),
    col("order_amount_decimal").alias("order_amount_usd"),
    col("product_category_standardized").alias("product_category_standardized"),
    col("processing_timestamp"),
    col("data_quality_score"),
    col("pii_masked")
)

print("Final transformed data schema:")
final_df.printSchema()

print("Sample of final transformed data:")
final_df.show(5, truncate=False)

# Calculate final metrics
final_count = final_df.count()
print(f"Final record count: {final_count}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality Validation

# COMMAND ----------

# Validate data quality thresholds
quality_threshold = 0.85  # 85% quality threshold
quality_passed = final_quality_score >= (quality_threshold * 100)

print(f"Data Quality Score: {final_quality_score:.2f}%")
print(f"Quality Threshold: {quality_threshold * 100}%")
print(f"Quality Check Passed: {quality_passed}")

if not quality_passed:
    raise Exception(f"Data quality score {final_quality_score:.2f}% is below threshold {quality_threshold * 100}%")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Save Transformed Data

# COMMAND ----------

# Save to curated zone with partitioning
print("Saving transformed data to curated zone...")

try:
    final_df.write \
        .mode("overwrite") \
        .partitionBy("order_date") \
        .parquet(f"{curated_path}/date={processing_date}")
    
    print(f"Successfully saved {final_count} records to curated zone")
    
    # Verify the saved data
    saved_df = spark.read.parquet(f"{curated_path}/date={processing_date}")
    saved_count = saved_df.count()
    print(f"Verification: {saved_count} records saved successfully")
    
except Exception as e:
    print(f"Error saving data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary Report

# COMMAND ----------

# Generate summary report
summary_report = {
    "processing_date": processing_date,
    "initial_records": initial_quality['total_records'],
    "final_records": final_count,
    "records_removed": initial_quality['total_records'] - final_count,
    "initial_quality_score": initial_quality['quality_score'],
    "final_quality_score": final_quality_score,
    "quality_improvement": final_quality_score - initial_quality['quality_score'],
    "duplicates_removed": initial_quality['duplicate_count'],
    "pii_masked": True,
    "processing_timestamp": datetime.now().isoformat()
}

print("=== TRANSFORMATION SUMMARY REPORT ===")
for key, value in summary_report.items():
    print(f"{key}: {value}")

# Save summary report
summary_json = json.dumps(summary_report, indent=2)
dbutils.fs.put(f"{curated_path}/reports/transformation_summary_{processing_date}.json", summary_json)

print("Transformation pipeline completed successfully!")

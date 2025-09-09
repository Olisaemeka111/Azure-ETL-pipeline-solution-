# Databricks notebook source
# MAGIC %md
# MAGIC # Data Quality Checks and Validation
# MAGIC 
# MAGIC This notebook implements comprehensive data quality checks using Great Expectations framework:
# MAGIC - Schema validation
# MAGIC - Data completeness checks
# MAGIC - Data accuracy validation
# MAGIC - Data consistency checks
# MAGIC - Business rule validation
# MAGIC - Statistical profiling

# COMMAND ----------

# MAGIC %md
# MAGIC ## Configuration and Imports

# COMMAND ----------

# Install Great Expectations if not already installed
%pip install great-expectations

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import great_expectations as ge
from great_expectations.core import ExpectationSuite
from great_expectations.core.expectation_configuration import ExpectationConfiguration
import json
from datetime import datetime
import pandas as pd

# Get parameters from ADF
storage_account = dbutils.widgets.get("storage_account")
curated_container = dbutils.widgets.get("curated_container")
quality_threshold = float(dbutils.widgets.get("quality_threshold"))

# Configuration
curated_path = f"abfss://{curated_container}@{storage_account}.dfs.core.windows.net/processed"

print(f"Quality threshold: {quality_threshold}")
print(f"Curated data path: {curated_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Load Data for Quality Checks

# COMMAND ----------

# Load the curated data
try:
    df = spark.read.parquet(f"{curated_path}/*")
    print(f"Loaded {df.count()} records for quality validation")
    
    # Convert to Pandas for Great Expectations (sample for large datasets)
    if df.count() > 10000:
        print("Large dataset detected, sampling 10,000 records for quality checks")
        df_sample = df.sample(0.1).limit(10000).toPandas()
    else:
        df_sample = df.toPandas()
    
    print(f"Using {len(df_sample)} records for quality validation")
    
except Exception as e:
    print(f"Error loading data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Define Data Quality Expectations

# COMMAND ----------

def create_quality_expectations():
    """Create comprehensive data quality expectations"""
    
    # Create expectation suite
    suite = ExpectationSuite(expectation_suite_name="etl_data_quality_suite")
    
    # Schema expectations
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_table_columns_to_match_ordered_list",
        kwargs={
            "column_list": [
                "id", "customer_id", "customer_name", "email_hash", 
                "phone_masked", "address_normalized", "order_date", 
                "order_amount_usd", "product_category_standardized", 
                "processing_timestamp", "data_quality_score", "pii_masked"
            ]
        }
    ))
    
    # Data completeness expectations
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_not_be_null",
        kwargs={"column": "id"}
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_not_be_null",
        kwargs={"column": "customer_id"}
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_not_be_null",
        kwargs={"column": "customer_name"}
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_not_be_null",
        kwargs={"column": "order_date"}
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_not_be_null",
        kwargs={"column": "order_amount_usd"}
    ))
    
    # Data type expectations
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_be_of_type",
        kwargs={"column": "order_amount_usd", "type_": "float64"}
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_be_of_type",
        kwargs={"column": "data_quality_score", "type_": "float64"}
    ))
    
    # Range expectations
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_be_between",
        kwargs={
            "column": "order_amount_usd",
            "min_value": 0.01,
            "max_value": 1000000
        }
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_be_between",
        kwargs={
            "column": "data_quality_score",
            "min_value": 0,
            "max_value": 100
        }
    ))
    
    # Format expectations
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_match_regex",
        kwargs={
            "column": "customer_id",
            "regex": r"^CUST_\d{6}$"
        }
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_match_regex",
        kwargs={
            "column": "email_hash",
            "regex": r"^user_[a-f0-9]{8}@masked\.com$"
        }
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_match_regex",
        kwargs={
            "column": "phone_masked",
            "regex": r"^\d{3}\*\*\*\d{4}$|^\*\*\*-\*\*\*-\*\*\*\*$"
        }
    ))
    
    # Uniqueness expectations
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_be_unique",
        kwargs={"column": "id"}
    ))
    
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_be_unique",
        kwargs={"column": "customer_id"}
    ))
    
    # Value set expectations
    suite.add_expectation(ExpectationConfiguration(
        expectation_type="expect_column_values_to_be_in_set",
        kwargs={
            "column": "pii_masked",
            "value_set": [True]
        }
    ))
    
    return suite

# Create expectations suite
expectations_suite = create_quality_expectations()
print(f"Created {len(expectations_suite.expectations)} quality expectations")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Execute Data Quality Validation

# COMMAND ----------

def run_quality_validation(df, expectations_suite):
    """Run comprehensive data quality validation"""
    
    # Create Great Expectations context
    ge_df = ge.from_pandas(df)
    
    # Run all expectations
    validation_result = ge_df.validate(expectations_suite)
    
    return validation_result

# Run quality validation
print("Running data quality validation...")
validation_result = run_quality_validation(df_sample, expectations_suite)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Analyze Validation Results

# COMMAND ----------

def analyze_validation_results(validation_result):
    """Analyze and summarize validation results"""
    
    results = validation_result.results
    total_expectations = len(results)
    successful_expectations = sum(1 for result in results if result.success)
    failed_expectations = total_expectations - successful_expectations
    
    success_rate = (successful_expectations / total_expectations) * 100 if total_expectations > 0 else 0
    
    # Detailed results
    detailed_results = []
    for result in results:
        detailed_results.append({
            "expectation_type": result.expectation_config.expectation_type,
            "column": result.expectation_config.kwargs.get("column", "N/A"),
            "success": result.success,
            "observed_value": result.result.get("observed_value", "N/A"),
            "expected_value": result.expectation_config.kwargs,
            "exception_info": result.exception_info.get("exception_message", "N/A") if not result.success else None
        })
    
    return {
        "total_expectations": total_expectations,
        "successful_expectations": successful_expectations,
        "failed_expectations": failed_expectations,
        "success_rate": success_rate,
        "detailed_results": detailed_results
    }

# Analyze results
analysis = analyze_validation_results(validation_result)

print("=== DATA QUALITY VALIDATION RESULTS ===")
print(f"Total Expectations: {analysis['total_expectations']}")
print(f"Successful: {analysis['successful_expectations']}")
print(f"Failed: {analysis['failed_expectations']}")
print(f"Success Rate: {analysis['success_rate']:.2f}%")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Detailed Quality Report

# COMMAND ----------

# Display detailed results
print("\n=== DETAILED QUALITY RESULTS ===")
for result in analysis['detailed_results']:
    status = "✅ PASS" if result['success'] else "❌ FAIL"
    print(f"{status} | {result['expectation_type']} | Column: {result['column']}")
    if not result['success']:
        print(f"    Error: {result['exception_info']}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Quality Threshold Check

# COMMAND ----------

# Check against quality threshold
quality_passed = analysis['success_rate'] >= (quality_threshold * 100)

print(f"\n=== QUALITY THRESHOLD CHECK ===")
print(f"Quality Threshold: {quality_threshold * 100}%")
print(f"Actual Success Rate: {analysis['success_rate']:.2f}%")
print(f"Quality Check: {'✅ PASSED' if quality_passed else '❌ FAILED'}")

if not quality_passed:
    print("\n❌ QUALITY CHECK FAILED - Data does not meet quality standards!")
    failed_expectations = [r for r in analysis['detailed_results'] if not r['success']]
    print(f"Failed expectations: {len(failed_expectations)}")
    
    # Raise exception to fail the pipeline
    raise Exception(f"Data quality check failed. Success rate: {analysis['success_rate']:.2f}% is below threshold: {quality_threshold * 100}%")
else:
    print("\n✅ QUALITY CHECK PASSED - Data meets quality standards!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Generate Quality Report

# COMMAND ----------

# Generate comprehensive quality report
quality_report = {
    "validation_timestamp": datetime.now().isoformat(),
    "dataset_info": {
        "total_records": len(df_sample),
        "total_columns": len(df_sample.columns)
    },
    "quality_metrics": {
        "total_expectations": analysis['total_expectations'],
        "successful_expectations": analysis['successful_expectations'],
        "failed_expectations": analysis['failed_expectations'],
        "success_rate": analysis['success_rate']
    },
    "threshold_check": {
        "threshold": quality_threshold * 100,
        "passed": quality_passed
    },
    "detailed_results": analysis['detailed_results']
}

# Save quality report
report_json = json.dumps(quality_report, indent=2, default=str)
dbutils.fs.put(f"{curated_path}/reports/quality_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", report_json)

print("Quality report saved successfully!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Additional Statistical Profiling

# COMMAND ----------

def generate_statistical_profile(df):
    """Generate statistical profile of the dataset"""
    
    profile = {}
    
    # Numeric columns analysis
    numeric_columns = df.select_dtypes(include=['number']).columns
    for col in numeric_columns:
        profile[col] = {
            "mean": float(df[col].mean()),
            "median": float(df[col].median()),
            "std": float(df[col].std()),
            "min": float(df[col].min()),
            "max": float(df[col].max()),
            "null_count": int(df[col].isnull().sum()),
            "null_percentage": float((df[col].isnull().sum() / len(df)) * 100)
        }
    
    # Categorical columns analysis
    categorical_columns = df.select_dtypes(include=['object']).columns
    for col in categorical_columns:
        profile[col] = {
            "unique_count": int(df[col].nunique()),
            "most_common": str(df[col].mode().iloc[0]) if not df[col].mode().empty else None,
            "most_common_count": int(df[col].value_counts().iloc[0]) if not df[col].empty else 0,
            "null_count": int(df[col].isnull().sum()),
            "null_percentage": float((df[col].isnull().sum() / len(df)) * 100)
        }
    
    return profile

# Generate statistical profile
print("Generating statistical profile...")
statistical_profile = generate_statistical_profile(df_sample)

# Save statistical profile
profile_json = json.dumps(statistical_profile, indent=2, default=str)
dbutils.fs.put(f"{curated_path}/reports/statistical_profile_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", profile_json)

print("Statistical profile saved successfully!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary

# COMMAND ----------

print("=== DATA QUALITY VALIDATION COMPLETED ===")
print(f"✅ Total expectations validated: {analysis['total_expectations']}")
print(f"✅ Success rate: {analysis['success_rate']:.2f}%")
print(f"✅ Quality threshold: {'PASSED' if quality_passed else 'FAILED'}")
print(f"✅ Reports generated and saved")
print(f"✅ Statistical profiling completed")

if quality_passed:
    print("\n🎉 Data quality validation completed successfully!")
    print("Data is ready for downstream consumption.")
else:
    print("\n⚠️ Data quality validation failed!")
    print("Please review the failed expectations and data quality issues.")

# Deployment Guide

## Overview

This guide covers deploying the dogs-as-a-service-pipeline to Google Cloud Platform with automated CI/CD via GitHub Actions. The deployment includes both ETL pipeline (Cloud Functions) and dbt analytics (BigQuery).

## 🚀 Quick Deployment (Recommended)

### GitHub Actions CI/CD Pipeline

The project includes automated CI/CD workflows:

- **PR Testing**: `.github/workflows/pr-tests.yml` - Runs dbt compile/run/test on PRs
- **Production Deploy**: `.github/workflows/deploy-prod.yml` - Deploys to production on merge to main

#### Setup GitHub Actions:

1. **Repository Secrets** (Settings → Secrets → Actions):
   ```
   GCP_SA_KEY: [Contents of your service account JSON file]
   ```

2. **Environment Variables** (Optional):
   ```
   DBT_PROJECT_ID: your-gcp-project-id
   DBT_DATASET_DEV: dog_explorer_dev 
   DBT_DATASET_PROD: dog_explorer
   ```

3. **GitHub Environments**:
   - Create `testing` environment for PR workflows
   - Create `production` environment for main branch deployments

#### Workflow Triggers:
- **Pull Requests** → Automated testing against dev dataset
- **Merge to Main** → Automated production deployment

---

## 📋 Manual Deployment (Alternative)

For manual deployment or local development setup:

## Prerequisites

### Required Tools
- **Google Cloud SDK** (`gcloud` CLI)
- **Python 3.11+** (specified in pyproject.toml)
- **UV package manager** (recommended) or pip

### Google Cloud Setup
- Google Cloud Project with billing enabled
- Required APIs enabled:
  - Cloud Functions API
  - BigQuery API
  - Cloud Storage API
  - Cloud Scheduler API (for automation)

### Service Account Permissions
Create a service account with these IAM roles:
- **BigQuery Data Editor** - For writing to BigQuery tables
- **Storage Admin** - For Cloud Storage operations
- **Cloud Functions Invoker** - For function execution

## Local Development Setup

### 1. Environment Preparation

```bash
# Navigate to project directory
cd dogs-as-a-service-pipeline

# Install UV (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync

# Verify Python version (should be 3.11+)
python --version
```

### 2. Local Testing

```bash
# Test pipeline locally
python main.py

# Or test specific components
python -c "from src.dog_api_pipeline import fetch_dog_breeds; print(len(list(fetch_dog_breeds())))"
```

### 3. Streamlit Dashboard

Create `.streamlit/secrets.toml` with:

```toml
[gcp_service_account]
# Paste full service account JSON here

# Optional: enable OpenAI-powered assistant in Finder tab
OPENAI_API_KEY = "sk-..."
```

Run the app:

```bash
streamlit run /Users/hendrik/Documents/Repositories2/dogs-as-a-service-pipeline/streamlit_app.py
```

Update dataset in `streamlit_app.py` if needed:

```python
PROJECT_DATASET = "dog-breed-explorer-470208.dog_explorer_dev"
```

### 3. Configure Google Cloud Credentials

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Create and download service account key (for local dev)
gcloud iam service-accounts create dogs-pipeline-service
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

# Download key for local development
gcloud iam service-accounts keys create credentials.json \
    --iam-account=dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com

export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"
```

## Cloud Function Deployment

### 1. Basic Deployment

```bash
# Deploy Cloud Function
gcloud functions deploy dog-pipeline-handler \
    --runtime python311 \
    --source . \
    --entry-point dog_pipeline_handler \
    --trigger-http \
    --allow-unauthenticated \
    --timeout 540s \
    --memory 512MB \
    --update-env-vars BUCKET_URL=gs://dog-breed-raw-data,DESTINATION__BIGQUERY__LOCATION=europe-north2
```

### 2. Advanced Deployment Configuration

Create `deployment/cloud-function.yaml`:

```yaml
name: dog-pipeline-handler
runtime: python311
entryPoint: dog_pipeline_handler
httpsTrigger: {}
timeout: 540s
availableMemoryMb: 512
serviceAccountEmail: dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com
environmentVariables:
  GOOGLE_CLOUD_PROJECT: YOUR_PROJECT_ID
  DESTINATION__BIGQUERY__LOCATION: europe-north2
  BUCKET_URL: gs://dog-breed-raw-data
labels:
  service: dogs-pipeline
  environment: production
```

Deploy using configuration:
```bash
gcloud functions deploy dog-pipeline-handler --source . --env-vars-file deployment/cloud-function.yaml
```

### 3. Verify Deployment

```bash
# Test the deployed function
FUNCTION_URL=$(gcloud functions describe dog-pipeline-handler --format="value(httpsTrigger.url)")
curl -X POST $FUNCTION_URL

# Check function logs
gcloud functions logs read dog-pipeline-handler --limit 50
```

## Cloud Storage Setup

### 1. Create Storage Bucket

```bash
# Create bucket for raw data storage
gsutil mb -p YOUR_PROJECT_ID gs://YOUR_PROJECT_ID-dogs-pipeline-raw-data

# Set lifecycle policy (optional - for data retention management)
cat > lifecycle.json << EOF
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 365}
    }
  ]
}
EOF

gsutil lifecycle set lifecycle.json gs://YOUR_PROJECT_ID-dogs-pipeline-raw-data
```

### 2. Configure DLT for Storage

Create `.dlt/secrets.toml` (local development):
```toml
[destination.filesystem]
bucket_url = "gs://YOUR_PROJECT_ID-dogs-pipeline-raw-data"

[destination.bigquery] 
project_id = "YOUR_PROJECT_ID"
location = "US"
```

## BigQuery Setup

### 1. Create Dataset

```bash
# Create bronze dataset for raw data
bq mk --dataset \
    --description "Bronze layer - raw dog breed data" \
    YOUR_PROJECT_ID:bronze
```

### 2. Set Access Controls

```bash
# Grant service account access to dataset
bq add-iam-policy-binding \
    --member=serviceAccount:dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/bigquery.dataEditor \
    YOUR_PROJECT_ID:bronze
```

## Automated Scheduling

### 1. Cloud Scheduler Setup

```bash
# Create daily schedule for pipeline execution
gcloud scheduler jobs create http dogs-pipeline-daily \
    --schedule="0 6 * * *" \
    --uri=$FUNCTION_URL \
    --http-method=POST \
    --time-zone="UTC" \
    --description="Daily dog breeds data pipeline execution"
```

### 2. Schedule Options

**Daily at 6 AM UTC:**
```bash
--schedule="0 6 * * *"
```

**Every 12 hours:**
```bash
--schedule="0 */12 * * *"
```

**Weekly on Sundays:**
```bash
--schedule="0 6 * * 0"
```

### 3. Manual Trigger

```bash
# Trigger scheduled job manually
gcloud scheduler jobs run dogs-pipeline-daily
```

## Monitoring and Alerting

### 1. Cloud Function Monitoring

```bash
# View function metrics
gcloud functions describe dog-pipeline-handler --format="table(
    name,
    status,
    updateTime,
    httpsTrigger.url
)"

# Monitor executions
gcloud functions logs read dog-pipeline-handler --limit 100
```

### 2. BigQuery Monitoring

```sql
-- Check latest data loads
SELECT 
  extraction_date,
  COUNT(*) as record_count,
  MAX(extracted_at) as latest_extraction
FROM `YOUR_PROJECT_ID.bronze.dog_breeds` 
GROUP BY extraction_date
ORDER BY extraction_date DESC;
```

### 3. Error Alerting

Create alerting policy for function failures:

```bash
# Create notification channel (email)
gcloud alpha monitoring channels create \
    --display-name="Pipeline Alerts" \
    --type=email \
    --channel-labels=email_address=YOUR_EMAIL@example.com

# Create alerting policy for function errors
gcloud alpha monitoring policies create \
    --policy-from-file=deployment/alerting-policy.yaml
```

## Environment Management

### 1. Development Environment

```yaml
# deployment/environments/dev.yaml
environment: development
function_name: dog-pipeline-handler-dev
memory: 256MB
timeout: 300s
schedule: "0 */6 * * *"  # Every 6 hours for testing
```

### 2. Production Environment

```yaml
# deployment/environments/prod.yaml
environment: production
function_name: dog-pipeline-handler
memory: 512MB
timeout: 540s
schedule: "0 6 * * *"    # Daily at 6 AM
```

### 3. Deployment Script

Create `deploy.sh`:

```bash
#!/bin/bash
ENVIRONMENT=${1:-dev}
CONFIG_FILE="deployment/environments/${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Environment configuration not found: $CONFIG_FILE"
    exit 1
fi

# Load configuration
FUNCTION_NAME=$(yq eval '.function_name' $CONFIG_FILE)
MEMORY=$(yq eval '.memory' $CONFIG_FILE)
TIMEOUT=$(yq eval '.timeout' $CONFIG_FILE)

# Deploy function
gcloud functions deploy $FUNCTION_NAME \
    --runtime python311 \
    --source . \
    --entry-point dog_pipeline_handler \
    --trigger-http \
    --allow-unauthenticated \
    --timeout $TIMEOUT \
    --memory $MEMORY \
    --service-account dogs-pipeline-service@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com

echo "Deployed $FUNCTION_NAME to $ENVIRONMENT environment"
```

Usage:
```bash
chmod +x deploy.sh
./deploy.sh dev   # Deploy to development
./deploy.sh prod  # Deploy to production
```

## Security Best Practices

### 1. Service Account Security

```bash
# Use principle of least privilege
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"

# Avoid using default service accounts
# Never commit service account keys to version control
```

### 2. Network Security

```bash
# Deploy function with VPC connector (optional)
gcloud functions deploy dog-pipeline-handler \
    --vpc-connector YOUR_VPC_CONNECTOR \
    --egress-settings vpc-connector

# Use private Google access for enhanced security
```

### 3. Secrets Management

```bash
# Store sensitive configuration in Secret Manager
gcloud secrets create api-key --data-file=api-key.txt

# Access secrets in function
gcloud functions deploy dog-pipeline-handler \
    --set-secrets API_KEY=api-key:latest
```

## Troubleshooting

### Common Issues

#### 1. Authentication Errors
```bash
# Check service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

#### 2. Function Timeout
```bash
# Increase timeout (max 540s for HTTP functions)
gcloud functions deploy dog-pipeline-handler \
    --timeout 540s
```

#### 3. Memory Issues
```bash
# Increase memory allocation
gcloud functions deploy dog-pipeline-handler \
    --memory 1024MB
```

#### 4. BigQuery Quota Exceeded
```bash
# Check BigQuery quotas
bq ls --project_id=YOUR_PROJECT_ID --max_results=1000
```

### Log Analysis

```bash
# Function execution logs
gcloud functions logs read dog-pipeline-handler \
    --format="table(timestamp,severity,textPayload)"

# Filter error logs only
gcloud functions logs read dog-pipeline-handler \
    --severity=ERROR \
    --limit=50
```

### Performance Optimization

#### 1. Cold Start Reduction
```bash
# Set minimum instances to reduce cold starts
gcloud functions deploy dog-pipeline-handler \
    --min-instances 1
```

#### 2. Memory Optimization
- Start with 256MB and increase if needed
- Monitor memory usage in Cloud Console
- Consider function splitting for large operations

#### 3. Network Optimization
- Use VPC connector for consistent networking
- Implement connection pooling for database connections
- Cache frequently accessed data when appropriate

## Rollback Procedures

### 1. Function Rollback
```bash
# List function versions
gcloud functions versions list --function dog-pipeline-handler

# Rollback to previous version
gcloud functions deploy dog-pipeline-handler \
    --source gs://YOUR_BUCKET/previous-version.zip
```

### 2. Data Rollback
```bash
# Restore BigQuery table from backup
bq cp YOUR_PROJECT_ID:bronze.dog_breeds@TIMESTAMP \
    YOUR_PROJECT_ID:bronze.dog_breeds_backup
```

---

## dbt Analytics Layer Deployment

### Overview

The dbt analytics layer transforms bronze data into business-ready models. This section covers setting up and deploying the dbt project for both development and production environments.

### Prerequisites for dbt

#### Required Tools
- **dbt-core** (≥1.5.0)
- **dbt-bigquery** adapter 
- **Google Cloud SDK** (for BigQuery authentication)

#### Installation
```bash
# Install dbt with BigQuery adapter
pip install dbt-core dbt-bigquery

# Or using UV (recommended)
uv add dbt-core dbt-bigquery

# Verify installation
dbt --version
```

### dbt Project Setup

#### 1. Configure dbt Profile

Create `~/.dbt/profiles.yml`:

```yaml
dog_breed_explorer:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: YOUR_PROJECT_ID
      dataset: dog_explorer_dev
      threads: 4
      timeout_seconds: 300
      location: US
      priority: interactive
      keyfile: /path/to/service-account.json
      
    prod:
      type: bigquery
      method: service-account
      project: YOUR_PROJECT_ID
      dataset: dog_explorer
      threads: 8
      timeout_seconds: 300
      location: US
      priority: interactive
      keyfile: /path/to/service-account.json
```

#### 2. Alternative: Application Default Credentials (ADC)

For production environments, use ADC instead of service account keys:

```yaml
dog_breed_explorer:
  target: prod
  outputs:
    prod:
      type: bigquery
      method: oauth
      project: YOUR_PROJECT_ID
      dataset: dog_explorer
      threads: 8
      timeout_seconds: 300
      location: US
      priority: interactive
```

#### 3. Install dbt Dependencies

```bash
# Install dbt packages
dbt deps

# This installs:
# - dbt_utils (utility macros)
# - dbt_expectations (advanced testing)
```

### BigQuery Dataset Configuration

#### 1. Create Analytics Datasets (current approach)

```bash
## Single dataset per environment for models
bq mk --dataset \
    --description "Development analytics dataset (models)" \
    YOUR_PROJECT_ID:dog_explorer_dev

bq mk --dataset \
    --description "Production analytics dataset (models)" \
    YOUR_PROJECT_ID:dog_explorer

## Separate datasets for tests
bq mk --dataset \
    --description "Development dbt tests dataset" \
    YOUR_PROJECT_ID:dog_explorer_dev_tests

bq mk --dataset \
    --description "Production dbt tests dataset" \
    YOUR_PROJECT_ID:dog_explorer_tests
```

#### 2. Grant Service Account Permissions

```bash
# Grant permissions to analytics datasets
for dataset in "dog_explorer_dev" "dog_explorer" "dog_explorer_dev_tests" "dog_explorer_tests"; do
    bq add-iam-policy-binding \
        --member=serviceAccount:dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com \
        --role=roles/bigquery.dataEditor \
        YOUR_PROJECT_ID:$dataset
done
```

### Development Workflow

#### 1. Local Development

```bash
DBT_PROFILES_DIR=/path/to/.dbt

# Test connection (dev)
uv run dbt debug --target dev

# Build dev (models + tests)
uv run dbt build --target dev

# Build prod (models + tests)
uv run dbt build --target prod

# Generate and serve documentation
dbt docs generate
dbt docs serve --port 8081
```

#### 2. Model Development Cycle

```bash
# Develop specific model
dbt run --select stg_dog_breeds

# Test specific model
dbt test --select stg_dog_breeds

# Run model with downstream dependencies
dbt run --select stg_dog_breeds+

# Run marts layer
dbt run --select marts.core
```

#### 3. Incremental Development

```bash
# Full refresh (recreate all tables)
dbt run --full-refresh

# Run only changed models
dbt run --select state:modified

# Validate schema changes
dbt run --vars "validate_schema: true"
```

### Production Deployment

#### 1. Production Environment Setup

Create production deployment script `deploy_dbt_prod.sh`:

```bash
#!/bin/bash
set -e

echo "Starting dbt production deployment..."

# Set production target
export DBT_PROFILES_DIR=~/.dbt
export DBT_TARGET=prod

echo "Validating BigQuery connection..."
uv run dbt debug --target prod

# Install dependencies
echo "Installing dbt packages..."
dbt deps

# Run full pipeline with testing
echo "Running dbt models & tests..."
uv run dbt build --target prod

echo "Running dbt tests..."
dbt test --target prod

# Generate documentation
echo "Generating documentation..."
uv run dbt docs generate --target prod

# Upload docs to Cloud Storage (optional)
echo "Uploading documentation..."
gsutil -m cp -r target/ gs://YOUR_PROJECT_ID-dbt-docs/

echo "dbt production deployment completed successfully!"
```

#### 2. Automated Production Deployment

Create Cloud Function for dbt deployment:

**`dbt_deploy_function/main.py`:**
```python
import subprocess
import os
from google.cloud import storage

def deploy_dbt_models(request):
    """Cloud Function to deploy dbt models"""
    try:
        # Set environment variables
        os.environ['DBT_PROFILES_DIR'] = '/tmp/.dbt'
        os.environ['DBT_TARGET'] = 'prod'
        
        # Run dbt commands
        subprocess.run(['dbt', 'deps'], check=True, cwd='/workspace')
        subprocess.run(['dbt', 'run', '--target', 'prod'], check=True, cwd='/workspace')
        subprocess.run(['dbt', 'test', '--target', 'prod'], check=True, cwd='/workspace')
        
        # Generate documentation
        subprocess.run(['dbt', 'docs', 'generate', '--target', 'prod'], check=True, cwd='/workspace')
        
        return {"status": "success", "message": "dbt deployment completed"}
    
    except subprocess.CalledProcessError as e:
        return {"status": "error", "message": f"dbt deployment failed: {str(e)}"}, 500
```

Deploy the dbt function:
```bash
gcloud functions deploy dbt-deploy-handler \
    --runtime python311 \
    --source dbt_deploy_function/ \
    --entry-point deploy_dbt_models \
    --trigger-http \
    --timeout 540s \
    --memory 2048MB \
    --service-account dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

#### 3. CI/CD Integration (✅ Already Implemented)

The project includes GitHub Actions workflows:

**PR Testing Workflow** (`.github/workflows/pr-tests.yml`):
- Triggers on PRs to main/dev branches
- Runs dbt deps, compile, run --target dev, test
- Uses service account authentication via GitHub secrets
- Tests against development dataset

**Production Deployment Workflow** (`.github/workflows/deploy-prod.yml`):
- Triggers on merge to main branch
- Runs dbt run --target prod and dbt test --target prod
- Deploys to production dataset
- Uses separate production environment for secrets

**Key Features:**
- ✅ Automated testing on every PR
- ✅ Production deployment on main branch merge
- ✅ Environment-specific configurations (dev/prod)
- ✅ Service account authentication
- ✅ Error handling and comprehensive logging

### Monitoring and Observability

#### 1. dbt Model Monitoring

Create BigQuery views for monitoring:

```sql
-- Model freshness monitoring
CREATE OR REPLACE VIEW `YOUR_PROJECT_ID.monitoring.dbt_model_freshness` AS
SELECT 
    'dim_breeds' as model_name,
    MAX(extracted_at) as last_update,
    CURRENT_TIMESTAMP() as check_timestamp,
    DATETIME_DIFF(CURRENT_DATETIME(), DATETIME(MAX(extracted_at)), HOUR) as hours_since_update
FROM `YOUR_PROJECT_ID.dog_explorer_marts_core.dim_breeds`

UNION ALL

SELECT 
    'fct_breed_metrics' as model_name,
    MAX(extracted_at) as last_update,
    CURRENT_TIMESTAMP() as check_timestamp,
    DATETIME_DIFF(CURRENT_DATETIME(), DATETIME(MAX(extracted_at)), HOUR) as hours_since_update  
FROM `YOUR_PROJECT_ID.dog_explorer_marts_core.fct_breed_metrics`

UNION ALL

SELECT 
    'bronze_raw' as model_name,
    MAX(extracted_at) as last_update,
    CURRENT_TIMESTAMP() as check_timestamp,
    DATETIME_DIFF(CURRENT_DATETIME(), DATETIME(MAX(extracted_at)), HOUR) as hours_since_update
FROM `YOUR_PROJECT_ID.bronze.dog_breeds`;
```

#### 2. Data Quality Monitoring

```sql
-- Data quality dashboard
CREATE OR REPLACE VIEW `YOUR_PROJECT_ID.monitoring.data_quality_summary` AS
SELECT 
    'Total Breeds' as metric,
    COUNT(*) as value,
    CURRENT_TIMESTAMP() as measured_at
FROM `YOUR_PROJECT_ID.dog_explorer_marts_core.dim_breeds`

UNION ALL

SELECT 
    'Breeds with Complete Data' as metric,
    COUNT(*) as value,
    CURRENT_TIMESTAMP() as measured_at
FROM `YOUR_PROJECT_ID.dog_explorer_marts_core.dim_breeds`
WHERE data_completeness_score = 4

UNION ALL

SELECT 
    'Average Data Completeness' as metric,
    ROUND(AVG(data_completeness_score), 2) as value,
    CURRENT_TIMESTAMP() as measured_at
FROM `YOUR_PROJECT_ID.dog_explorer_marts_core.dim_breeds`;
```

#### 3. Automated Testing Alerts

Create alerting for dbt test failures:

```bash
# Create Cloud Monitoring alert for dbt test failures
gcloud alpha monitoring policies create \
    --policy-from-file=monitoring/dbt-test-failures-policy.yaml
```

### Performance Optimization

#### 1. BigQuery Optimization

```sql
-- Add clustering to improve query performance
ALTER TABLE `YOUR_PROJECT_ID.dog_explorer_marts_core.dim_breeds`
CLUSTER BY breed_id;

ALTER TABLE `YOUR_PROJECT_ID.dog_explorer_marts_core.fct_breed_metrics`  
CLUSTER BY breed_id;

ALTER TABLE `YOUR_PROJECT_ID.dog_explorer_marts_core.dim_temperament`
CLUSTER BY breed_id;
```

#### 2. dbt Performance Configuration

Update `dbt_project.yml` for production optimization:

```yaml
models:
  dog_breed_explorer:
    marts:
      core:
        +materialized: table
        +cluster_by: breed_id
        +partition_by:
          field: extraction_date
          data_type: date
        +pre-hook: "{{ log('Running model: ' ~ this.identifier) }}"
        +post-hook: "ANALYZE TABLE {{ this }}"
```

#### 3. Query Optimization

```sql
-- Example optimized query for analytics
SELECT 
    d.breed_name,
    d.size_category,
    f.avg_weight_lbs,
    t.family_suitability
FROM `{{ ref('dim_breeds') }}` d
JOIN `{{ ref('fct_breed_metrics') }}` f USING (breed_id)  
JOIN `{{ ref('dim_temperament') }}` t USING (breed_id)
WHERE d.extraction_date = (SELECT MAX(extraction_date) FROM `{{ ref('dim_breeds') }}`)
  AND f.has_weight_data = true
  AND t.family_suitability = 'Excellent for Families'
```

### Troubleshooting dbt Issues

#### 1. Common dbt Errors

**Connection Issues:**
```bash
# Test BigQuery connection
dbt debug --target prod

# Verify service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
    --filter="bindings.members:dogs-pipeline-service@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

**Model Failures:**
```bash  
# Run with debug logging
dbt run --debug --select failing_model_name

# Check compiled SQL
dbt compile --select failing_model_name
cat target/compiled/dog_breed_explorer/models/marts/core/failing_model_name.sql
```

**Test Failures:**
```bash
# Run specific test with verbose output
dbt test --select test_name --store-failures

# Query test failure details
SELECT * FROM `YOUR_PROJECT_ID.dbt_test__audit.failing_test`
```

#### 2. Performance Issues

```bash
# Profile query performance
dbt run --profiles-dir . --profile-template

# Use BigQuery query insights
bq query --dry_run --use_legacy_sql=false < your_query.sql
```

#### 3. Documentation Issues

```bash
# Regenerate docs
dbt docs generate --target prod

# Serve docs locally for testing
dbt docs serve --port 8080

# Upload to Cloud Storage with proper permissions
gsutil -m cp -r target/ gs://YOUR_BUCKET/dbt-docs/
gsutil iam ch allUsers:objectViewer gs://YOUR_BUCKET/dbt-docs
```

## 🔄 Development Workflow with CI/CD

### Recommended Workflow:

1. **Feature Development**:
   ```bash
   git checkout -b feature/new-model
   # Make changes to dbt models
   dbt run --target dev  # Test locally
   git add . && git commit -m "Add new model"
   git push origin feature/new-model
   ```

2. **Create Pull Request**:
   - GitHub Actions automatically runs PR testing workflow
   - Tests run against development dataset
   - Review results in Actions tab

3. **Merge to Production**:
   ```bash
   git checkout main
   git merge feature/new-model
   git push origin main
   ```
   - GitHub Actions automatically deploys to production
   - dbt models run against production dataset

### Monitoring CI/CD:

- **GitHub Actions**: Repository → Actions tab
- **BigQuery**: Monitor dataset updates in Cloud Console  
- **Logs**: Check workflow logs for debugging

This comprehensive deployment guide covers both the ETL pipeline and dbt analytics layer with modern CI/CD practices, providing automated end-to-end deployment capabilities for the complete data platform.
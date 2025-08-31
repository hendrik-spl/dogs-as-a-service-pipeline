# Setup Guide

## Overview

This guide provides comprehensive setup instructions for the Dogs-as-a-Service Pipeline, covering both local development and production deployment scenarios.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Production Deployment](#production-deployment)
4. [Authentication & Secrets Management](#authentication--secrets-management)
5. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- **Python 3.11+** (specified in pyproject.toml)
- **UV package manager** (recommended) or pip
- **Google Cloud SDK** (`gcloud` CLI)
- **Git** (for version control)

### Google Cloud Requirements

- Google Cloud Project with billing enabled
- Required APIs enabled:
  - Cloud Functions API
  - BigQuery API
  - Cloud Storage API
  - Cloud Scheduler API (for automation)

### Service Account Permissions

The following IAM roles are required for the service accounts:

- **BigQuery Data Editor** - For writing to BigQuery tables
- **Storage Admin** - For Cloud Storage operations
- **Cloud Functions Invoker** - For function execution (production only)

## Local Development Setup

### Step 1: Clone and Initialize

```bash
# Clone the repository
git clone <repository-url>
cd dogs-as-a-service-pipeline

# Run the automated setup script
./setup.sh
```

### Step 2: Install Dependencies

```bash
# Using UV (recommended)
uv sync

# Alternative: Using pip
pip install -r requirements.txt

# Install dbt dependencies
dbt deps
```

### Step 3: Google Cloud Authentication

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Create service account for local development
gcloud iam service-accounts create dogs-pipeline-local \
    --display-name="Dogs Pipeline Local Development"

# Grant necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-local@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-local@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

# Download service account key
gcloud iam service-accounts keys create dbt-sa.json \
    --iam-account=dogs-pipeline-local@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/dbt-sa.json"
```

### Step 4: BigQuery Dataset Setup

```bash
# Create development datasets
bq mk --dataset \
    --description "Development analytics dataset" \
    YOUR_PROJECT_ID:dog_explorer_dev

bq mk --dataset \
    --description "Development dbt tests dataset" \
    YOUR_PROJECT_ID:dog_explorer_dev_tests

# Create production datasets (for testing)
bq mk --dataset \
    --description "Production analytics dataset" \
    YOUR_PROJECT_ID:dog_explorer

bq mk --dataset \
    --description "Production dbt tests dataset" \
    YOUR_PROJECT_ID:dog_explorer_tests
```

### Step 5: Configure dbt

1. **Copy the profiles template:**
```bash
cp .dbt/profiles.yml.example ~/.dbt/profiles.yml
```

2. **Edit the profiles file:**
```bash
nano ~/.dbt/profiles.yml
```

3. **Update with your project details:**
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
      location: US  # or your preferred region
      priority: interactive
      keyfile: /path/to/your/dbt-sa.json
      
    prod:
      type: bigquery
      method: service-account
      project: YOUR_PROJECT_ID
      dataset: dog_explorer
      threads: 8
      timeout_seconds: 300
      location: US  # or your preferred region
      priority: interactive
      keyfile: /path/to/your/dbt-sa.json
```

### Step 6: Configure Streamlit

1. **Copy the secrets template:**
```bash
cp .streamlit/secrets.toml.example .streamlit/secrets.toml
```

2. **Edit the secrets file:**
```bash
nano .streamlit/secrets.toml
```

3. **Update with your service account details:**
```toml
# Optional: OpenAI API key for enhanced features
OPENAI_API_KEY = "your-openai-api-key-here"

[gcp_service_account]
type = "service_account"
project_id = "YOUR_PROJECT_ID"
private_key_id = "your-private-key-id"
private_key = "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n"
client_email = "your-service-account@YOUR_PROJECT_ID.iam.gserviceaccount.com"
client_id = "your-client-id"
auth_uri = "https://accounts.google.com/o/oauth2/auth"
token_uri = "https://oauth2.googleapis.com/token"
auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs"
client_x509_cert_url = "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

### Step 7: Test Local Setup

```bash
# Test ETL pipeline
python main.py

# Test dbt models
dbt run --target dev
dbt test --target dev

# Test Streamlit app
streamlit run streamlit_app.py
```

## Production Deployment

### Step 1: Production Service Account Setup

```bash
# Create production service account
gcloud iam service-accounts create dogs-pipeline-prod \
    --display-name="Dogs Pipeline Production"

# Grant production permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-prod@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-prod@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:dogs-pipeline-prod@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudfunctions.invoker"
```

### Step 2: Deploy Cloud Function

```bash
# Deploy ETL pipeline as Cloud Function
gcloud functions deploy dog-pipeline-handler \
    --runtime python311 \
    --source . \
    --entry-point dog_pipeline_handler \
    --trigger-http \
    --allow-unauthenticated \
    --memory 512MB \
    --timeout 540s \
    --update-env-vars BUCKET_URL=gs://dog-breed-raw-data,DESTINATION__BIGQUERY__LOCATION=europe-north2

# Set up Cloud Scheduler for automated execution
gcloud scheduler jobs create http dog-pipeline-scheduler \
    --schedule="0 */6 * * *" \
    --uri="$(gcloud functions describe dog-pipeline-handler --format='value(httpsTrigger.url)')" \
    --http-method=POST
```

### Step 3: Deploy dbt Models

```bash
# Switch to production target
dbt run --target prod

# Run production tests
dbt test --target prod

# Generate documentation
dbt docs generate
```

### Step 4: Deploy Streamlit App

1. **Connect repository to Streamlit Cloud**
2. **Configure secrets in Streamlit Cloud dashboard**
3. **Deploy the application**

## Authentication & Secrets Management

### Service Account Strategy

We use separate service accounts for different environments:

- **Local Development**: `dogs-pipeline-local@YOUR_PROJECT_ID.iam.gserviceaccount.com`
- **Production**: `dogs-pipeline-prod@YOUR_PROJECT_ID.iam.gserviceaccount.com`

### File-Based Authentication

#### dbt Authentication
- **File**: `dbt-sa.json` (service account key)
- **Location**: Project root (local) or Cloud Function environment (production)
- **Usage**: Referenced in `~/.dbt/profiles.yml`

#### Streamlit Authentication
- **File**: `.streamlit/secrets.toml`
- **Location**: Local development only
- **Production**: Configured via Streamlit Cloud dashboard

### Security Best Practices

1. **Never commit credentials to version control**
2. **Use separate service accounts for different environments**
3. **Grant minimal required permissions**
4. **Rotate service account keys regularly**
5. **Use IAM conditions for additional security**
6. **Monitor service account usage**

### Environment Variables

```bash
# Local development
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/dbt-sa.json"
export DBT_PROFILES_DIR="/path/to/your/.dbt"

# Production (Cloud Functions)
# Set via Cloud Console or gcloud CLI
```

## Troubleshooting

### Common Issues

#### dbt Connection Issues

**Problem**: Cannot connect to BigQuery
```bash
# Solution: Verify credentials
gcloud auth application-default login

# Check profiles.yml path
export DBT_PROFILES_DIR=/path/to/your/.dbt

# Test connection
dbt debug
```

#### Streamlit Authentication Issues

**Problem**: Cannot access BigQuery from Streamlit
```bash
# Solution: Verify service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:your-service-account@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

#### ETL Pipeline Issues

**Problem**: Cloud Function fails to execute
```bash
# Solution: Test locally first
python -c "from src.dog_api_pipeline import fetch_dog_breeds; print(len(list(fetch_dog_breeds())))"

# Check Cloud Function logs
gcloud functions logs read dog-pipeline-handler --limit 50
```

### Environment-Specific Configuration

#### Development Environment
- **Dataset**: `dog_explorer_dev`
- **Threads**: 4
- **Timeout**: 300s
- **Priority**: interactive
- **Service Account**: `dogs-pipeline-local`

#### Production Environment
- **Dataset**: `dog_explorer`
- **Threads**: 8
- **Timeout**: 300s
- **Priority**: interactive
- **Service Account**: `dogs-pipeline-prod`

### Debugging Commands

```bash
# Test dbt connection
dbt debug

# Test BigQuery access
bq ls YOUR_PROJECT_ID:dog_explorer_dev

# Test Cloud Function
curl -X POST $(gcloud functions describe dog-pipeline-handler --format='value(httpsTrigger.url)')

# Check service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:service-account@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

## Next Steps

After completing the setup:

1. **Run the complete pipeline**: `python main.py && dbt run --target dev`
2. **Explore the data**: Open the Streamlit app
3. **Review documentation**: `dbt docs generate && dbt docs serve`
4. **Set up monitoring**: Configure Cloud Monitoring for production
5. **Plan scaling**: Consider data volume and performance requirements

For additional help, refer to the main README.md or the project documentation in the `docs/` directory.

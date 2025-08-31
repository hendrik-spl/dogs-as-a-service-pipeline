# 🐕 Dogs-as-a-Service Data Platform

## Table of Contents

- [Overview](#overview)
- [Architecture](#️-architecture)
- [Quick Start](#-quick-start)
  - [CI/CD Automated Deployment (Recommended)](#cicd-automated-deployment-recommended)
  - [Manual Setup (Alternative)](#manual-setup-alternative)
  - [Prerequisites](#prerequisites)
  - [1. Local Development Setup](#1-local-development-setup)
  - [2. Production Deployment](#2-production-deployment)
  - [3. Secrets Management](#3-secrets-management)
  - [4. dbt Project Details](#4-dbt-project-details)
  - [5. Explore the Data](#5-explore-the-data)
- [Data Models & Analytics](#-data-models--analytics)
- [Quality & Testing](#-quality--testing)
- [Business Impact](#-business-impact)
- [Technology Stack](#️-technology-stack)
- [Documentation](#-documentation)
- [Development](#-development)
- [Data Sample](#-data-sample)
- [Troubleshooting](#troubleshooting)

## Overview 

A comprehensive **end-to-end data engineering platform** that demonstrates modern data architecture patterns through dog breed analytics. This project combines a robust ETL pipeline with advanced analytics capabilities, showcasing both technical depth and practical business value.

### 🎯 Project Highlights

- **Complete Data Platform**: ETL pipeline + dbt analytics warehouse
- **Production-Ready**: 20+ automated tests, comprehensive documentation
- **Advanced Analytics**: Temperament scoring, family matching algorithms
- **Modern Stack**: DLT, dbt, BigQuery, Cloud Functions
- **Business Value**: Real-world insights for pet industry applications

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   TheDogAPI     │    │   Cloud Function │    │   Bronze Layer      │    │   dbt Analytics     │
│   (External)    │───▶│   ETL Pipeline   │───▶│                     │───▶│                     │
│                 │    │                  │    │ ┌─────────────────┐ │    │ ┌─────────────────┐ │
│ • REST API      │    │ • Data Extract   │    │ │   BigQuery      │ │    │ │   Staging       │ │
│ • 172 breeds    │    │ • Transform      │    │ │   bronze        │ │    │ │ stg_dog_breeds  │ │
│ • JSON format   │    │ • Dual Load      │    │ │   schema        │ │    │ └─────────────────┘ │
└─────────────────┘    └──────────────────┘    │ └─────────────────┘ │    │ ┌─────────────────┐ │
                                                │ ┌─────────────────┐ │    │ │      Marts      │ │
                                                │ │ Cloud Storage   │ │    │ │ • dim_breeds    │ │
                                                │ │(raw/partitioned)│ │    │ │ • fct_metrics   │ │
                                                │ └─────────────────┘ │    │ │ • dim_temper    │ │
                                                └─────────────────────┘    │ └─────────────────┘ │
                                                                           └─────────────────────┘
```

## 🚀 Quick Start

### CI/CD Automated Deployment

1. **Setup GitHub Repository**:
   - Fork/clone this repository
   - Configure GitHub Secrets (see [Deployment Guide](docs/DEPLOYMENT.md))

2. **GitHub Secrets Required**:
   ```
   Repository Settings → Secrets → Actions:
   GCP_SA_KEY: [Your service account JSON content]
   ```

3. **Automated Workflow**:
   - **Pull Requests** → Automatic testing against dev dataset
   - **Merge to Main** → Automatic production deployment
   - Monitor progress in GitHub Actions tab

### Manual Setup

For detailed step-by-step instructions, see the [Complete Setup Guide](docs/SETUP_GUIDE.md).

### Prerequisites

- **Python 3.11+** (specified in pyproject.toml)
- **Google Cloud Platform account** with billing enabled
- **UV package manager** (recommended) or pip
- **Google Cloud SDK** (`gcloud` CLI)

### 1. Local Development Setup

#### 1.1 Clone and Install Dependencies

```bash
# Clone the repository
git clone https://github.com/your-username/dogs-as-a-service-pipeline.git
cd dogs-as-a-service-pipeline

# Install UV (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies using UV (recommended)
uv sync

# Alternative: Install using pip
pip install -r requirements.txt

# Verify Python version
python --version  # Should be 3.11+
```

#### 1.2 Google Cloud Authentication Setup

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

# Set environment variable for local development
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/dbt-sa.json"
```

#### 1.3 Cloud Storage Setup

```bash
# Create Cloud Storage bucket for raw data
gcloud mb gs://dog-breed-raw-data-YOUR_PROJECT_ID
```

#### 1.4 BigQuery Dataset Setup

```bash
# Create bronze dataset for raw data
bq mk --dataset \
    --description "Bronze layer - raw dog breed data" \
    --location=europe-north2 \
    YOUR_PROJECT_ID:bronze

# Create development datasets for dbt
bq mk --dataset \
    --description "Development analytics dataset" \
    --location=europe-north2 \
    YOUR_PROJECT_ID:dog_explorer_dev

bq mk --dataset \
    --description "Development dbt tests dataset" \
    --location=europe-north2 \
    YOUR_PROJECT_ID:dog_explorer_dev_tests

# Create production datasets for dbt
bq mk --dataset \
    --description "Production analytics dataset" \
    --location=europe-north2 \
    YOUR_PROJECT_ID:dog_explorer

bq mk --dataset \
    --description "Production dbt tests dataset" \
    --location=europe-north2 \
    YOUR_PROJECT_ID:dog_explorer_tests
```

#### 1.5 dbt Configuration

1. **Copy and configure profiles.yml template:**

```bash
# Copy the template
cp .dbt/profiles.yml ~/.dbt/profiles.yml

# Edit with your project details
nano ~/.dbt/profiles.yml
```

2. **Update profiles.yml with your project details:**

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

3. **Install dbt dependencies:**

```bash
dbt deps
```

#### 1.6 Streamlit Configuration

1. **Create Streamlit secrets template:**

```bash
# Copy the template
cp .streamlit/secrets.toml.example .streamlit/secrets.toml

# Edit with your service account details
nano .streamlit/secrets.toml
```

2. **Update secrets.toml with your project details:**

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

#### 1.7 Test Local Setup

```bash
# Activate UV environment (if using UV)
uv sync

# Test ETL pipeline
python main.py

# Test dbt models
dbt run --target dev
dbt test --target dev

# Test Streamlit app (optional)
streamlit run streamlit_app.py

# Verify data was loaded
bq query "SELECT COUNT(*) as breed_count FROM \`YOUR_PROJECT_ID.bronze.dog_breeds\`"
```

### 2. Production Deployment

#### 2.1 Cloud Function Deployment

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

#### 2.2 Production dbt Deployment

```bash
# Run production models
dbt run --target prod

# Run production tests
dbt test --target prod

# Generate documentation
dbt docs generate
```

#### 2.3 Streamlit Cloud Deployment

1. **Connect your repository to Streamlit Cloud**
2. **Set up secrets in Streamlit Cloud dashboard:**
   - Go to your app settings
   - Add the same secrets as in your local `.streamlit/secrets.toml`
3. **Deploy the app**

### 3. Secrets Management

#### 3.1 Service Account Files

- **dbt-sa.json**: Service account key for dbt operations
- **Streamlit secrets.toml**: Service account credentials for Streamlit app
- **Never commit these files to version control**

#### 3.2 Environment Variables

```bash
# For local development
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/dbt-sa.json"

# For production (Cloud Functions)
# Set via Cloud Console or gcloud CLI
```

#### 3.3 Security Best Practices

- Use separate service accounts for different environments
- Grant minimal required permissions
- Rotate service account keys regularly
- Use IAM conditions for additional security
- Monitor service account usage

### 4. dbt Project Details

#### 4.1 Data Models
- **`stg_dog_breeds`**: Cleaned and normalized raw data with parsed measurement ranges
- **`dim_breeds`**: Master dimension with breed characteristics and derived insights
- **`fct_breed_metrics`**: Quantitative metrics and physical measurements analysis
- **`dim_temperament`**: Behavioral analysis with temperament scoring and categorization

#### 4.2 Testing Strategy
- Schema tests (uniqueness, referential integrity, ranges, accepted values)
- Custom tests: e.g. cross-model consistency

#### 4.3 Common dbt Commands
```bash
# Run everything
dbt run && dbt test

# Run a specific model
dbt run --select stg_dog_breeds

# Run a model and its dependencies
dbt run --select dim_breeds+

# Test a specific model
dbt test --select fct_breed_metrics

# Generate and serve docs
dbt docs generate && dbt docs serve
```

### 5. Explore the Data
```sql
-- Find family-friendly small breeds
SELECT 
    breed_name,
    size_category,
    avg_life_span_years,
    family_suitability
FROM dim_breeds d
JOIN dim_temperament t USING (breed_id)
WHERE size_category = 'Small'
  AND family_suitability = 'Excellent for Families'
ORDER BY avg_life_span_years DESC;
```

## 📊 Data Models & Analytics

### Staging Layer
- **`stg_dog_breeds`**: Cleaned data with intelligent range parsing

### Analytical Models
- **`dim_breeds`**: Master breed dimension with 15+ derived insights
- **`fct_breed_metrics`**: Physical measurements with calculated ratios
- **`dim_temperament`**: Advanced behavioral analysis with 0-1 scoring

### Key Analytics Features
- **Smart Range Parsing**: "22 - 25 pounds" → min/max columns
- **Temperament Scoring**: Normalized behavioral trait analysis
- **Family Matching**: AI-driven suitability predictions
- **Data Quality**: Completeness tracking and validation

## 🧪 Quality & Testing

### Comprehensive Test Suite
- **20+ Schema Tests**: Uniqueness, referential integrity, ranges
- **3 Custom Tests**: Business logic validation
- **Data Quality Monitoring**: Completeness scores, validation flags
- **Cross-Model Consistency**: Referential integrity enforcement

### Testing Commands
```bash
# ETL Pipeline
python main.py

# dbt Analytics
dbt test
dbt test --select stg_dog_breeds
dbt test --store-failures  # Store test failures for analysis
```

## 📈 Business Impact

### Findings & Business Impact Narrative
The Overview dashboard highlights that longevity skews toward small and toy companion breeds: the top cohort includes Toy Poodle, Maltese, Pekingese, and several terriers with expected lifespans around 14–17 years. Breed counts cluster in the medium and small size categories, with extra‑large breeds comparatively rare—signaling narrower supply and higher ownership costs. Among breeds rated highly for families, dominant temperament traits are intelligent, affectionate, alert, loyal and friendly, indicating lower training friction and reduced return‑to‑shelter risk.

Business impact: adoption teams can prioritize small/medium, high‑affection/intelligence breeds for family placements to raise success rates; retailers and insurers can align assortments and pricing with the prevalent size mix and lifespan bands; training providers can productize curricula around the most common family‑friendly traits (playfulness, energy, protectiveness). The Find Your Own Dog assistant further shortens time‑to‑match by converting lifestyle descriptions into data‑grounded recommendations, consistently constrained by the active dataset filters.

### Analytical Insights Delivered
- **Family Matching**: Optimal breed recommendations for households
- **Longevity Analysis**: Breed lifespan patterns and predictions
- **Training Programs**: Difficulty assessment based on temperament
- **Veterinary Insights**: Breed-specific health correlations

### Sample Business Questions Answered
1. Which breeds live longest among family-friendly dogs?
2. How does temperament complexity vary by breed group?
3. What physical characteristics correlate with training difficulty?
4. Which breeds are best for first-time dog owners?

### Key Performance Indicators
- **Data Coverage**: 172+ breeds with 90%+ completeness
- **Analytics Depth**: 25+ calculated metrics per breed
- **Quality Score**: 20+ automated validation rules
- **Processing Time**: <60 seconds for complete refresh

## 🛠️ Technology Stack

### Data Pipeline
- **DLT (Data Load Tool)**: Modern Python ETL framework
- **Google Cloud Functions**: Serverless execution
- **BigQuery**: Cloud data warehouse
- **Cloud Storage**: Raw data lake

### Analytics Layer
- **dbt**: Data transformation and modeling
- **BigQuery**: Analytical data warehouse
- **dbt_utils**: Testing and utility macros
- **Git**: Version-controlled transformations

### Development Tools
- **UV**: Fast Python package management
- **Jupyter**: Interactive data exploration
- **Google Cloud SDK**: Cloud deployment
- **GitHub Actions**: Automated CI/CD workflows
- **Environment Separation**: Dev/prod dataset isolation

## 📚 Documentation

### Complete Documentation Suite
- **[Setup Guide](docs/SETUP_GUIDE.md)**: Complete setup and deployment instructions
- **[Project Overview](docs/PROJECT_OVERVIEW.md)**: Business context and roadmap
- **[Architecture](docs/ARCHITECTURE.md)**: Technical architecture and design
- **[API Reference](docs/API_REFERENCE.md)**: Complete data model schemas
- **[Deployment Guide](docs/DEPLOYMENT.md)**: ETL + dbt deployment instructions
- **[File Structure](docs/FILE_STRUCTURE.md)**: Project organization guide

### Additional Resources
- **[Analysis Examples](analyses/breed_insights.sql)**: Sample analytical queries
- **Auto-generated dbt docs**: `dbt docs generate && dbt docs serve`

## 🔧 Development

### Recommended CI/CD Workflow
```bash
# 1. Create feature branch
git checkout -b feature/breed-analysis

# 2. Make changes and test locally (optional)
dbt run --target dev

# 3. Create Pull Request
git push origin feature/breed-analysis
# → Triggers automated testing in GitHub Actions

# 4. Review and merge
# → Automatically deploys to production
```

### Local Development (Alternative)
```bash
# ETL Development
python -c "from src.dog_api_pipeline import fetch_dog_breeds; print(len(list(fetch_dog_breeds())))"

# dbt Development  
dbt run --select staging --target dev
dbt run --select dim_breeds+ --target dev
dbt docs serve --port 8080
```

### Manual Production Deployment (Backup)
```bash
# Deploy ETL Pipeline
gcloud functions deploy dog-pipeline-handler \
    --runtime python311 \
    --source . \
    --entry-point dog_pipeline_handler \
    --trigger-http \
    --allow-unauthenticated \
    --memory 512MB \
    --timeout 540s \
    --update-env-vars BUCKET_URL=gs://dog-breed-raw-data,DESTINATION__BIGQUERY__LOCATION=europe-north2

# Deploy dbt Models
dbt run --target prod
dbt test --target prod
```

### Monitoring CI/CD
- **GitHub Actions**: Repository → Actions tab
- **Workflow Logs**: Detailed execution logs for debugging
- **PR Status**: Automated test results on pull requests
- **Deployment Status**: Production deployment confirmations

### Performance Considerations (dbt)
- Materialization strategy: staging as views for fast iteration; marts as tables for analytics
- Consider clustering on `breed_id` for large datasets
- Partition historical datasets when applicable

## 📊 Data Sample

The pipeline processes 172 dog breeds with rich metadata:

```json
{
  "breed_name": "Golden Retriever",
  "size_category": "Large", 
  "avg_weight_lbs": 65,
  "family_friendliness_score": 0.83,
  "training_difficulty": "Easy to Train",
  "primary_temperament_category": "Social/Friendly"
}
```

## Troubleshooting

### Common Issues

#### Authentication Problems
```bash
# Check if authenticated
gcloud auth list

# Re-authenticate if needed
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Verify service account key
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/dbt-sa.json"
```

#### ETL Pipeline Errors
```bash
# Check Cloud Function logs
gcloud functions logs read dog-pipeline-handler --limit 50

# Test pipeline locally
python main.py

# Debug API connection
python -c "import requests; print(requests.get('https://api.thedogapi.com/v1/breeds').status_code)"
```

#### dbt Issues
```bash
# Check profiles
dbt debug

# Clear compiled files
dbt clean

# Re-install dependencies
dbt deps
```

#### BigQuery Issues
```bash
# Check dataset exists
bq ls YOUR_PROJECT_ID:

# Verify table structure
bq show YOUR_PROJECT_ID:bronze.dog_breeds
```

### Getting Help

- **Issues**: Report bugs at [GitHub Issues](https://github.com/your-username/dogs-as-a-service-pipeline/issues)
- **Documentation**: Full documentation in [`docs/`](docs/) directory
- **dbt Docs**: Run `dbt docs generate && dbt docs serve` for model documentation

---

**🔗 Quick Links:**
- [Complete Setup Guide](docs/SETUP_GUIDE.md)
- [Architecture Documentation](docs/ARCHITECTURE.md) 
- [API Reference](docs/API_REFERENCE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
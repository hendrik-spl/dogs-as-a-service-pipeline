# System Architecture

## Overview

This document outlines the complete system architecture for the Dog Breed Explorer project, including data pipeline, CI/CD workflows, and BigQuery dataset structure. The architecture follows modern data engineering practices with automated testing and deployment.

## 🏠 High-Level Architecture

```
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│      GitHub         │    │   Google Cloud     │    │   BigQuery Data   │
│   Repository       │    │    Platform        │    │   Warehouse       │
│                    │    │                   │    │                   │
│ ┌──────────────┐ │    │ ┌──────────────┐ │    │ ┌──────────────┐ │
│ │ CI/CD Actions │ │    │ │ Cloud Function │ │    │ │ Bronze Layer  │ │
│ │  - PR Tests    │────▶│ │ ETL Pipeline   │────▶│ │ (Raw Data)    │ │
│ │  - Prod Deploy │ │    │ └──────────────┘ │    │ └──────────────┘ │
│ └──────────────┘ │    │        │        │    │        ↓        │
│        │        │    │        │        │    │ ┌──────────────┐ │
│ ┌──────────────┐ │    │ ┌──────────────┐ │    │ │ dbt Analytics │ │
│ │ dbt Models    │────▶│ │ GitHub Actions│────▶│ │ (Staging +    │ │
│ │  - staging    │ │    │ │ dbt Runner    │ │    │ │  Marts)       │ │
│ │  - marts      │ │    │ └──────────────┘ │    │ └──────────────┘ │
│ └──────────────┘ │    └───────────────────┘    └───────────────────┘
└───────────────────┘                           ↓
                                    ┌───────────────────┐
                                    │   Streamlit App   │
                                    │   (Frontend)      │
                                    └───────────────────┘
```

## 🔄 CI/CD Pipeline Architecture

### GitHub Actions Workflows

#### 1. PR Testing Workflow (`.github/workflows/pr-tests.yml`)
```yaml
Trigger: Pull Request to main/dev
Environment: testing
Target: dev dataset
Steps:
  1. Setup Python 3.11 + UV
  2. Google Cloud Authentication
  3. Create dbt profiles.yml dynamically
  4. Run: dbt deps → compile → run → test
  5. Report results to PR
```

#### 2. Production Deployment Workflow (`.github/workflows/deploy-prod.yml`)
```yaml
Trigger: Merge to main
Environment: production
Target: prod dataset
Steps:
  1. Setup Python 3.11 + UV
  2. Google Cloud Authentication
  3. Create dbt profiles.yml for production
  4. Run: dbt deps → compile → run → test
  5. Deploy to production dataset
```

### Authentication Flow
```
GitHub Secret (GCP_SA_KEY)
     ↓
google-github-actions/auth@v2
     ↓
Credentials file + GOOGLE_APPLICATION_CREDENTIALS
     ↓
dbt profiles.yml (keyfile: path)
     ↓
BigQuery Connection
```

## Dataset Structure

### 1. Bronze Layer (Raw Data)
- **Dataset**: `bronze`
- **Purpose**: Raw, unprocessed data from external sources
- **Data Quality**: Minimal validation, preserves original format
- **Retention**: Long-term storage of raw data
- **Tables**:
  - `dog_breeds` - Raw data from TheDogAPI via dlt pipeline

### 2. Staging Layer (Cleaned Data)
- **Dataset**: `dog_explorer` (dev: `dog_explorer_dev`) — single dataset per env
- **Purpose**: Cleaned, validated, and standardized data
- **Data Quality**: Type casting, null handling, data validation
- **Retention**: Medium-term storage
- **Tables**:
  - `stg_dog_breeds` - Cleaned and parsed dog breed data

### 3. Marts Layer (Business-Ready Data)
- **Dataset**: `dog_explorer` (dev: `dog_explorer_dev`) — single dataset per env
- **Purpose**: Business-ready dimensional models for analytics
- **Data Quality**: Business logic applied, optimized for querying
- **Retention**: Long-term storage of business data
- **Sub-datasets**:
  - `dog_explorer_marts_core` (dev: `dog_explorer_dev_marts_core`)
    - `dim_breeds` - Dimension table for breed information
    - `dim_temperament` - Dimension table for temperament traits
    - `fct_breed_metrics` - Fact table for breed measurements and metrics

## 📊 Data Flow Architecture

### End-to-End Data Pipeline
```
┌─────────────────────┐
│ External Data Source │
│    TheDogAPI REST    │
│    (172 breeds)      │
└─────────────────────┘
           ↓
┌─────────────────────┐
│  ETL Pipeline Layer  │
│ - Cloud Function    │
│ - DLT Framework     │
│ - Error Handling    │
└─────────────────────┘
           ↓
┌─────────────────────┐
│    Bronze Layer      │
│   bronze.dog_breeds │
│   (Raw JSON data)   │
└─────────────────────┘
           ↓ (dbt via CI/CD)
┌─────────────────────┐
│   Staging Layer     │
│   stg_dog_breeds    │
│   (Cleaned/Parsed)  │
└─────────────────────┘
           ↓ (dbt transforms)
┌─────────────────────┐
│   Analytics Layer   │
│ - dim_breeds       │
│ - dim_temperament  │
│ - fct_breed_metrics│
└─────────────────────┘
           ↓
┌─────────────────────┐
│  Frontend Layer     │
│ - Streamlit App    │
│ - Interactive UI   │
│ - AI Assistant     │
└─────────────────────┘
```

### CI/CD Integration
```
Developer
    ↓ (git push)
GitHub Repository
    ↓ (PR trigger)
GitHub Actions (PR Testing)
    ↓ (runs dbt --target dev)
Development Dataset
    ↓ (merge to main)
GitHub Actions (Production)
    ↓ (runs dbt --target prod)
Production Dataset
    ↓
Streamlit App
```

## Environment Separation

### Development Environment
- **Models Dataset**: `dog_explorer_dev`
- **Tests Dataset**: `dog_explorer_dev_tests`

### Production Environment
- **Models Dataset**: `dog_explorer`
- **Tests Dataset**: `dog_explorer_tests`

## Naming Conventions

### Datasets
- `bronze` - Raw data layer
- `dog_explorer_{env}` - Analytics models (single dataset per env)
- `dog_explorer_{env}_tests` - dbt test artifacts

### Tables
- `stg_*` - Staging tables (cleaned raw data)
- `dim_*` - Dimension tables (descriptive attributes)  
- `fct_*` - Fact tables (measurable events/metrics)

### GitHub Workflows
- `pr-tests.yml` - PR testing workflow (dev dataset)
- `deploy-prod.yml` - Production deployment workflow

## 🎦 Benefits of This Architecture

### Data Engineering Benefits
1. **Clear Separation**: Each layer has a distinct purpose
2. **Data Lineage**: Easy to trace data from source to consumption
3. **Environment Isolation**: Development and production are completely separate
4. **Scalability**: Easy to add new data sources and business domains
5. **Performance**: Optimized materializations for each use case
6. **Maintainability**: Clear ownership and responsibility for each layer

### DevOps Benefits
7. **Automated Testing**: Catch issues before production deployment
8. **Consistent Deployments**: Identical process for every release
9. **Rollback Capability**: Git-based version control for all changes
10. **Environment Parity**: Dev/prod consistency eliminates deployment surprises
11. **Visibility**: Complete audit trail of all changes and deployments

### Business Benefits
12. **Reduced Downtime**: Automated testing prevents production failures
13. **Faster Development**: Parallel development with automated validation
14. **Quality Assurance**: Built-in data quality checks and monitoring
15. **Compliance**: Automated documentation and audit trails
16. **Modular UI**: Frontend split into pages and shared filters for reuse

## 🔄 Development Workflow

### Feature Development Cycle
1. **Create Feature Branch**: `git checkout -b feature/new-model`
2. **Develop Locally**: Make changes, test with `dbt run --target dev`
3. **Create Pull Request**: Push branch, open PR
4. **Automated Testing**: GitHub Actions runs dbt against dev dataset
5. **Code Review**: Manual review + automated test results
6. **Merge to Main**: Triggers production deployment
7. **Production Deploy**: GitHub Actions runs dbt against prod dataset

### Monitoring & Observability
- **GitHub Actions**: Workflow status and logs
- **BigQuery**: Data freshness and quality metrics
- **Streamlit**: Application health and usage
- **Cloud Functions**: ETL pipeline execution logs

## ⚙️ Deployment Architecture

### Environment Strategy

#### Development Environment
- **Trigger**: Pull Request to main/dev
- **Dataset**: `dog_explorer_dev`
- **Tests**: `dog_explorer_dev_tests`
- **Purpose**: Validate changes before production
- **Workflow**: `.github/workflows/pr-tests.yml`

#### Production Environment  
- **Trigger**: Merge to main branch
- **Dataset**: `dog_explorer`
- **Tests**: `dog_explorer_tests`
- **Purpose**: Serve production analytics
- **Workflow**: `.github/workflows/deploy-prod.yml`

### Service Account Architecture
```
GitHub Repository Secrets
    ↓
GCP_SA_KEY (Service Account JSON)
    ↓
Google Cloud Authentication
    ↓
BigQuery Permissions:
- bigquery.dataEditor
- storage.admin
    ↓
dbt Connection via keyfile
```

## 🛡️ Security Architecture

### Authentication & Authorization
1. **GitHub Secrets**: Encrypted service account keys
2. **Environment Separation**: Isolated dev/prod environments
3. **Least Privilege**: Service accounts with minimal required permissions
4. **No Hardcoded Credentials**: All secrets managed via GitHub/GCP

### Data Security
1. **Encrypted in Transit**: HTTPS/TLS for all API calls
2. **Encrypted at Rest**: BigQuery native encryption
3. **Access Control**: IAM-based dataset permissions
4. **Audit Logging**: Cloud Audit Logs for all operations

## 📝 Best Practices

### Data Architecture
1. **Never query bronze directly** for business logic
2. **Use staging for data quality checks** and validation
3. **Build business logic in marts** layer only
4. **Test each layer independently**
5. **Document schema changes** and data lineage
6. **Monitor data freshness** and quality metrics

### CI/CD Practices
7. **Automated Testing**: Every PR runs full dbt test suite
8. **Environment Parity**: Dev and prod use same code/configs
9. **Rollback Strategy**: Git-based rollbacks via branch management
10. **Monitoring**: GitHub Actions provide deployment visibility

### Application Practices
11. **Prefer metric units** in UI for consistency (kg, cm)
12. **Secrets management**: Streamlit requires `st.secrets["gcp_service_account"]`; optional `OPENAI_API_KEY` for assistant
13. **Dataset scoping**: Set `PROJECT_DATASET` in `streamlit_app.py` to the correct `..._marts_core` dataset
14. **Error Handling**: Graceful degradation when services unavailable
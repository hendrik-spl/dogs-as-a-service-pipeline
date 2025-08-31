# Project Overview

## dogs-as-a-service-pipeline

### Current State
This is a **production-ready data engineering project** featuring a functional ETL pipeline that extracts dog breed information from TheDogAPI and a comprehensive **dbt analytical data warehouse**. The project demonstrates end-to-end data engineering capabilities from raw data ingestion to business-ready analytical models, built with modern tools and best practices.

### Repository Information
- **Owner**: hendrik (local development)
- **Repository**: dogs-as-a-service-pipeline (local project)
- **Primary Language**: Python 3.11+
- **Purpose**: ETL pipeline + Analytics for dog breed data
- **Deployment**: Google Cloud Functions
- **Storage**: Google BigQuery + Google Cloud Storage

### Key Features

#### **ETL Pipeline Layer**
- **Data Extraction**: Fetches dog breed data from TheDogAPI REST API (172 breeds)
- **Data Processing**: Adds extraction timestamps and metadata enrichment
- **Dual Storage**: Saves raw data to GCS and processed data to BigQuery bronze layer
- **Cloud Native**: Designed for Google Cloud Platform deployment
- **Serverless**: Runs as a Cloud Function triggered by Cloud Scheduler
- **Modern Tooling**: Uses DLT (data load tool) for pipeline orchestration

#### **dbt Analytical Layer**
- **Data Modeling**: Complete staging and mart layer transformations
- **Advanced Analytics**: Temperament analysis, physical characteristics scoring
- **Business Intelligence**: Family suitability, training difficulty, longevity analysis
- **Data Quality**: Comprehensive testing suite with 20+ tests
- **Documentation**: Auto-generated docs with model lineage and business context
- **Dimensional Modeling**: Proper fact/dimension separation following best practices

### Technology Stack

#### **Data Ingestion & Pipeline**
- **Pipeline Framework**: DLT (Data Load Tool) v1.15.0+
- **HTTP Client**: requests for API calls
- **Runtime**: Google Cloud Functions (Python 3.11+)
- **Package Management**: UV (ultraviolet) for dependency management
- **Development**: Jupyter notebooks for EDA and prototyping

#### **Data Platform**
- **Cloud Platform**: Google Cloud Platform
- **Data Warehouse**: Google BigQuery (bronze, staging, marts layers)
- **Data Lake**: Google Cloud Storage (raw data partitioned by date)
- **Orchestration**: Cloud Scheduler for automated execution

#### **Analytics & Transformation**
- **Transformation Tool**: dbt (data build tool) v1.5.0+
- **dbt Adapter**: dbt-bigquery for BigQuery integration
- **Testing**: dbt_utils and dbt_expectations packages
- **Documentation**: dbt docs with auto-generated lineage graphs; Streamlit docs added
- **Version Control**: Git-based development workflow

### Current Implementation Status

#### **CI/CD & DevOps**
- ✅ GitHub Actions workflows for PR testing (`.github/workflows/pr-tests.yml`)
- ✅ Automated dbt testing on pull requests
- ✅ Production deployment workflow (`.github/workflows/deploy-prod.yml`)
- ✅ Automated dbt run/test on merge to main branch
- ✅ Service account authentication configured for CI/CD
- ✅ Environment-specific configurations (dev/prod targets)

#### **ETL Pipeline Layer**
- ✅ Core pipeline functionality implemented (`src/dog_api_pipeline.py`)
- ✅ Data extraction from TheDogAPI (172 breeds)
- ✅ Data transformation and metadata enrichment (extraction timestamps)
- ✅ BigQuery integration (bronze layer: `bronze.dog_breeds`)
- ✅ Cloud Storage integration (raw JSON data, date-partitioned)
- ✅ Cloud Function HTTP entry point (`main.py`)
- ✅ Error handling and comprehensive logging
- ✅ Package dependencies defined (pyproject.toml with UV)

#### **dbt Analytical Layer** 
- ✅ Complete dbt project structure configured
- ✅ Staging layer: `stg_dog_breeds` with intelligent range parsing
- ✅ Mart layer: 3 analytical models (`dim_breeds`, `fct_breed_metrics`, `dim_temperament`)
- ✅ Comprehensive testing suite: 20+ schema tests + 3 custom tests
- ✅ Rich documentation with model descriptions and business context
- ✅ Advanced analytics: temperament scoring, family suitability analysis
- ✅ Data quality monitoring with completeness scores

#### **Infrastructure & Operations**
- ✅ Development environment configured
- ✅ BigQuery dataset structure (bronze → staging → marts)
- ✅ dbt profiles template with dev/prod configurations
- ✅ CI/CD pipeline implemented (GitHub Actions)
- ✅ Automated testing and deployment workflows

### End-to-End Data Architecture

#### **Bronze Layer (Raw Data Ingestion)**
1. **Extraction**: Fetch dog breeds from TheDogAPI REST endpoint (172 breeds)
2. **Raw Storage**: Save original JSON to Cloud Storage (date-partitioned)
3. **Bronze Load**: Load structured data to BigQuery `bronze.dog_breeds` table
4. **Orchestration**: Triggered by HTTP request via Cloud Function or direct execution

#### **Silver Layer (dbt Staging)**
5. **Data Cleaning**: Parse and normalize raw JSON in `stg_dog_breeds`
   - Intelligent range parsing (weights, heights, lifespans)
   - Data type casting and standardization
   - Quality flags and completeness scoring
   - Null handling and edge case management

#### **Gold Layer (dbt Marts)**
6. **Dimensional Modeling**: Transform to business-ready analytical models
   - **`dim_breeds`**: Master breed dimension with derived insights
   - **`fct_breed_metrics`**: Physical measurements and calculated metrics
   - **`dim_temperament`**: Behavioral analysis with scoring algorithms

### Enhanced Data Schema

#### **Raw Data Schema** (`bronze.dog_breeds`)
- **Identifiers**: `id`, `name`, `_dlt_id`, `_dlt_load_id`
- **Physical traits**: `weight` (nested: imperial/metric), `height` (nested: imperial/metric), `life_span`
- **Characteristics**: `temperament`, `bred_for`, `breed_group`, `origin`
- **Metadata**: `extracted_at`, `extraction_date`, `reference_image_id`
- **Additional**: (additional fields from API as available)

#### **Analytical Schema** (dbt Marts)
- **Dimensional Attributes**: Size categories, activity levels, family suitability
- **Calculated Metrics**: Average measurements, weight-height ratios, build types
- **Behavioral Scoring**: Temperament scores (0-1 scale), training difficulty classifications
- **Data Quality**: Completeness scores, data availability flags

### Business Value & Use Cases

#### **Analytical Insights Enabled**
- **Family Matching**: Find breeds optimal for different household types
- **Longevity Analysis**: Compare breed lifespans and health predictions  
- **Training Programs**: Tailor approaches based on temperament analysis
- **Breeding Decisions**: Physical characteristic correlations and patterns
- **Veterinary Insights**: Breed-specific health and behavioral patterns

#### **Key Business Questions Answered**
- Which breeds have the longest predicted life span?
- What's the distribution of breeds by weight class?
- Which temperament traits are most common among family-friendly breeds?
- How do physical characteristics vary by breed group?
- Which breeds are best suited for different family situations?
- What are the training difficulty patterns across different breed groups?
- Which breeds have the most complex temperament profiles?

#### **Key Performance Indicators**
- **Data Coverage**: 172+ dog breeds with 90%+ data completeness
- **Analytical Depth**: 8+ derived metrics per breed (family scores, training difficulty, etc.)
- **Data Quality**: 20+ automated tests ensuring accuracy and consistency
- **Business Value**: Answers 15+ analytical questions across multiple domains

### Future Development Roadmap

#### **Phase 1: Production Hardening** (Partially Complete)
- ✅ **CI/CD Pipeline**: GitHub Actions workflow for automated testing and deployment
- **Infrastructure as Code**: Terraform configurations for reproducible environments
- **Monitoring & Alerting**: Cloud Monitoring integration with failure notifications
- **ETL Testing**: pytest framework for pipeline validation

#### **Phase 2: Advanced Analytics**
- **ML Integration**: Breed recommendation engine based on user preferences
- **Real-time Updates**: Streaming pipeline for live data updates
- **Data Enrichment**: Additional APIs (nutrition, health conditions, grooming needs)
- **Performance Optimization**: Incremental loading and change data capture

#### **Phase 3: Platform Extension**
- **Multi-Source Integration**: Cat breeds, exotic pets, veterinary data
- **API Development**: REST API for external applications
- **Dashboard Creation**: Self-service analytics via Looker Studio/Power BI
- **Data Marketplace**: Productized datasets for pet industry partners

### Learnings and Design Decisions

- Metric-only UI avoids unit confusion and simplifies filter logic.
- Temperament UNNEST must be in FROM/joined CTEs to keep filters valid in BigQuery.
- Dataset scoping: the Streamlit app targets a single dataset prefix via `PROJECT_DATASET`; switch this per environment.
- Assistant grounding: always pass a compact, clipped dataset excerpt to reduce hallucinations.
- Quota resilience: fall back to deterministic heuristic recommendations when OpenAI quota is exceeded.

### Project Maturity Assessment

#### **Production Ready Components**
- ✅ **Data Pipeline**: Robust, error-handled ETL with comprehensive logging
- ✅ **Data Models**: Well-tested dimensional models following industry best practices  
- ✅ **Documentation**: Comprehensive technical and business documentation
- ✅ **Data Quality**: Multi-layer testing ensuring reliability

#### **Development/Staging Components**  
- ✅ **Deployment**: Automated via GitHub Actions CI/CD
- 🔄 **Monitoring**: Basic logging, needs enhanced observability
- 🔄 **Testing**: dbt tests implemented, needs Python unit testing

This project demonstrates enterprise-level data engineering capabilities with both technical depth and clear business value, featuring modern CI/CD practices and automated deployment workflows, making it an excellent showcase for data engineering interviews and real-world applications.

---

## Dashboard (Streamlit)

### Overview

The repository includes a modular Streamlit dashboard that reads directly from the dbt marts in BigQuery.

- Entry point: `streamlit_app.py`
- Modules:
  - `frontend/filters.py`: Renders sidebar filters and builds SQL WHERE clauses (metric-only)
  - `frontend/overview.py`: Overview charts and insights
  - `frontend/finder.py`: Placeholder for “Find your own dog” page

### Design Choices

- Metric-only UI (kg, cm) to ensure consistent units across visuals and filters
- Tabs instead of sidebar navigation to keep the main view focused
- Caching with `st.cache_data(ttl=600)` for responsive queries
 - Assistant grounded strictly in the current filtered dataset; streams responses; heuristic fallback on quota

### Query Notes

- Temperament query uses `UNNEST` joined in the FROM clause for valid syntax
- Family suitability filters apply to `dim_temperament` with a clear alias (`tt`)
- IN-clause values are safely quoted to avoid syntax errors

### How to Run

```bash
streamlit run /Users/hendrik/Documents/Repositories2/dogs-as-a-service-pipeline/streamlit_app.py
```

Requirements:

- `st.secrets["gcp_service_account"]` configured with a valid BigQuery service account
- Optional `st.secrets["OPENAI_API_KEY"]` for the assistant (heuristic fallback without it)
- dbt marts available in the configured project (e.g., `..._marts_core` dataset)
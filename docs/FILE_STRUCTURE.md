# File Structure Documentation

## Current Directory Structure

```
dogs-as-a-service-pipeline/
├── .github/                         # GitHub configuration
│   └── workflows/                   # GitHub Actions CI/CD
│       ├── pr-tests.yml             # PR testing workflow
│       └── deploy-prod.yml          # Production deployment workflow
├── docs/                            # Project documentation
│   ├── ARCHITECTURE.md              # System architecture and CI/CD
│   ├── API_REFERENCE.md             # API schemas and data models
│   ├── DEPLOYMENT.md                # Deployment guides and GitHub Actions
│   ├── FILE_STRUCTURE.md            # This file - directory structure
│   ├── PROJECT_OVERVIEW.md          # Project summary and roadmap
│   └── README.md                    # Documentation overview
├── frontend/                        # Streamlit modular frontend
│   ├── overview.py                  # Overview page renderer
│   ├── finder.py                    # Finder placeholder page
│   └── filters.py                   # Sidebar filters and SQL clause builder
├── src/                             # ETL Pipeline source code
│   └── dog_api_pipeline.py          # Main ETL pipeline implementation (111 lines)
├── models/                          # dbt transformation models
│   ├── sources.yml                  # Source data definitions
│   ├── staging/
│   │   ├── stg_dog_breeds.sql       # Staging model with data cleaning
│   │   └── schema.yml               # Staging tests and documentation
│   └── marts/core/
│       ├── dim_breeds.sql           # Master breed dimension
│       ├── fct_breed_metrics.sql    # Physical measurements fact table
│       ├── dim_temperament.sql      # Behavioral analysis dimension
│       └── schema.yml               # Mart tests and documentation
├── tests/                           # Custom dbt tests
│   └── assert_breed_consistency_across_models.sql
├── analyses/                        # dbt analysis files
│   └── breed_insights.sql           # Sample analytical queries
├── macros/                          # dbt macros
│   └── generate_schema_name.sql     # Env-aware dataset resolution (models vs tests)
├── dbt_packages/                    # Installed dbt packages
├── dbt_internal_packages/           # dbt internal packages
├── target/                          # dbt compile target directory
├── data_sample.csv                  # Sample dog breed data for reference
├── dbt-sa.json                      # Service account JSON file
├── requirements.txt                 # Python requirements (legacy)
├── CLAUDE.md                        # AI development guidance
├── README.md                        # Project overview incl. dbt documentation
├── streamlit_app.py                 # Streamlit entrypoint using modular frontend
├── README_dbt.md                    # Deprecated; content merged into README.md
├── main.py                          # Cloud Function entry point (8 lines)
├── pyproject.toml                   # Python project configuration and dependencies
├── uv.lock                          # UV package manager lock file
├── package-lock.yml                # Package lock file
├── dbt_project.yml                  # dbt project configuration
├── profiles.yml                     # dbt BigQuery connection template
└── packages.yml                     # dbt package dependencies
```

## File Descriptions

### ETL Pipeline Source Code

#### `src/dog_api_pipeline.py` (111 lines)
- **Purpose**: Core ETL pipeline implementation
- **Key Functions**:
  - `fetch_dog_breeds()`: DLT resource for data extraction
  - `save_to_cloud_storage()`: Raw data storage to GCS
  - `load_to_bigquery()`: Main pipeline orchestration
  - `main()`: Cloud Function entry point
- **Dependencies**: dlt, requests, datetime, typing
- **Architecture**: Dual-pipeline pattern (GCS + BigQuery)

#### `main.py` (8 lines)  
- **Purpose**: Cloud Function HTTP handler
- **Function**: `dog_pipeline_handler(request)` 
- **Role**: Wrapper for Cloud Function deployment
- **Import**: Delegates to `dog_api_pipeline.main()`
- **Logging**: Includes pipeline start logging

### dbt Analytics Layer

#### `models/sources.yml` (47 lines)
- **Purpose**: Source data definitions for bronze layer
- **Configuration**: BigQuery `bronze.dog_api_raw` table definition
- **Documentation**: Column descriptions and data freshness tests
- **Schema**: Complete source schema with data types and descriptions

#### `models/staging/stg_dog_breeds.sql` (127 lines)
- **Purpose**: Core staging model with data cleaning and normalization
- **Key Features**:
  - Intelligent range parsing for weights, heights, lifespans
  - Data type casting and standardization
  - Quality flags and completeness scoring
  - Null handling and edge case management
- **Output**: Clean, typed dataset ready for analytical modeling

#### `models/staging/schema.yml` (127 lines)
- **Purpose**: Staging layer tests and documentation
- **Tests**: 15+ schema tests (uniqueness, ranges, accepted values)
- **Documentation**: Comprehensive column descriptions
- **Quality**: Data range validation and consistency checks

#### `models/marts/core/dim_breeds.sql` (103 lines)
- **Purpose**: Master breed dimension with business classifications
- **Key Features**:
  - Size categorization and activity level inference
  - Family suitability scoring based on temperament analysis
  - Longevity categorization and data completeness metrics
  - Derived business insights and calculated averages
- **Materialization**: Table (optimized for analytical queries)

#### `models/marts/core/fct_breed_metrics.sql` (144 lines)
- **Purpose**: Physical measurements fact table with calculated metrics
- **Key Features**:
  - Weight-height ratio calculations and build type classification
  - Measurement consistency analysis
  - Performance optimized for analytical queries
  - Range calculations and statistical metrics
- **Materialization**: Table (analytical performance)

#### `models/marts/core/dim_temperament.sql` (151 lines)
- **Purpose**: Behavioral analysis dimension with temperament scoring
- **Key Features**:
  - Temperament trait normalization using UNNEST operations
  - 0-1 normalized scoring across behavioral categories
  - Training difficulty and family suitability predictions
  - Primary temperament classification algorithms
- **Advanced SQL**: Array operations, complex scoring logic

#### `models/marts/core/schema.yml` (186 lines)
- **Purpose**: Mart layer comprehensive testing and documentation
- **Tests**: Referential integrity, business logic validation, range checks
- **Documentation**: Business context and usage examples for each model
- **Quality**: Cross-model consistency and relationship validation

### dbt Testing Framework

#### `tests/assert_breed_consistency_across_models.sql` (59 lines)
- **Purpose**: Cross-model referential integrity validation
- **Logic**: Ensures breeds exist consistently across all mart models
- **Data Quality**: Prevents orphaned records and maintains consistency

### dbt Configuration Files

#### `dbt_project.yml` (65 lines)
- **Purpose**: dbt project configuration and materialization strategy
- **Configuration**:
  - Staging models as views; marts as tables
  - Single dataset per env (`target.schema`) via `generate_schema_name`
  - Tests routed to `<target.schema>_tests`
  - Stable `bronze` source dataset

#### `profiles.yml` (34 lines)
- **Purpose**: BigQuery connection template
- **Environments**: Dev and production configurations
- **Authentication**: Service account and OAuth examples
- **Usage**: Template for `~/.dbt/profiles.yml`

#### `packages.yml` (4 lines)
- **Purpose**: dbt package dependencies
- **Dependencies**: dbt_utils v1.1.1, dbt_expectations v0.10.1
- **Usage**: `dbt deps` installs testing and utility macros

### Sample Data & Analysis

#### `data/data_sample.csv` (173 lines)
- **Purpose**: Sample dog breed data for development and testing
- **Content**: 172 dog breed records with all API fields
- **Usage**: Development reference and data structure analysis

#### `analyses/breed_insights.sql` (87 lines)
- **Purpose**: Sample analytical queries demonstrating project capabilities
- **Content**: 6 different business analysis examples
- **Business Value**: Family matching, longevity analysis, training insights

#### `README_dbt.md` (deprecated)
- **Note**: This file is deprecated; refer to `README.md` for dbt docs

### Configuration Files

#### `pyproject.toml` (13 lines)
- **Purpose**: Modern Python project configuration
- **Package Manager**: UV-compatible
- **Dependencies**:
  - `dlt[bigquery,gcs]>=1.15.0`: Pipeline orchestration
  - `functions-framework>=3.9.2`: Cloud Function runtime  
  - `gcloud>=0.18.3`: Google Cloud SDK
  - `google-cloud-bigquery-storage>=2.32.0`: BigQuery API
  - `ipykernel>=6.30.1`: Jupyter notebook support
- **Python Requirement**: >=3.11

#### `uv.lock` (Generated)
- **Purpose**: UV package manager lock file
- **Content**: Exact dependency versions and hashes
- **Role**: Ensures reproducible builds
- **Management**: Auto-generated, not manually edited

#### `.python-version`
- **Purpose**: Python version specification
- **Usage**: Used by pyenv, UV, and other Python version managers
- **Content**: Specifies exact Python version for project

#### `.gitignore` (4,688 bytes)
- **Coverage**: Comprehensive Python ecosystem patterns
- **Modern Tools**: UV, Poetry, PDM, Pixi, Ruff, Marimo
- **Frameworks**: Django, Flask, Scrapy, Celery
- **Development**: Jupyter, PyCharm, VS Code, pytest
- **Cloud**: Google Cloud, AWS, Azure patterns

### Documentation

#### `docs/README.md` (36 lines)
- **Purpose**: Documentation navigation and overview
- **Structure**: Links to other documentation files
- **Audience**: AI agents and human developers
- **Last Updated**: August 26, 2025

#### `docs/PROJECT_OVERVIEW.md` (86 lines)
- **Purpose**: Complete project summary and roadmap
- **Content**: Current state, features, tech stack, roadmap
- **Status**: Functional pipeline (not initial setup)
- **Key Info**: ETL architecture, 172 dog breeds, GCP deployment

#### `docs/ARCHITECTURE.md` (187 lines)
- **Purpose**: Detailed technical architecture
- **Content**: System design, data flow, technology decisions
- **Diagrams**: ASCII architecture diagrams
- **Code Examples**: Implementation snippets and patterns

#### `CLAUDE.md` (Updated)
- **Purpose**: AI development assistant guidance
- **Content**: Project context, development commands, architecture notes
- **Target**: Claude Code and other AI development tools
- **Updates**: Reflects actual implemented functionality

#### `README.md` (1 line)
- **Status**: Minimal placeholder with project title
- **Content**: "# dogs-as-a-service-pipeline"
- **TODO**: Needs expansion with usage instructions

### Development Files

#### `eda_testing.ipynb`
- **Purpose**: Exploratory data analysis and testing
- **Content**: Interactive testing of pipeline functions
- **Usage**: Development and data exploration
- **Sample Output**: Shows successful data extraction (172 breeds)
- **Cells**: Import statements and function testing

## Source Code Structure Analysis

### Module Organization
```python
# src/dog_api_pipeline.py structure
├── Imports (lines 1-5)
├── DLT Resource Definition (lines 8-37)
│   └── fetch_dog_breeds()
├── Raw Storage Function (lines 40-58)
│   └── save_to_cloud_storage()  
├── Main Pipeline Function (lines 61-86)
│   └── load_to_bigquery()
└── Entry Points (lines 89-111)
    ├── main() - Cloud Function entry
    └── __main__ guard
```

### Key Implementation Patterns
- **DLT Decorators**: `@dlt.resource` for pipeline components
- **Error Handling**: Try/catch with logging for API calls
- **Dual Storage**: Parallel writes to GCS and BigQuery
- **Metadata Enrichment**: Timestamps added to all records
- **Cloud Function Ready**: HTTP request/response handling

## Data Flow Through Files

### ETL Pipeline Flow
1. **Trigger**: HTTP request to Cloud Function or `python main.py`
2. **Entry**: `main.py:dog_pipeline_handler()` 
3. **Orchestration**: `src/dog_api_pipeline.py:main()`
4. **Execution**: `load_to_bigquery()` coordinates dual pipeline
5. **Data Flow**: 
   - `fetch_dog_breeds()` → API extraction (TheDogAPI)
   - `save_to_cloud_storage()` → Raw storage (GCS)
   - DLT pipeline → BigQuery bronze layer loading

### dbt Analytics Flow  
6. **Source Definition**: `models/sources.yml` → Bronze layer connection
7. **Staging**: `models/staging/stg_dog_breeds.sql` → Data cleaning & parsing
8. **Testing**: `models/staging/schema.yml` → Data validation (15+ tests)
9. **Marts**: Business-ready models creation
   - `dim_breeds.sql` → Master breed dimension
   - `fct_breed_metrics.sql` → Physical measurements fact
   - `dim_temperament.sql` → Behavioral analysis dimension
10. **Quality Assurance**: Custom tests → Business logic validation
11. **Documentation**: Auto-generated docs → Model lineage & descriptions

## Current CI/CD Implementation (✅ Complete)

### GitHub Actions Workflows

#### PR Testing Workflow
- **File**: `.github/workflows/pr-tests.yml`
- **Purpose**: Automated validation of changes before merge
- **Coverage**: Full dbt test suite execution
- **Environment**: Isolated development dataset
- **Security**: Service account authentication

#### Production Deployment Workflow
- **File**: `.github/workflows/deploy-prod.yml` 
- **Purpose**: Automated production deployment
- **Trigger**: Merge to main branch
- **Coverage**: Production dbt run and test execution
- **Environment**: Production dataset with separate authentication

### Authentication Architecture
```
GitHub Repository Secrets (GCP_SA_KEY)
    ↓
google-github-actions/auth@v2
    ↓
Dynamic dbt profiles.yml creation
    ↓
BigQuery connection (keyfile method)
    ↓
dbt execution (dev/prod targets)
```

### Development Workflow Integration
1. **Feature Development**: Local development (optional)
2. **Pull Request**: Automated testing via GitHub Actions
3. **Code Review**: Manual review + automated test results
4. **Merge to Main**: Automatic production deployment
5. **Monitoring**: GitHub Actions logs and BigQuery validation

## Remaining Missing Elements

### ETL Pipeline Testing Infrastructure
- **No Python `tests/` directory**: Unit/integration tests for pipeline code
- **No test configuration**: No `pytest.ini` or similar testing config
- **No mocking**: No API response mocking for reliable testing

### GitHub Actions CI/CD (✅ Implemented)

#### `.github/workflows/pr-tests.yml` (59 lines)
- **Purpose**: Automated testing on pull requests
- **Trigger**: Pull requests to main/dev branches
- **Environment**: testing (GitHub environment)
- **Target**: dev dataset (`dog_explorer_dev`)
- **Steps**:
  - Python 3.11 + UV setup
  - Google Cloud authentication via service account
  - Dynamic dbt profiles.yml creation
  - dbt deps, compile, run, test execution
- **Authentication**: Uses `GCP_SA_KEY` GitHub secret

#### `.github/workflows/deploy-prod.yml` (56 lines)
- **Purpose**: Production deployment on main branch merge
- **Trigger**: Push to main branch
- **Environment**: production (GitHub environment)
- **Target**: prod dataset (`dog_explorer`)
- **Steps**:
  - Python 3.11 + UV setup
  - Google Cloud authentication
  - Production dbt profiles.yml creation
  - dbt deps, compile, run, test for production
- **Security**: Separate production environment with isolated secrets

### Remaining Infrastructure Gaps
- **No deployment configs**: No Terraform, Cloud Deployment Manager
- **No Docker**: No `Dockerfile` for containerization
- **No environment management**: No `.env.example` template

### Development Tools
- **No `Makefile`**: No build automation shortcuts
- **No pre-commit hooks**: No code quality automation (black, ruff, mypy)
- **No development docs**: No CONTRIBUTING.md or development setup guide

### Production Infrastructure
- **No monitoring configs**: No Cloud Monitoring alerting setup
- **No backup strategies**: No data backup/recovery procedures  
- **No secrets management**: No Google Secret Manager integration

## Repository Metadata

### Git Information
- **Remote**: https://github.com/hendrik-spl/dogs-as-a-service-pipeline.git
- **Current Branch**: main
- **Commits**: 1 (Initial commit: 6deb9b0)
- **Working Directory**: Modified files present
- **Untracked Files**: Several (docs/, src/, *.py, etc.)

### File Sizes
- **Largest**: `.gitignore` (4,688 bytes)
- **Code**: `dog_api_pipeline.py` (~3KB estimated)
- **Config**: `pyproject.toml` (small, 13 lines)
- **Documentation**: `docs/` directory (~15KB total)

## Recommended Structure Improvements

### Testing Addition
```
tests/
├── __init__.py
├── test_dog_api_pipeline.py        # Unit tests
├── test_integration.py             # Integration tests  
├── conftest.py                     # Pytest configuration
└── fixtures/                      # Test data
    └── sample_api_response.json
```

### Deployment Addition
```
deployment/
├── terraform/                     # Infrastructure as Code
├── cloudfunctions/                # Deployment configs  
└── environments/                  # Environment-specific settings
```

### Development Tools Addition
```
├── .pre-commit-config.yaml        # Code quality automation
├── Makefile                       # Build automation
├── docker-compose.yml             # Local development
└── .env.example                   # Environment template
```

## Current Project Strengths

### Architecture & Design
✅ **End-to-End Data Platform**: Complete ETL + Analytics pipeline
✅ **Layered Architecture**: Clean Bronze → Silver → Gold data flow
✅ **Modern Technology Stack**: DLT + dbt + BigQuery integration
✅ **Cloud-Native Design**: Ready for GCP production deployment
✅ **Dimensional Modeling**: Proper fact/dimension separation

### Code Quality & Testing
✅ **Comprehensive Testing**: 20+ dbt tests + 3 custom business logic tests
✅ **Data Quality Framework**: Multi-layer validation and monitoring
✅ **Clean Module Structure**: Well-organized source code separation
✅ **Advanced SQL Patterns**: Complex analytics with array operations, scoring algorithms
✅ **Error Handling**: Robust exception handling throughout pipeline

### Documentation & Development Experience
✅ **Comprehensive Documentation**: 6 detailed docs covering all aspects
✅ **Business Context**: Clear analytical value and use case definitions
✅ **Model Lineage**: dbt-generated documentation with dependency tracking
✅ **Development Ready**: Jupyter notebooks, sample data, analysis examples
✅ **Configuration Management**: Environment-specific settings (dev/prod)

### Analytics & Business Value
✅ **Advanced Analytics**: Temperament scoring, family suitability analysis
✅ **Derived Insights**: 15+ calculated business metrics
✅ **Range Intelligence**: Smart parsing of measurement ranges
✅ **Data Completeness Monitoring**: Quality scoring and availability tracking
✅ **Business-Ready Models**: Immediate analytical value for stakeholders
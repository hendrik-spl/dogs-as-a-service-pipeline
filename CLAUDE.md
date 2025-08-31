# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **functional ETL data pipeline** called "dogs-as-a-service-pipeline" that extracts dog breed data from TheDogAPI and loads it into Google Cloud Platform (BigQuery + Cloud Storage). The project uses modern Python data engineering tools and is designed for serverless deployment.

## Project State

**Current Status**: Production-ready ETL pipeline with:
- ✅ **Core Pipeline**: Functional data extraction, transformation, and loading
- ✅ **Dual Storage**: Raw data to Cloud Storage, processed data to BigQuery  
- ✅ **Cloud Function**: HTTP-triggered serverless execution
- ✅ **Data Processing**: 172 dog breeds with metadata enrichment
- ✅ **Modern Tooling**: DLT framework, UV package manager, Python 3.11+
- ✅ **CI/CD**: GitHub Actions for automated testing and deployment
## Architecture Quick Reference

### Data Flow
```
TheDogAPI → Cloud Function → Dual Storage (GCS + BigQuery)
```

### Key Files
- **`src/dog_api_pipeline.py`**: Core ETL pipeline (111 lines)
- **`main.py`**: Cloud Function HTTP handler (7 lines)
- **`pyproject.toml`**: Dependencies and project config
- **`eda_testing.ipynb`**: Development notebook
- **`docs/`**: Comprehensive documentation

### Technology Stack
- **Pipeline**: DLT (Data Load Tool) v1.15.0+
- **Cloud**: Google Cloud Platform (Functions, BigQuery, Storage)
- **Runtime**: Python 3.11+ with UV package manager
- **Data Source**: TheDogAPI REST API (172 breeds)

## Development Commands

### CI/CD Pipeline
```bash
# Automated testing on PR (GitHub Actions)
# - Runs dbt deps, compile, run --target dev, test
# - Uses service account authentication
# - Tests against development dataset

# Production deployment on merge to main
# - Runs dbt run --target prod
# - Deploys to production dataset
# - Automated via GitHub Actions
```

### Local Development
```bash
# Install dependencies
uv sync

# Test pipeline locally
python main.py

# Run specific components
python -c "from src.dog_api_pipeline import fetch_dog_breeds; print(len(list(fetch_dog_breeds())))"

# Start Jupyter for EDA
jupyter notebook eda_testing.ipynb
```

### Testing Commands
```bash
# dbt tests (automated in CI/CD)
dbt test

# Python unit tests (none implemented)
# pytest tests/
```

### Deployment Commands
```bash
# Automated via GitHub Actions on PR merge to main
# Manual deployment:
gcloud functions deploy dog-pipeline-handler \
    --runtime python311 \
    --source . \
    --entry-point dog_pipeline_handler \
    --trigger-http \
    --allow-unauthenticated \
    --memory 512MB \
    --timeout 540s \
    --update-env-vars BUCKET_URL=gs://dog-breed-raw-data,DESTINATION__BIGQUERY__LOCATION=europe-north2

# Test deployed function
curl -X POST https://REGION-PROJECT.cloudfunctions.net/dog-pipeline-handler
```

## Code Architecture

### Pipeline Components
1. **`fetch_dog_breeds()`** (`src/dog_api_pipeline.py:13`): DLT resource for API extraction
2. **`save_to_cloud_storage()`** (`src/dog_api_pipeline.py:40`): Raw data storage
3. **`load_to_bigquery()`** (`src/dog_api_pipeline.py:61`): Main orchestration
4. **`main()`** (`src/dog_api_pipeline.py:90`): Entry point with error handling

### Data Storage
- **BigQuery Dataset**: `bronze.dog_breeds` (structured data)
- **Cloud Storage**: Raw JSON files partitioned by date
- **Schema**: Auto-inferred by DLT with timestamp metadata

### Error Handling
- Request exceptions caught and logged
- JSON error responses for Cloud Function
- DLT provides robust pipeline error handling

## Development Workflow

### For Feature Development
1. **Explore**: Use `eda_testing.ipynb` for data exploration
2. **Implement**: Add functions to `src/dog_api_pipeline.py`
3. **Test Locally**: Run `python main.py` to verify
4. **Document**: Update relevant files in `docs/`

### For Infrastructure Changes
1. **Check Documentation**: Review `docs/DEPLOYMENT.md`
2. **Test Locally**: Verify with local credentials
3. **Deploy Incrementally**: Start with development environment
4. **Monitor**: Check Cloud Function logs and BigQuery tables

### For Bug Fixes
1. **Check Logs**: Use `gcloud functions logs read dog-pipeline-handler`
2. **Reproduce Locally**: Run pipeline with same conditions
3. **Fix and Test**: Verify fix doesn't break existing functionality
4. **Deploy**: Update Cloud Function

## Important Implementation Notes

### DLT Framework Usage
- **Resources**: Use `@dlt.resource` decorator for data extraction
- **Pipelines**: Separate pipelines for different destinations
- **Schema**: Auto-inference with explicit column type definitions where needed
- **Error Handling**: DLT provides retry logic and error tracking

### Google Cloud Integration
- **Authentication**: Service account with BigQuery and Storage permissions
- **Function Runtime**: HTTP-triggered with 540s timeout
- **Data Partitioning**: Date-based partitioning in Cloud Storage
- **BigQuery**: Replace mode for full refresh, bronze layer dataset

### Code Style and Conventions
- **Type Hints**: Use `List[Dict[str, Any]]` for data structures
- **Error Handling**: Catch specific exceptions with informative logging
- **Function Design**: Single responsibility principle
- **Documentation**: Docstrings for all public functions

## Performance Characteristics

### Current Scale
- **Data Volume**: 172 records per execution (~small dataset)
- **Execution Time**: ~30-60 seconds typical
- **API Calls**: Single request to TheDogAPI
- **Storage Operations**: Dual writes (parallel)

### Scaling Considerations
- **API Rate Limits**: TheDogAPI limits unknown (appears unlimited)
- **Cloud Function**: Adequate for current volume, consider memory optimization
- **BigQuery**: Well within quotas, consider slot usage for larger datasets
- **Storage**: No practical limits for current volume

## Security Considerations

### Current Security
- **Service Account**: Principle of least privilege (BigQuery Editor, Storage Admin)
- **API Keys**: No authentication required for TheDogAPI
- **Data**: Public dog breed information (no sensitive data)

### Production Security Recommendations
- **Secrets Management**: Use Google Secret Manager for any API keys
- **Network Security**: Consider VPC connector for private access
- **Monitoring**: Implement alerting for function failures
- **Access Control**: Restrict Cloud Function access as needed

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **`docs/PROJECT_OVERVIEW.md`**: Project summary, features, roadmap
- **`docs/ARCHITECTURE.md`**: System design, data flow, technical details
- **`docs/FILE_STRUCTURE.md`**: Directory structure and file organization
- **`docs/API_REFERENCE.md`**: API documentation and data schemas
- **`docs/DEPLOYMENT.md`**: Deployment guide for Google Cloud Platform

## Development Priorities

### Immediate Improvements Needed
1. **Testing Framework**: Add pytest with unit and integration tests
2. **Monitoring**: Add Cloud Monitoring alerting for failures
3. **Data Validation**: Add explicit data quality checks
4. **Environment Protection**: Add manual approval for production deployments

### Medium-Term Enhancements
1. **Silver/Gold Layers**: Add data transformation and analytics layers
2. **Incremental Loading**: Optimize for incremental data updates
3. **Error Recovery**: Add retry logic and dead letter queues
4. **Performance**: Optimize for larger datasets if needed

### Long-Term Considerations
1. **Multi-Source**: Extend to additional pet-related APIs
2. **Real-Time**: Consider streaming for real-time updates
3. **Analytics**: Add data analysis and ML capabilities
4. **API Service**: Expose processed data via REST API

## Troubleshooting

### Common Issues
- **Authentication Errors**: Check service account permissions
- **API Failures**: Verify TheDogAPI accessibility
- **BigQuery Errors**: Check dataset existence and permissions
- **Function Timeouts**: Monitor execution time and optimize

### Debug Commands
```bash
# Check function logs
gcloud functions logs read dog-pipeline-handler --limit 50

# Verify BigQuery data
bq query "SELECT COUNT(*) FROM \`PROJECT.bronze.dog_breeds\`"

# Test API directly
curl "https://api.thedogapi.com/v1/breeds"
```

This guidance reflects the actual implemented functionality and provides actionable information for development work.
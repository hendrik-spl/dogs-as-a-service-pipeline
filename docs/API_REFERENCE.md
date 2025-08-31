# API & Data Model Reference

## Overview

This document describes the complete data architecture for the dogs-as-a-service-pipeline, including:
- ETL Pipeline API (Cloud Function endpoints)
- dbt Data Models (Analytics Layer schemas)
- Data flow from raw ingestion to business-ready marts

## Cloud Function API

### Endpoint
```
POST/GET https://{region}-{project-id}.cloudfunctions.net/dog-pipeline-handler
```

### HTTP Handler Function

#### `dog_pipeline_handler(request)`
**Location**: `main.py:3`

Entry point for Google Cloud Function HTTP requests.

**Parameters:**
- `request`: Flask Request object (can be None for local execution)

**Returns:**
```json
{
  "status": "success|error",
  "message": "Description of result",
  "load_info": "DLT load information (string representation)"
}
```

**Success Response Example:**
```json
{
  "status": "success",
  "message": "Dog breeds data loaded successfully",
  "load_info": "LoadInfo(pipeline_name='dog_breeds_pipeline', destination_name='bigquery', ..."
}
```

**Error Response Example:**
```json
{
  "status": "error", 
  "message": "Pipeline failed: API request timeout"
}
```

## Core Pipeline API

### Main Pipeline Function

#### `main(request=None)`
**Location**: `src/dog_api_pipeline.py:90`

Main entry point that orchestrates the complete ETL pipeline.

**Parameters:**
- `request` (optional): HTTP request object (ignored in current implementation)

**Workflow:**
1. Calls `load_to_bigquery()` to execute pipeline
2. Handles exceptions and returns status
3. Logs all operations

**Returns:** Same JSON structure as HTTP handler

### Data Processing Functions

#### `fetch_dog_breeds()`
**Location**: `src/dog_api_pipeline.py:13`

DLT resource function that extracts dog breed data from TheDogAPI.

**Decorator:** `@dlt.resource`
**Configuration:**
- `name`: "dog_breeds"
- `write_disposition`: "replace" 
- `columns`: {"extracted_at": {"data_type": "timestamp"}}

**External API:** `https://api.thedogapi.com/v1/breeds`

**Returns:** `List[Dict[str, Any]]` - List of enhanced dog breed records

**Data Enhancement:**
- Adds `extracted_at`: ISO format timestamp
- Adds `extraction_date`: Date string (YYYY-MM-DD)

**Error Handling:**
- Catches `requests.exceptions.RequestException`
- Logs errors and re-raises exceptions

#### `save_to_cloud_storage(data, date_partition)`
**Location**: `src/dog_api_pipeline.py:40`

Saves raw JSON data to Google Cloud Storage with date partitioning.

**Parameters:**
- `data`: `List[Dict[str, Any]]` - Raw dog breed data
- `date_partition`: `str` - Date string for partitioning (YYYY-MM-DD)

**Pipeline Configuration:**
- `pipeline_name`: "dog_breeds_raw_storage"
- `destination`: "filesystem" (GCS)
- `dataset_name`: "raw_data_{YYYY}_{MM}_{DD}"

**Storage Pattern:**
```
gs://{bucket}/raw_data_{YYYY}_{MM}_{DD}/raw_dog_api_data/
```

**Returns:** None (logs completion status)

#### `load_to_bigquery()`
**Location**: `src/dog_api_pipeline.py:61`

Main pipeline orchestrator that coordinates extraction and loading.

**Pipeline Configuration:**
- `pipeline_name`: "dog_breeds_pipeline"  
- `destination`: "bigquery"
- `dataset_name`: "bronze"

**Execution Flow:**
1. Fetches data using `fetch_dog_breeds()`
2. Saves raw data to GCS via `save_to_cloud_storage()`  
3. Loads processed data to BigQuery via DLT pipeline
4. Returns DLT LoadInfo object

**Returns:** `LoadInfo` - DLT pipeline execution results

## Data Schema

### API Source Schema (TheDogAPI)

The external API returns dog breed objects with the following structure:

```json
{
  "id": 1,
  "name": "Affenpinscher", 
  "bred_for": "Small rodent hunting, lapdog",
  "breed_group": "Toy",
  "life_span": "10 - 12 years",
  "temperament": "Stubborn, Curious, Playful, Adventurous, Active, Fun-loving",
  "origin": "Germany, France",
  "reference_image_id": "BJa4kxc4X",
  "weight": {
    "imperial": "6 - 13",
    "metric": "3 - 6"
  },
  "height": {
    "imperial": "9 - 11.5", 
    "metric": "23 - 29"
  }
}
```

### Enhanced Schema (Pipeline Output)

The pipeline adds metadata fields to each record:

```json
{
  "id": 1,
  "name": "Affenpinscher",
  "bred_for": "Small rodent hunting, lapdog",
  "breed_group": "Toy", 
  "life_span": "10 - 12 years",
  "temperament": "Stubborn, Curious, Playful, Adventurous, Active, Fun-loving",
  "origin": "Germany, France",
  "reference_image_id": "BJa4kxc4X",
  "weight": {"imperial": "6 - 13", "metric": "3 - 6"},
  "height": {"imperial": "9 - 11.5", "metric": "23 - 29"},
  "extracted_at": "2025-08-26T14:17:18.109571",
  "extraction_date": "2025-08-26"
}
```

### BigQuery Schema

DLT automatically infers and creates the BigQuery schema. Key characteristics:

**Table:** `{project}.bronze.dog_breeds`

**Column Types:**
- `id`: INTEGER
- `name`: STRING
- `breed_group`: STRING (nullable)
- `bred_for`: STRING (nullable)
- `life_span`: STRING
- `temperament`: STRING (nullable)
- `origin`: STRING (nullable)
- `reference_image_id`: STRING
- `weight`: RECORD (nested: imperial STRING, metric STRING)
- `height`: RECORD (nested: imperial STRING, metric STRING) 
- `extracted_at`: TIMESTAMP
- `extraction_date`: STRING (ISO date format)
- `_dlt_id`: STRING (DLT unique row identifier)
- `_dlt_load_id`: STRING (DLT load batch identifier)

**Write Mode:** REPLACE (full table refresh each run)

## Streamlit Assistant Behavior

### Overview
- The Finder page (`frontend/finder.py`) offers a conversational assistant grounded in the current filtered dataset.
- It streams responses from OpenAI when `OPENAI_API_KEY` is present; otherwise falls back to a heuristic recommender.
- The assistant sees a compact, clipped excerpt of the dataset (breed, group, size, avg_weight_kg, avg_lifespan_years, family_suitability, temperament traits).

### Secrets
- `st.secrets["gcp_service_account"]`: required BigQuery service account JSON
- `st.secrets["OPENAI_API_KEY"]`: optional; enables streaming responses via OpenAI

### Quotas and Fallbacks
- On insufficient OpenAI quota, the UI displays a warning and returns deterministic heuristic suggestions using the same dataset context.
- The heuristic favors user-stated size, apartment suitability, family friendliness, activity/calm preferences, guard traits, and longer lifespan.

### Dataset Configuration
- The Streamlit app points at a single dataset prefix via `PROJECT_DATASET` in `streamlit_app.py`.
- Adjust this to your environment: e.g., `...dog_explorer_dev_marts_core` for development.

## Error Handling

### HTTP Function Errors

The Cloud Function returns appropriate HTTP status codes:

- **200 OK**: Successful pipeline execution
- **500 Internal Server Error**: Pipeline failure

### Pipeline Errors

Common error scenarios and handling:

#### API Request Failures
```python
except requests.exceptions.RequestException as e:
    print(f"Error fetching data from Dog API: {e}")
    raise
```

**Causes:**
- Network connectivity issues
- TheDogAPI service downtime
- Request timeout
- Invalid API endpoint

#### DLT Pipeline Failures
```python
except Exception as e:
    print(f"Pipeline failed: {str(e)}")
    return {"status": "error", "message": f"Pipeline failed: {str(e)}"}
```

**Causes:**
- BigQuery authentication issues
- BigQuery quota exceeded
- Schema validation failures
- Network issues during data loading

### Monitoring and Observability

#### Logging Strategy

**Info Level Logs:**
- Successful data extraction: `"Successfully fetched {count} dog breeds"`
- Raw data storage: `"Raw data saved to Cloud Storage for date: {date}"`
- Pipeline completion: `"Pipeline completed successfully!"`

**Error Level Logs:**
- API failures: `"Error fetching data from Dog API: {error}"`
- Pipeline failures: `"Pipeline failed: {error}"`

#### Health Check

To verify pipeline functionality:

```bash
# Local execution test
python main.py

# Cloud Function test
curl -X POST https://{region}-{project}.cloudfunctions.net/dog-pipeline-handler
```

Expected successful response includes:
- `status: "success"`
- `message`: Contains "loaded successfully"
- `load_info`: Contains DLT execution details

## Usage Examples

### Local Development

```python
from dog_api_pipeline import main

# Execute pipeline locally
result = main()
print(result)
```

### Cloud Function Deployment

```yaml
# cloudfunctions/function.yaml
name: dog-pipeline-handler
runtime: python311
entry_point: dog_pipeline_handler
source: .
environment_variables:
  GOOGLE_CLOUD_PROJECT: your-project-id
```

### Programmatic Usage

```python
from dog_api_pipeline import fetch_dog_breeds, load_to_bigquery

# Extract data only
breeds = list(fetch_dog_breeds())
print(f"Extracted {len(breeds)} breeds")

# Full pipeline execution  
load_info = load_to_bigquery()
print(f"Pipeline result: {load_info}")
```

## Rate Limits and Quotas

### TheDogAPI Limits
- **Requests**: Not explicitly documented (appears unlimited for public API)
- **Data Volume**: 172 breeds per request (small dataset)
- **Recommendation**: Implement exponential backoff for production use

### Google Cloud Limits
- **Cloud Functions**: 540 second timeout (adequate for current volume)
- **BigQuery**: Well within quotas for 172 records
- **Cloud Storage**: No practical limits for current volume

### Recommended Production Enhancements
- Implement request retry logic with exponential backoff
- Add rate limiting to respect API quotas
- Monitor BigQuery slot usage for larger datasets
- Implement circuit breaker pattern for API failures

---

## dbt Analytics Layer Data Models

### Overview

The analytics layer transforms raw bronze data into business-ready models using dbt. The architecture follows a three-layer approach:

1. **Bronze Layer**: Raw data from ETL pipeline (`bronze.dog_breeds`)
2. **Silver Layer (Staging)**: Cleaned and normalized data (`stg_dog_breeds`)  
3. **Gold Layer (Marts)**: Business-ready analytical models

### Data Model Lineage

```
bronze.dog_breeds → stg_dog_breeds → ┌─ dim_breeds
                                   ├─ fct_breed_metrics  
                                   └─ dim_temperament
```

### Silver Layer (Staging Models)

#### `stg_dog_breeds`
**Purpose**: Staging table with cleaned and normalized dog breed data from TheDogAPI, featuring parsed measurement ranges, standardized names, and data quality flags for downstream processing

**Schema:**
```sql
breed_id                    INT64      -- Unique breed identifier
breed_name                  STRING     -- Standardized breed name  
extracted_at                TIMESTAMP  -- Data extraction timestamp
extraction_date             DATE       -- Date of extraction
bred_for                    STRING     -- Original breed purpose
breed_group                 STRING     -- AKC breed group classification
origin                      STRING     -- Country/region of origin
country_code                STRING     -- ISO country code

-- Parsed weight ranges (Imperial)
weight_min_lbs              FLOAT64    -- Minimum weight in pounds
weight_max_lbs              FLOAT64    -- Maximum weight in pounds

-- Parsed weight ranges (Metric)  
weight_min_kg               FLOAT64    -- Minimum weight in kilograms
weight_max_kg               FLOAT64    -- Maximum weight in kilograms

-- Parsed height ranges (Imperial)
height_min_inches           FLOAT64    -- Minimum height in inches
height_max_inches           FLOAT64    -- Maximum height in inches

-- Parsed height ranges (Metric)
height_min_cm               FLOAT64    -- Minimum height in centimeters
height_max_cm               FLOAT64    -- Maximum height in centimeters

-- Parsed lifespan ranges
life_span_min_years         INT64      -- Minimum lifespan in years
life_span_max_years         INT64      -- Maximum lifespan in years

-- Temperament and additional data
temperament_raw             STRING     -- Comma-separated temperament traits
description                 STRING     -- Detailed breed description
history                     STRING     -- Historical breed information
reference_image_id          STRING     -- TheDogAPI image reference

-- Derived classifications
size_category               STRING     -- Weight-based size classification
has_weight_data             BOOL       -- Weight data availability flag
has_height_data             BOOL       -- Height data availability flag
has_lifespan_data           BOOL       -- Lifespan data availability flag
has_temperament_data        BOOL       -- Temperament data availability flag
```

**Key Features:**
- Intelligent range parsing (e.g., "22 - 25 pounds" → min/max columns)
- Data quality flags for missing information
- Size categorization based on weight ranges
- Edge case handling for malformed data

### Gold Layer (Mart Models)

#### `dim_breeds` (Master Breed Dimension)
**Purpose**: Master dimension table containing comprehensive breed information with derived characteristics including size categories, longevity classifications, and inferred activity levels based on breed group analysis

**Schema:**
```sql
-- Primary key
breed_id                    INT64      -- Unique breed identifier (PK)

-- Basic breed information  
breed_name                  STRING     -- Breed name
breed_group                 STRING     -- AKC breed group
bred_for                    STRING     -- Original purpose
origin                      STRING     -- Country/region of origin
country_code                STRING     -- ISO country code

-- Physical characteristics (averages)
size_category               STRING     -- Size classification
avg_weight_lbs              FLOAT64    -- Average weight in pounds
avg_weight_kg               FLOAT64    -- Average weight in kilograms
avg_height_inches           FLOAT64    -- Average height in inches
avg_height_cm               FLOAT64    -- Average height in centimeters
avg_life_span_years         FLOAT64    -- Average lifespan in years

-- Temperament analysis
temperament_raw             STRING     -- Original temperament string
temperament_trait_count     INT64      -- Number of temperament traits

-- Derived business classifications
longevity_category          STRING     -- Lifespan classification
inferred_activity_level     STRING     -- Activity level inference
family_friendliness         STRING     -- Family suitability category

-- Data quality indicators
has_weight_data             BOOL       -- Weight data availability
has_height_data             BOOL       -- Height data availability  
has_lifespan_data           BOOL       -- Lifespan data availability
has_temperament_data        BOOL       -- Temperament data availability
data_completeness_score     INT64      -- Overall completeness (0-4)

-- Additional information
description                 STRING     -- Breed description
history                     STRING     -- Historical information
reference_image_id          STRING     -- Image reference
extracted_at                TIMESTAMP  -- Data extraction timestamp
extraction_date             DATE       -- Extraction date
```

**Business Classifications:**
- `longevity_category`: Long-lived, Average lifespan, Moderate lifespan, Short-lived
- `inferred_activity_level`: High, Medium-High, Medium, Low-Medium, Unknown
- `family_friendliness`: Family-Friendly, Protective/Guardian, Moderate, Unknown

#### `fct_breed_metrics` (Physical Measurements Fact)
**Purpose**: Fact table focused on measurable breed characteristics including weight, height, and lifespan metrics with calculated averages, ranges, and derived ratios for analytical insights

**Schema:**
```sql
-- Primary/Foreign keys
breed_id                    INT64      -- Breed identifier (FK to dim_breeds)
breed_name                  STRING     -- Breed name for reference

-- Weight metrics (Imperial)
weight_min_lbs              FLOAT64    -- Minimum weight in pounds
weight_max_lbs              FLOAT64    -- Maximum weight in pounds  
weight_range_lbs            FLOAT64    -- Weight range (max - min)
avg_weight_lbs              FLOAT64    -- Average weight

-- Weight metrics (Metric)
weight_min_kg               FLOAT64    -- Minimum weight in kg
weight_max_kg               FLOAT64    -- Maximum weight in kg
weight_range_kg             FLOAT64    -- Weight range in kg
avg_weight_kg               FLOAT64    -- Average weight in kg

-- Height metrics (Imperial)
height_min_inches           FLOAT64    -- Minimum height in inches
height_max_inches           FLOAT64    -- Maximum height in inches
height_range_inches         FLOAT64    -- Height range
avg_height_inches           FLOAT64    -- Average height

-- Height metrics (Metric)  
height_min_cm               FLOAT64    -- Minimum height in cm
height_max_cm               FLOAT64    -- Maximum height in cm
height_range_cm             FLOAT64    -- Height range in cm
avg_height_cm               FLOAT64    -- Average height in cm

-- Lifespan metrics
life_span_min_years         INT64      -- Minimum lifespan
life_span_max_years         INT64      -- Maximum lifespan
life_span_range_years       INT64      -- Lifespan range
avg_life_span_years         FLOAT64    -- Average lifespan

-- Calculated ratios and analysis
weight_height_ratio_imperial FLOAT64   -- Weight/height ratio (BMI-like)
weight_height_ratio_metric  FLOAT64    -- Metric weight/height ratio

-- Derived classifications
build_type                  STRING     -- Physical build classification
weight_consistency          STRING     -- Weight variation assessment
height_consistency          STRING     -- Height variation assessment
lifespan_predictability     STRING     -- Lifespan variation assessment

-- Data quality flags
has_weight_data             BOOL       -- Weight data availability
has_height_data             BOOL       -- Height data availability
has_lifespan_data           BOOL       -- Lifespan data availability
metrics_completeness_score  FLOAT64    -- Completeness score (0-1)

-- Metadata
extracted_at                TIMESTAMP  -- Extraction timestamp
extraction_date             DATE       -- Extraction date
```

**Derived Classifications:**
- `build_type`: Heavy Build, Sturdy Build, Balanced Build, Lean Build, Very Lean Build
- `weight_consistency`: Consistent Size, Moderate Variation, High Variation
- `height_consistency`: Consistent Size, Moderate Variation, High Variation
- `lifespan_predictability`: Predictable Lifespan, Moderate Variation, High Variation

#### `dim_temperament` (Behavioral Analysis Dimension)
**Purpose**: Dimension table analyzing temperament patterns through normalized scoring of behavioral characteristics, providing insights into family suitability, training difficulty, and primary temperament categories

**Schema:**
```sql
-- Primary/Foreign keys
breed_id                    INT64      -- Breed identifier (FK to dim_breeds)
breed_name                  STRING     -- Breed name for reference

-- Raw temperament data
temperament_raw             STRING     -- Original temperament string
total_traits                INT64      -- Total number of traits
trait_array                 ARRAY<STRING> -- Individual traits as array

-- Normalized behavioral scores (0-1 scale)
social_score                FLOAT64    -- Social/friendly temperament
energy_score                FLOAT64    -- Energy level temperament  
intelligence_score          FLOAT64    -- Intelligence/trainability
protective_score            FLOAT64    -- Protective/guardian traits
independent_score           FLOAT64    -- Independence/stubbornness
calm_score                  FLOAT64    -- Calm/gentle temperament
family_friendliness_score   FLOAT64    -- Family suitability score
working_score               FLOAT64    -- Working dog traits

-- Raw trait counts
social_traits_count         INT64      -- Count of social traits
energy_traits_count         INT64      -- Count of energy traits
intelligence_traits_count   INT64      -- Count of intelligence traits
protective_traits_count     INT64      -- Count of protective traits
independent_traits_count    INT64      -- Count of independent traits
calm_traits_count           INT64      -- Count of calm traits
family_friendly_traits      INT64      -- Count of family-friendly traits
working_traits_count        INT64      -- Count of working traits

-- Business classifications
primary_temperament_category STRING    -- Primary temperament classification
temperament_complexity      STRING    -- Complexity of temperament profile
family_suitability          STRING    -- Overall family suitability
training_difficulty         STRING    -- Estimated training difficulty
```

**Temperament Classifications:**
- `primary_temperament_category`: Social/Friendly, High-Energy/Active, Intelligent/Trainable, Protective/Guardian, Independent/Strong-Willed, Calm/Gentle, Unclassified
- `temperament_complexity`: Complex, Moderate, Simple, Minimal
- `family_suitability`: Excellent for Families, Good for Families, Moderate for Families, Good Guard Dog, Needs Experienced Owner
- `training_difficulty`: Easy to Train, Moderate to Train, Challenging to Train, Very Challenging to Train

### Advanced Analytics Features

#### Range Parsing Logic
The staging model includes intelligent parsing for measurement ranges:

```sql
-- Weight parsing example
case when weight__imperial like '%-%' then 
    cast(trim(split(weight__imperial, ' - ')[offset(0)]) as float64)
when weight__imperial = 'NaN' then null
when regexp_contains(weight__imperial, r'^up - \d+$') then 0.0
else cast(trim(weight__imperial) as float64)
end as weight_min_lbs
```

#### Temperament Scoring Algorithm
Behavioral traits are normalized using UNNEST operations:

```sql
-- Temperament trait normalization
temperament_traits as (
    select
        breed_id,
        breed_name,
        trim(trait) as temperament_trait
    from staging_data,
    unnest(split(temperament_raw, ', ')) as trait
    where temperament_raw is not null
)
```

#### Business Logic Examples

**Family Suitability Scoring:**
```sql
case 
    when family_friendliness_score >= 0.4 and calm_score >= 0.2 
    then 'Excellent for Families'
    when family_friendliness_score >= 0.3 or calm_score >= 0.3 
    then 'Good for Families'
    when family_friendliness_score >= 0.2 
    then 'Moderate for Families'
    when protective_score >= 0.4 and independent_score <= 0.3 
    then 'Good Guard Dog'
    else 'Needs Experienced Owner'
end as family_suitability
```

### Data Quality & Testing Framework

#### Schema Tests (20+ tests)
- **Uniqueness**: Primary keys and business keys
- **Referential Integrity**: Foreign key relationships  
- **Range Validation**: Physical measurements within bounds
- **Accepted Values**: Categorical data validation

#### Custom Tests (3 tests)
1. **Weight-Height Ratio Validation**: Ensures realistic physical measurements
2. **Temperament Score Validation**: Validates behavioral scoring consistency
3. **Cross-Model Consistency**: Maintains referential integrity across marts

#### Data Quality Metrics
- **Completeness Scores**: Track missing data across key metrics
- **Quality Flags**: Boolean indicators for data availability
- **Range Validation**: Ensure measurements are within realistic bounds

### Usage Examples

#### Family-Friendly Breeds Analysis
```sql
-- Find family-friendly breeds under 50 lbs
SELECT 
    d.breed_name,
    d.avg_weight_lbs,
    d.size_category,
    d.avg_life_span_years,
    t.family_friendliness_score,
    t.training_difficulty,
    t.primary_temperament_category
FROM {{ ref('dim_breeds') }} d
JOIN {{ ref('dim_temperament') }} t USING (breed_id)
WHERE d.avg_weight_lbs <= 50
  AND t.family_suitability = 'Excellent for Families'
ORDER BY d.avg_weight_lbs;
```

#### Physical Characteristics Analysis  
```sql
SELECT 
    build_type,
    COUNT(*) as breed_count,
    AVG(avg_weight_lbs) as avg_weight,
    AVG(avg_height_inches) as avg_height,
    AVG(avg_life_span_years) as avg_lifespan
FROM {{ ref('fct_breed_metrics') }}
WHERE build_type IS NOT NULL
GROUP BY build_type
ORDER BY avg_weight DESC;
```

#### Temperament Complexity Analysis
```sql
-- Compare temperament complexity by breed group
SELECT 
    d.breed_group,
    AVG(t.total_traits) as avg_temperament_complexity,
    AVG(t.intelligence_score) as avg_intelligence,
    AVG(t.family_friendliness_score) as avg_family_score,
    COUNT(*) as breed_count
FROM {{ ref('dim_breeds') }} d
JOIN {{ ref('dim_temperament') }} t USING (breed_id)
WHERE d.has_temperament_data = true
GROUP BY d.breed_group
ORDER BY avg_temperament_complexity DESC;
```

### Model Materialization Strategy

- **Staging Models**: Views (fast development iteration)
- **Mart Models**: Tables (optimized for analytical performance)
- **Schema Separation**: staging, marts_core schemas for clear organization
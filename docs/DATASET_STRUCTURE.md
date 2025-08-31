# BigQuery Dataset Structure Reference

## Quick Reference

| Layer | Dataset | Purpose | Materialization | Tables |
|-------|---------|---------|----------------|---------|
| **Bronze** | `bronze` | Raw data | Table | `dog_breeds` |
| **Analytics (dev)** | `dog_explorer_dev` | Views/tables for models | View/Table | `stg_dog_breeds`, `dim_breeds`, `dim_temperament`, `fct_breed_metrics` |
| **Analytics (prod)** | `dog_explorer` | Views/tables for models | View/Table | `stg_dog_breeds`, `dim_breeds`, `dim_temperament`, `fct_breed_metrics` |
| **Tests (dev)** | `dog_explorer_dev_tests` | Persistent test artifacts | Tables | dbt test result tables when `--store-failures` |
| **Tests (prod)** | `dog_explorer_tests` | Persistent test artifacts | Tables | dbt test result tables when `--store-failures` |

## Environment Mapping

### Development (`--target dev`)
- Models dataset: `dog_explorer_dev`
- Tests dataset: `dog_explorer_dev_tests`

### Production (`--target prod`)
- Models dataset: `dog_explorer`
- Tests dataset: `dog_explorer_tests`

## Data Flow Summary

```
bronze.dog_breeds (Raw API data)
    ↓
dog_explorer_{env}.stg_dog_breeds (Cleaned & parsed)
    ↓
dog_explorer_{env}.dim_breeds + dim_temperament + fct_breed_metrics (Business-ready)
```

## Key Changes Made

1. **Single dataset per environment** for models using a `generate_schema_name` macro that returns `target.schema`.
2. **Separate tests dataset** via the same macro when `node.resource_type == 'test'`, writing to `<target.schema>_tests`.
3. **Removed folder-level +schema overrides** to prevent dataset proliferation (`staging`, `marts`, `marts_core`).
4. **Stable bronze source** remains `bronze` across environments.

## Next Steps

1. Build dev: `DBT_PROFILES_DIR=.dbt uv run dbt build --target dev`
2. Build prod: `DBT_PROFILES_DIR=.dbt uv run dbt build --target prod`
3. Verify models in `dog_explorer_dev`/`dog_explorer` and tests in `_tests` datasets.
4. Drop any legacy datasets that are no longer in use.

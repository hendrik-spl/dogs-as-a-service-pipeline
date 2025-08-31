{{ config(
    materialized='view'
) }}

with source_data as (
    select * from {{ source('bronze', 'dog_breeds') }}
),

parsed_data as (
    select
        -- Primary identifiers
        cast(id as int64) as breed_id,
        trim(name) as breed_name,
        
        -- DLT metadata
        _dlt_load_id,
        _dlt_id,
        cast(extracted_at as timestamp) as extracted_at,
        cast(extraction_date as date) as extraction_date,
        
        -- Basic breed information  
        trim(bred_for) as bred_for,
        trim(breed_group) as breed_group,
        trim(origin) as origin,
        trim(country_code) as country_code,
        
        -- Parse weight ranges (imperial)
        case 
            when weight__imperial is null or trim(weight__imperial) = '' then null
            when weight__imperial = 'NaN' then null
            when regexp_contains(weight__imperial, r'^up - \d+$') then 0.0
            when regexp_contains(weight__imperial, r'^up – \d+$') then 0.0
            when weight__imperial like '%-%' or weight__imperial like '%–%' then 
                cast(trim(split(replace(weight__imperial, '–', '-'), ' - ')[offset(0)]) as float64)
            else cast(trim(weight__imperial) as float64)
        end as weight_min_lbs,
        
        case 
            when weight__imperial is null or trim(weight__imperial) = '' then null
            when weight__imperial = 'NaN' then null
            when regexp_contains(weight__imperial, r'^up - (\d+)$') then 
                cast(regexp_extract(weight__imperial, r'^up - (\d+)$') as float64)
            when regexp_contains(weight__imperial, r'^up – (\d+)$') then 
                cast(regexp_extract(weight__imperial, r'^up – (\d+)$') as float64)
            when weight__imperial like '%-%' or weight__imperial like '%–%' then 
                cast(trim(split(replace(weight__imperial, '–', '-'), ' - ')[offset(1)]) as float64)
            else cast(trim(weight__imperial) as float64)
        end as weight_max_lbs,
        
        -- Parse weight ranges (metric)  
        case 
            when weight__metric is null or trim(weight__metric) = '' then null
            when weight__metric like '%-%' or weight__metric like '%–%' then 
                cast(trim(split(replace(weight__metric, '–', '-'), ' - ')[offset(0)]) as float64)
            when weight__metric = 'NaN' then null
            when regexp_contains(weight__metric, r'^NaN - \d+$') then null
            when regexp_contains(weight__metric, r'^NaN – \d+$') then null
            else cast(trim(weight__metric) as float64)
        end as weight_min_kg,
        
        case 
            when weight__metric is null or trim(weight__metric) = '' then null
            when weight__metric like '%-%' or weight__metric like '%–%' then 
                cast(trim(split(replace(weight__metric, '–', '-'), ' - ')[offset(1)]) as float64)
            when weight__metric = 'NaN' then null
            when regexp_contains(weight__metric, r'^NaN - (\d+)$') then 
                cast(regexp_extract(weight__metric, r'^NaN - (\d+)$') as float64)
            when regexp_contains(weight__metric, r'^NaN – (\d+)$') then 
                cast(regexp_extract(weight__metric, r'^NaN – (\d+)$') as float64)
            else cast(trim(weight__metric) as float64)
        end as weight_max_kg,
        
        -- Parse height ranges (imperial)
        case 
            when height__imperial is null or trim(height__imperial) = '' then null
            when height__imperial like '%-%' or height__imperial like '%–%' then 
                cast(trim(split(replace(height__imperial, '–', '-'), ' - ')[offset(0)]) as float64)
            else cast(trim(height__imperial) as float64)
        end as height_min_inches,
        
        case 
            when height__imperial is null or trim(height__imperial) = '' then null
            when height__imperial like '%-%' or height__imperial like '%–%' then 
                cast(trim(split(replace(height__imperial, '–', '-'), ' - ')[offset(1)]) as float64)
            else cast(trim(height__imperial) as float64)
        end as height_max_inches,
        
        -- Parse height ranges (metric)
        case 
            when height__metric is null or trim(height__metric) = '' then null
            when height__metric like '%-%' or height__metric like '%–%' then 
                cast(trim(split(replace(height__metric, '–', '-'), ' - ')[offset(0)]) as float64)
            else cast(trim(height__metric) as float64)
        end as height_min_cm,
        
        case 
            when height__metric is null or trim(height__metric) = '' then null
            when height__metric like '%-%' or height__metric like '%–%' then 
                cast(trim(split(replace(height__metric, '–', '-'), ' - ')[offset(1)]) as float64)
            else cast(trim(height__metric) as float64)
        end as height_max_cm,
        
        -- Parse life span ranges
        case 
            when life_span is null or trim(life_span) = '' then null
            when life_span like '%-%' or life_span like '%–%' then 
                cast(regexp_extract(replace(life_span, '–', '-'), r'^(\d+)') as int64)
            when regexp_contains(life_span, r'^\d+') then
                cast(regexp_extract(life_span, r'^(\d+)') as int64)
            else null
        end as life_span_min_years,
        
        case 
            when life_span is null or trim(life_span) = '' then null
            when life_span like '%-%' or life_span like '%–%' then 
                cast(regexp_extract(replace(life_span, '–', '-'), r'(\d+) years?') as int64)
            when regexp_contains(life_span, r'^\d+') then
                cast(regexp_extract(life_span, r'^(\d+)') as int64)
            else null
        end as life_span_max_years,
        
        -- Clean temperament data
        case 
            when temperament is null or trim(temperament) = '' then null
            else trim(temperament)
        end as temperament_raw,
        
        -- Additional fields
        trim(description) as description,
        trim(history) as history,
        trim(reference_image_id) as reference_image_id,
        
        -- Weight classification
        case 
            when weight__imperial is null or trim(weight__imperial) = '' then null
            when weight__imperial = 'NaN' then null
            when regexp_contains(weight__imperial, r'^up - \d+$') or regexp_contains(weight__imperial, r'^up – \d+$') then 'Very Small'
            when cast(coalesce(
                case 
                    when weight__imperial like '%-%' or weight__imperial like '%–%' then 
                        case 
                            when regexp_contains(weight__imperial, r'^up - (\d+)$') then 
                                regexp_extract(weight__imperial, r'^up - (\d+)$')
                            when regexp_contains(weight__imperial, r'^up – (\d+)$') then 
                                regexp_extract(weight__imperial, r'^up – (\d+)$')
                            else trim(split(replace(weight__imperial, '–', '-'), ' - ')[offset(1)])
                        end
                    else weight__imperial 
                end, '0'
            ) as float64) <= 25 then 'Small'
            when cast(coalesce(
                case 
                    when weight__imperial like '%-%' or weight__imperial like '%–%' then 
                        case 
                            when regexp_contains(weight__imperial, r'^up - (\d+)$') then 
                                regexp_extract(weight__imperial, r'^up - (\d+)$')
                            when regexp_contains(weight__imperial, r'^up – (\d+)$') then 
                                regexp_extract(weight__imperial, r'^up – (\d+)$')
                            else trim(split(replace(weight__imperial, '–', '-'), ' - ')[offset(1)])
                        end
                    else weight__imperial 
                end, '0'
            ) as float64) <= 60 then 'Medium'
            when cast(coalesce(
                case 
                    when weight__imperial like '%-%' or weight__imperial like '%–%' then 
                        case 
                            when regexp_contains(weight__imperial, r'^up - (\d+)$') then 
                                regexp_extract(weight__imperial, r'^up - (\d+)$')
                            when regexp_contains(weight__imperial, r'^up – (\d+)$') then 
                                regexp_extract(weight__imperial, r'^up – (\d+)$')
                            else trim(split(replace(weight__imperial, '–', '-'), ' - ')[offset(1)])
                        end
                    else weight__imperial 
                end, '0'
            ) as float64) <= 90 then 'Large'
            else 'Extra Large'
        end as size_category,
        
        -- Data quality flags
        case when weight__imperial is null or trim(weight__imperial) = '' or weight__imperial = 'NaN' 
             then false else true end as has_weight_data,
        case when height__imperial is null or trim(height__imperial) = '' 
             then false else true end as has_height_data,
        case when life_span is null or trim(life_span) = '' 
             then false else true end as has_lifespan_data,
        case when temperament is null or trim(temperament) = '' 
             then false else true end as has_temperament_data
             
    from source_data
)

select * from parsed_data
where breed_id is not null
  and breed_name is not null
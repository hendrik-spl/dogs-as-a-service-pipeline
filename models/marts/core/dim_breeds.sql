{{ config(materialized='table') }}

with staging_data as (
    select * from {{ ref('stg_dog_breeds') }}
),

breed_dimensions as (
    select
        -- Primary key
        breed_id,
        
        -- Basic breed information
        breed_name,
        breed_group,
        bred_for,
        
        -- Origin information
        origin,
        country_code,
        
        -- Physical characteristics
        size_category,
        
        -- Average measurements (using midpoint of ranges where available)
        case 
            when weight_min_lbs is not null and weight_max_lbs is not null 
            then round((weight_min_lbs + weight_max_lbs) / 2.0, 1)
            when weight_max_lbs is not null then weight_max_lbs
            when weight_min_lbs is not null then weight_min_lbs
            else null
        end as avg_weight_lbs,
        
        case 
            when weight_min_kg is not null and weight_max_kg is not null 
            then round((weight_min_kg + weight_max_kg) / 2.0, 1)
            when weight_max_kg is not null then weight_max_kg
            when weight_min_kg is not null then weight_min_kg
            else null
        end as avg_weight_kg,
        
        case 
            when height_min_inches is not null and height_max_inches is not null 
            then round((height_min_inches + height_max_inches) / 2.0, 1)
            when height_max_inches is not null then height_max_inches
            when height_min_inches is not null then height_min_inches
            else null
        end as avg_height_inches,
        
        case 
            when height_min_cm is not null and height_max_cm is not null 
            then round((height_min_cm + height_max_cm) / 2.0, 1)
            when height_max_cm is not null then height_max_cm
            when height_min_cm is not null then height_min_cm
            else null
        end as avg_height_cm,
        
        case 
            when life_span_min_years is not null and life_span_max_years is not null 
            then round((life_span_min_years + life_span_max_years) / 2.0, 1)
            when life_span_max_years is not null then life_span_max_years
            when life_span_min_years is not null then life_span_min_years
            else null
        end as avg_life_span_years,
        
        -- Temperament analysis
        temperament_raw,
        case 
            when temperament_raw is not null 
            then array_length(split(temperament_raw, ', '))
            else 0
        end as temperament_trait_count,
        
        -- Derived characteristics
        case
            when (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then round((life_span_min_years + life_span_max_years) / 2.0, 1)
                    when life_span_max_years is not null then life_span_max_years
                    when life_span_min_years is not null then life_span_min_years
                    else null
                end
            ) >= 14 then 'Long-lived'
            when (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then round((life_span_min_years + life_span_max_years) / 2.0, 1)
                    when life_span_max_years is not null then life_span_max_years
                    when life_span_min_years is not null then life_span_min_years
                    else null
                end
            ) >= 12 then 'Average lifespan'
            when (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then round((life_span_min_years + life_span_max_years) / 2.0, 1)
                    when life_span_max_years is not null then life_span_max_years
                    when life_span_min_years is not null then life_span_min_years
                    else null
                end
            ) >= 10 then 'Moderate lifespan'
            else 'Short-lived'
        end as longevity_category,
        
        -- Activity level inference (based on breed group and bred_for)
        case 
            when breed_group in ('Sporting', 'Herding') then 'High'
            when breed_group in ('Working', 'Terrier') then 'Medium-High'
            when breed_group in ('Hound') then 'Medium'
            when breed_group in ('Toy', 'Non-Sporting') then 'Low-Medium'
            else 'Unknown'
        end as inferred_activity_level,
        
        -- Family friendliness inference (based on temperament keywords)
        case 
            when temperament_raw is not null and (
                regexp_contains(lower(temperament_raw), r'friendly|gentle|patient|loving|affectionate|companionable|familial')
            ) then 'Family-Friendly'
            when temperament_raw is not null and (
                regexp_contains(lower(temperament_raw), r'protective|alert|watchful|territorial|dominant')
                and not regexp_contains(lower(temperament_raw), r'friendly|gentle|patient')
            ) then 'Protective/Guardian'
            when temperament_raw is not null then 'Moderate'
            else 'Unknown'
        end as family_friendliness,
        
        -- Additional breed information
        description,
        history,
        reference_image_id,
        
        -- Data quality indicators
        has_weight_data,
        has_height_data,
        has_lifespan_data,
        has_temperament_data,
        
        -- Data completeness score (0-4)
        cast(has_weight_data as int64) + 
        cast(has_height_data as int64) + 
        cast(has_lifespan_data as int64) + 
        cast(has_temperament_data as int64) as data_completeness_score,
        
        -- Metadata
        extracted_at,
        extraction_date
        
    from staging_data
)

select * from breed_dimensions
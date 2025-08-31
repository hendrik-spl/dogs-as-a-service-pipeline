{{ config(materialized='table') }}

with staging_data as (
    select * from {{ ref('stg_dog_breeds') }}
),

breed_metrics as (
    select
        -- Primary key
        breed_id,
        
        -- Foreign key to dimension
        breed_name,
        
        -- Weight metrics (imperial)
        weight_min_lbs,
        weight_max_lbs,
        case 
            when weight_min_lbs is not null and weight_max_lbs is not null 
            then weight_max_lbs - weight_min_lbs
            else null
        end as weight_range_lbs,
        
        -- Weight metrics (metric)
        weight_min_kg,
        weight_max_kg,
        case 
            when weight_min_kg is not null and weight_max_kg is not null 
            then weight_max_kg - weight_min_kg
            else null
        end as weight_range_kg,
        
        -- Height metrics (imperial)
        height_min_inches,
        height_max_inches,
        case 
            when height_min_inches is not null and height_max_inches is not null 
            then height_max_inches - height_min_inches
            else null
        end as height_range_inches,
        
        -- Height metrics (metric)
        height_min_cm,
        height_max_cm,
        case 
            when height_min_cm is not null and height_max_cm is not null 
            then height_max_cm - height_min_cm
            else null
        end as height_range_cm,
        
        -- Lifespan metrics
        life_span_min_years,
        life_span_max_years,
        case 
            when life_span_min_years is not null and life_span_max_years is not null 
            then life_span_max_years - life_span_min_years
            else null
        end as life_span_range_years,
        
        -- Calculated averages/midpoints
        case 
            when weight_min_lbs is not null and weight_max_lbs is not null 
            then (weight_min_lbs + weight_max_lbs) / 2.0
            when weight_max_lbs is not null then weight_max_lbs
            when weight_min_lbs is not null then weight_min_lbs
            else null
        end as avg_weight_lbs,
        
        case 
            when weight_min_kg is not null and weight_max_kg is not null 
            then (weight_min_kg + weight_max_kg) / 2.0
            when weight_max_kg is not null then weight_max_kg
            when weight_min_kg is not null then weight_min_kg
            else null
        end as avg_weight_kg,
        
        case 
            when height_min_inches is not null and height_max_inches is not null 
            then (height_min_inches + height_max_inches) / 2.0
            when height_max_inches is not null then height_max_inches
            when height_min_inches is not null then height_min_inches
            else null
        end as avg_height_inches,
        
        case 
            when height_min_cm is not null and height_max_cm is not null 
            then (height_min_cm + height_max_cm) / 2.0
            when height_max_cm is not null then height_max_cm
            when height_min_cm is not null then height_min_cm
            else null
        end as avg_height_cm,
        
        case 
            when life_span_min_years is not null and life_span_max_years is not null 
            then (life_span_min_years + life_span_max_years) / 2.0
            when life_span_max_years is not null then life_span_max_years
            when life_span_min_years is not null then life_span_min_years
            else null
        end as avg_life_span_years,
        
        -- Body Mass Index approximation (weight/height ratio indicators)
        case 
            when (
                case 
                    when weight_min_lbs is not null and weight_max_lbs is not null 
                    then (weight_min_lbs + weight_max_lbs) / 2.0
                    when weight_max_lbs is not null then weight_max_lbs
                    when weight_min_lbs is not null then weight_min_lbs
                    else null
                end
            ) is not null
            and (
                case 
                    when height_min_inches is not null and height_max_inches is not null 
                    then (height_min_inches + height_max_inches) / 2.0
                    when height_max_inches is not null then height_max_inches
                    when height_min_inches is not null then height_min_inches
                    else null
                end
            ) is not null
            and (
                case 
                    when height_min_inches is not null and height_max_inches is not null 
                    then (height_min_inches + height_max_inches) / 2.0
                    when height_max_inches is not null then height_max_inches
                    when height_min_inches is not null then height_min_inches
                    else null
                end
            ) > 0
            then round(
                (
                    case 
                        when weight_min_lbs is not null and weight_max_lbs is not null 
                        then (weight_min_lbs + weight_max_lbs) / 2.0
                        when weight_max_lbs is not null then weight_max_lbs
                        when weight_min_lbs is not null then weight_min_lbs
                        else null
                    end
                ) / power(
                    (
                        case 
                            when height_min_inches is not null and height_max_inches is not null 
                            then (height_min_inches + height_max_inches) / 2.0
                            when height_max_inches is not null then height_max_inches
                            when height_min_inches is not null then height_min_inches
                            else null
                        end
                    ), 1.5
                ), 2)
            else null
        end as weight_height_ratio_imperial,
        
        case 
            when (
                case 
                    when weight_min_kg is not null and weight_max_kg is not null 
                    then (weight_min_kg + weight_max_kg) / 2.0
                    when weight_max_kg is not null then weight_max_kg
                    when weight_min_kg is not null then weight_min_kg
                    else null
                end
            ) is not null
            and (
                case 
                    when height_min_cm is not null and height_max_cm is not null 
                    then (height_min_cm + height_max_cm) / 2.0
                    when height_max_cm is not null then height_max_cm
                    when height_min_cm is not null then height_min_cm
                    else null
                end
            ) is not null
            and (
                case 
                    when height_min_cm is not null and height_max_cm is not null 
                    then (height_min_cm + height_max_cm) / 2.0
                    when height_max_cm is not null then height_max_cm
                    when height_min_cm is not null then height_min_cm
                    else null
                end
            ) > 0
            then round(
                (
                    case 
                        when weight_min_kg is not null and weight_max_kg is not null 
                        then (weight_min_kg + weight_max_kg) / 2.0
                        when weight_max_kg is not null then weight_max_kg
                        when weight_min_kg is not null then weight_min_kg
                        else null
                    end
                ) / power(
                    (
                        case 
                            when height_min_cm is not null and height_max_cm is not null 
                            then (height_min_cm + height_max_cm) / 2.0
                            when height_max_cm is not null then height_max_cm
                            when height_min_cm is not null then height_min_cm
                            else null
                        end
                    )/100, 1.5
                ), 2)
            else null
        end as weight_height_ratio_metric,
        
        -- Physical proportion analysis
        case
            when (
                (
                    case 
                        when weight_min_lbs is not null and weight_max_lbs is not null 
                        then (weight_min_lbs + weight_max_lbs) / 2.0
                        when weight_max_lbs is not null then weight_max_lbs
                        when weight_min_lbs is not null then weight_min_lbs
                        else null
                    end
                ) / power(
                    (
                        case 
                            when height_min_inches is not null and height_max_inches is not null 
                            then (height_min_inches + height_max_inches) / 2.0
                            when height_max_inches is not null then height_max_inches
                            when height_min_inches is not null then height_min_inches
                            else null
                        end
                    ), 1.5
                )
            ) >= 15 then 'Heavy Build'
            when (
                (
                    case 
                        when weight_min_lbs is not null and weight_max_lbs is not null 
                        then (weight_min_lbs + weight_max_lbs) / 2.0
                        when weight_max_lbs is not null then weight_max_lbs
                        when weight_min_lbs is not null then weight_min_lbs
                        else null
                    end
                ) / power(
                    (
                        case 
                            when height_min_inches is not null and height_max_inches is not null 
                            then (height_min_inches + height_max_inches) / 2.0
                            when height_max_inches is not null then height_max_inches
                            when height_min_inches is not null then height_min_inches
                            else null
                        end
                    ), 1.5
                )
            ) >= 10 then 'Sturdy Build'
            when (
                (
                    case 
                        when weight_min_lbs is not null and weight_max_lbs is not null 
                        then (weight_min_lbs + weight_max_lbs) / 2.0
                        when weight_max_lbs is not null then weight_max_lbs
                        when weight_min_lbs is not null then weight_min_lbs
                        else null
                    end
                ) / power(
                    (
                        case 
                            when height_min_inches is not null and height_max_inches is not null 
                            then (height_min_inches + height_max_inches) / 2.0
                            when height_max_inches is not null then height_max_inches
                            when height_min_inches is not null then height_min_inches
                            else null
                        end
                    ), 1.5
                )
            ) >= 7 then 'Balanced Build'
            when (
                (
                    case 
                        when weight_min_lbs is not null and weight_max_lbs is not null 
                        then (weight_min_lbs + weight_max_lbs) / 2.0
                        when weight_max_lbs is not null then weight_max_lbs
                        when weight_min_lbs is not null then weight_min_lbs
                        else null
                    end
                ) / power(
                    (
                        case 
                            when height_min_inches is not null and height_max_inches is not null 
                            then (height_min_inches + height_max_inches) / 2.0
                            when height_max_inches is not null then height_max_inches
                            when height_min_inches is not null then height_min_inches
                            else null
                        end
                    ), 1.5
                )
            ) >= 4 then 'Lean Build'
            when (
                (
                    case 
                        when weight_min_lbs is not null and weight_max_lbs is not null 
                        then (weight_min_lbs + weight_max_lbs) / 2.0
                        when weight_max_lbs is not null then weight_max_lbs
                        when weight_min_lbs is not null then weight_min_lbs
                        else null
                    end
                ) / power(
                    (
                        case 
                            when height_min_inches is not null and height_max_inches is not null 
                            then (height_min_inches + height_max_inches) / 2.0
                            when height_max_inches is not null then height_max_inches
                            when height_min_inches is not null then height_min_inches
                            else null
                        end
                    ), 1.5
                )
            ) is not null then 'Very Lean Build'
            else null
        end as build_type,
        
        -- Size consistency indicators
        case 
            when (
                case 
                    when weight_min_lbs is not null and weight_max_lbs is not null 
                    then weight_max_lbs - weight_min_lbs
                    else null
                end
            ) is not null
            and (
                case 
                    when weight_min_lbs is not null and weight_max_lbs is not null 
                    then weight_max_lbs - weight_min_lbs
                    else null
                end
            ) <= 10 then 'Consistent Size'
            when (
                case 
                    when weight_min_lbs is not null and weight_max_lbs is not null 
                    then weight_max_lbs - weight_min_lbs
                    else null
                end
            ) is not null
            and (
                case 
                    when weight_min_lbs is not null and weight_max_lbs is not null 
                    then weight_max_lbs - weight_min_lbs
                    else null
                end
            ) <= 30 then 'Moderate Variation'
            when (
                case 
                    when weight_min_lbs is not null and weight_max_lbs is not null 
                    then weight_max_lbs - weight_min_lbs
                    else null
                end
            ) is not null then 'High Variation'
            else null
        end as weight_consistency,
        
        case 
            when (
                case 
                    when height_min_inches is not null and height_max_inches is not null 
                    then height_max_inches - height_min_inches
                    else null
                end
            ) is not null
            and (
                case 
                    when height_min_inches is not null and height_max_inches is not null 
                    then height_max_inches - height_min_inches
                    else null
                end
            ) <= 2 then 'Consistent Size'
            when (
                case 
                    when height_min_inches is not null and height_max_inches is not null 
                    then height_max_inches - height_min_inches
                    else null
                end
            ) is not null
            and (
                case 
                    when height_min_inches is not null and height_max_inches is not null 
                    then height_max_inches - height_min_inches
                    else null
                end
            ) <= 5 then 'Moderate Variation'
            when (
                case 
                    when height_min_inches is not null and height_max_inches is not null 
                    then height_max_inches - height_min_inches
                    else null
                end
            ) is not null then 'High Variation'
            else null
        end as height_consistency,
        
        -- Longevity metrics
        case 
            when (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then life_span_max_years - life_span_min_years
                    else null
                end
            ) is not null
            and (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then life_span_max_years - life_span_min_years
                    else null
                end
            ) <= 2 then 'Predictable Lifespan'
            when (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then life_span_max_years - life_span_min_years
                    else null
                end
            ) is not null
            and (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then life_span_max_years - life_span_min_years
                    else null
                end
            ) <= 4 then 'Moderate Variation'
            when (
                case 
                    when life_span_min_years is not null and life_span_max_years is not null 
                    then life_span_max_years - life_span_min_years
                    else null
                end
            ) is not null then 'High Variation'
            else null
        end as lifespan_predictability,
        
        -- Data quality flags
        has_weight_data,
        has_height_data,
        has_lifespan_data,
        
        -- Metric completeness (0-1)
        case 
            when has_weight_data and has_height_data and has_lifespan_data then 1.0
            when (cast(has_weight_data as int64) + cast(has_height_data as int64) + cast(has_lifespan_data as int64)) = 2 then 0.67
            when (cast(has_weight_data as int64) + cast(has_height_data as int64) + cast(has_lifespan_data as int64)) = 1 then 0.33
            else 0.0
        end as metrics_completeness_score,
        
        -- Metadata
        extracted_at,
        extraction_date
        
    from staging_data
)

select * from breed_metrics
where breed_id is not null
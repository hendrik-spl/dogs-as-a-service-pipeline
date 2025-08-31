-- Breed Insights Analysis
-- Demonstrates key analytical capabilities of the Dog Breed Explorer dbt project

-- 1. Family-Friendly Breeds by Size Category
SELECT 
    'Family-Friendly Breeds by Size' as analysis_type,
    d.size_category,
    COUNT(*) as breed_count,
    ROUND(AVG(t.family_friendliness_score), 2) as avg_family_score,
    STRING_AGG(d.breed_name, ', ' ORDER BY t.family_friendliness_score DESC LIMIT 3) as top_breeds
FROM {{ ref('dim_breeds') }} d
JOIN {{ ref('dim_temperament') }} t USING (breed_id)
WHERE t.family_suitability IN ('Excellent for Families', 'Good for Families')
GROUP BY d.size_category
ORDER BY avg_family_score DESC;

-- 2. Longevity by Breed Group
SELECT 
    'Longevity by Breed Group' as analysis_type,
    breed_group,
    COUNT(*) as breed_count,
    ROUND(AVG(avg_life_span_years), 1) as avg_lifespan,
    MIN(avg_life_span_years) as min_lifespan,
    MAX(avg_life_span_years) as max_lifespan
FROM {{ ref('dim_breeds') }}
WHERE avg_life_span_years IS NOT NULL
GROUP BY breed_group
ORDER BY avg_lifespan DESC;

-- 3. Training Difficulty vs Intelligence Score
SELECT 
    'Training Analysis' as analysis_type,
    training_difficulty,
    COUNT(*) as breed_count,
    ROUND(AVG(intelligence_score), 2) as avg_intelligence_score,
    ROUND(AVG(independent_score), 2) as avg_independence_score,
    STRING_AGG(breed_name, ', ' ORDER BY intelligence_score DESC LIMIT 2) as example_breeds
FROM {{ ref('dim_temperament') }}
GROUP BY training_difficulty
ORDER BY avg_intelligence_score DESC;

-- 4. Physical Characteristics by Build Type
SELECT 
    'Physical Characteristics' as analysis_type,
    build_type,
    COUNT(*) as breed_count,
    ROUND(AVG(avg_weight_lbs), 1) as avg_weight_lbs,
    ROUND(AVG(avg_height_inches), 1) as avg_height_inches,
    ROUND(AVG(weight_height_ratio_imperial), 2) as avg_weight_height_ratio
FROM {{ ref('fct_breed_metrics') }}
WHERE build_type IS NOT NULL
GROUP BY build_type
ORDER BY avg_weight_lbs DESC;

-- 5. Temperament Complexity Analysis
SELECT 
    'Temperament Complexity' as analysis_type,
    temperament_complexity,
    COUNT(*) as breed_count,
    ROUND(AVG(total_traits), 1) as avg_traits,
    ROUND(AVG(social_score + energy_score + intelligence_score + protective_score + independent_score + calm_score), 2) as avg_total_score,
    mode() WITHIN GROUP (ORDER BY primary_temperament_category) as most_common_category
FROM {{ ref('dim_temperament') }}
GROUP BY temperament_complexity
ORDER BY avg_traits DESC;

-- 6. Data Quality Summary
SELECT 
    'Data Quality Summary' as analysis_type,
    'Overall' as category,
    COUNT(*) as total_breeds,
    COUNTIF(has_weight_data) as breeds_with_weight,
    COUNTIF(has_height_data) as breeds_with_height,  
    COUNTIF(has_lifespan_data) as breeds_with_lifespan,
    COUNTIF(has_temperament_data) as breeds_with_temperament,
    ROUND(AVG(data_completeness_score), 2) as avg_completeness_score
FROM {{ ref('dim_breeds') }};
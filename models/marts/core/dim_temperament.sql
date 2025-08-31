{{ config(materialized='table') }}

with staging_data as (
    select * from {{ ref('stg_dog_breeds') }}
),

-- Normalize temperament traits into individual rows
temperament_traits as (
    select
        breed_id,
        breed_name,
        temperament_raw,
        trim(trait) as temperament_trait
    from staging_data,
    unnest(split(temperament_raw, ', ')) as trait
    where temperament_raw is not null
      and trim(trait) != ''
),

-- Aggregate temperament analysis by breed (including breeds without temperament data)
breed_temperament_analysis as (
    select
        s.breed_id,
        s.breed_name,
        s.temperament_raw,
        
        -- Count of traits (0 if no temperament data)
        coalesce(count(t.temperament_trait), 0) as total_traits,
        
        -- Collect all traits as array (empty array if no temperament data)
        case 
            when count(t.temperament_trait) > 0 then array_agg(t.temperament_trait order by t.temperament_trait)
            else []
        end as trait_array,
        
        -- Behavioral category analysis (0 if no temperament data)
        coalesce(countif(lower(t.temperament_trait) in (
            'affectionate', 'friendly', 'loving', 'companionable', 'gentle', 
            'sweet-tempered', 'sociable', 'outgoing', 'cheerful', 'happy', 'joyful'
        )), 0) as social_traits_count,
        
        coalesce(countif(lower(t.temperament_trait) in (
            'energetic', 'active', 'lively', 'playful', 'spirited', 'agile', 
            'boisterous', 'athletic', 'keen', 'eager'
        )), 0) as energy_traits_count,
        
        coalesce(countif(lower(t.temperament_trait) in (
            'intelligent', 'trainable', 'obedient', 'responsive', 'quick', 
            'clever', 'bright', 'alert'
        )), 0) as intelligence_traits_count,
        
        coalesce(countif(lower(t.temperament_trait) in (
            'protective', 'loyal', 'devoted', 'faithful', 'watchful', 
            'territorial', 'dominant', 'confident', 'fearless', 'brave', 'courageous'
        )), 0) as protective_traits_count,
        
        coalesce(countif(lower(t.temperament_trait) in (
            'independent', 'stubborn', 'strong willed', 'aloof', 'reserved', 
            'self-assured', 'proud', 'dignified'
        )), 0) as independent_traits_count,
        
        coalesce(countif(lower(t.temperament_trait) in (
            'calm', 'quiet', 'gentle', 'patient', 'steady', 'even tempered', 
            'composed', 'docile', 'stable'
        )), 0) as calm_traits_count,
        
        -- Family suitability indicators
        coalesce(countif(lower(t.temperament_trait) in (
            'affectionate', 'friendly', 'gentle', 'patient', 'loving', 
            'companionable', 'familial', 'trustworthy', 'tolerant'
        )), 0) as family_friendly_traits,
        
        -- Working dog traits
        coalesce(countif(lower(t.temperament_trait) in (
            'hardworking', 'dutiful', 'reliable', 'responsible', 'cooperative', 
            'eager', 'trainable', 'obedient'
        )), 0) as working_traits_count
        
    from staging_data s
    left join temperament_traits t on s.breed_id = t.breed_id
    group by s.breed_id, s.breed_name, s.temperament_raw
),

-- Create temperament profile scores
temperament_profiles as (
    select
        breed_id,
        breed_name,
        temperament_raw,
        total_traits,
        trait_array,
        
        -- Normalize scores to 0-1 scale
        case when total_traits > 0 then social_traits_count / total_traits else 0 end as social_score,
        case when total_traits > 0 then energy_traits_count / total_traits else 0 end as energy_score,
        case when total_traits > 0 then intelligence_traits_count / total_traits else 0 end as intelligence_score,
        case when total_traits > 0 then protective_traits_count / total_traits else 0 end as protective_score,
        case when total_traits > 0 then independent_traits_count / total_traits else 0 end as independent_score,
        case when total_traits > 0 then calm_traits_count / total_traits else 0 end as calm_score,
        case when total_traits > 0 then family_friendly_traits / total_traits else 0 end as family_friendliness_score,
        case when total_traits > 0 then working_traits_count / total_traits else 0 end as working_score,
        
        -- Raw counts
        social_traits_count,
        energy_traits_count,
        intelligence_traits_count,
        protective_traits_count,
        independent_traits_count,
        calm_traits_count,
        family_friendly_traits,
        working_traits_count
        
    from breed_temperament_analysis
),

-- Determine primary temperament category
final_temperament_dim as (
    select
        *,
        
        -- Primary temperament category (highest scoring category)
        case 
            when social_score >= energy_score 
                 and social_score >= intelligence_score 
                 and social_score >= protective_score 
                 and social_score >= independent_score 
                 and social_score >= calm_score 
                 and social_score > 0 then 'Social/Friendly'
            when energy_score >= intelligence_score 
                 and energy_score >= protective_score 
                 and energy_score >= independent_score 
                 and energy_score >= calm_score 
                 and energy_score > 0 then 'High-Energy/Active'
            when intelligence_score >= protective_score 
                 and intelligence_score >= independent_score 
                 and intelligence_score >= calm_score 
                 and intelligence_score > 0 then 'Intelligent/Trainable'
            when protective_score >= independent_score 
                 and protective_score >= calm_score 
                 and protective_score > 0 then 'Protective/Guardian'
            when independent_score >= calm_score 
                 and independent_score > 0 then 'Independent/Strong-Willed'
            when calm_score > 0 then 'Calm/Gentle'
            else 'Unclassified'
        end as primary_temperament_category,
        
        -- Temperament complexity (diversity of traits)
        case 
            when total_traits >= 8 then 'Complex'
            when total_traits >= 5 then 'Moderate'
            when total_traits >= 2 then 'Simple'
            else 'Minimal'
        end as temperament_complexity,
        
        -- Overall temperament rating for families
        case 
            when family_friendliness_score >= 0.4 and calm_score >= 0.2 then 'Excellent for Families'
            when family_friendliness_score >= 0.3 or calm_score >= 0.3 then 'Good for Families'
            when family_friendliness_score >= 0.2 then 'Moderate for Families'
            when protective_score >= 0.4 and independent_score <= 0.3 then 'Good Guard Dog'
            else 'Needs Experienced Owner'
        end as family_suitability,
        
        -- Training difficulty estimation
        case 
            when intelligence_score >= 0.3 and independent_score <= 0.2 then 'Easy to Train'
            when intelligence_score >= 0.2 and independent_score <= 0.3 then 'Moderate to Train'
            when intelligence_score >= 0.1 or independent_score <= 0.4 then 'Challenging to Train'
            else 'Very Challenging to Train'
        end as training_difficulty
        
    from temperament_profiles
)

select * from final_temperament_dim
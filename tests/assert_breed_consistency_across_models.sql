-- Custom test to ensure breed consistency across all mart models
-- All breeds should exist in dim_breeds and have corresponding records in fact/dimension tables

with breed_counts as (
    select 'dim_breeds' as table_name, count(*) as breed_count
    from {{ ref('dim_breeds') }}
    
    union all
    
    select 'fct_breed_metrics' as table_name, count(*) as breed_count
    from {{ ref('fct_breed_metrics') }}
    
    union all
    
    select 'dim_temperament' as table_name, count(*) as breed_count
    from {{ ref('dim_temperament') }}
),

-- Check for missing breeds in fact/dimension tables
missing_breeds as (
    select 
        'fct_breed_metrics' as missing_from_table,
        d.breed_id,
        d.breed_name
    from {{ ref('dim_breeds') }} d
    left join {{ ref('fct_breed_metrics') }} f on d.breed_id = f.breed_id
    where f.breed_id is null
    
    union all
    
    select 
        'dim_temperament' as missing_from_table,
        d.breed_id,
        d.breed_name
    from {{ ref('dim_breeds') }} d
    left join {{ ref('dim_temperament') }} t on d.breed_id = t.breed_id
    where t.breed_id is null
),

-- Check for orphaned records (breeds in fact/dim tables but not in dim_breeds)
orphaned_records as (
    select 
        'fct_breed_metrics' as orphaned_in_table,
        f.breed_id,
        f.breed_name
    from {{ ref('fct_breed_metrics') }} f
    left join {{ ref('dim_breeds') }} d on f.breed_id = d.breed_id
    where d.breed_id is null
    
    union all
    
    select 
        'dim_temperament' as orphaned_in_table,
        t.breed_id,
        t.breed_name
    from {{ ref('dim_temperament') }} t
    left join {{ ref('dim_breeds') }} d on t.breed_id = d.breed_id
    where d.breed_id is null
),

all_inconsistencies as (
    select 
        missing_from_table as issue_type,
        breed_id,
        breed_name,
        'missing_breed' as issue_description
    from missing_breeds
    
    union all
    
    select 
        orphaned_in_table as issue_type,
        breed_id,
        breed_name,
        'orphaned_record' as issue_description
    from orphaned_records
)

-- This test passes if there are no missing or orphaned breed records
select * from all_inconsistencies
# How to write a dbt model

## Optional comments: 
File-level comments (e.g., author, date, purpose, Jira ticket)

```
{{
  config(
    materialized='table', or 'view', 'incremental', 'ephemeral'
    unique_key='your_unique_key', for incremental models
    sort='timestamp_column', for performance on some warehouses
    dist='user_id', for distribution on some warehouses
    tags=['finance', 'daily']
  )
}}
```

## Import sources: 

Select from upstream sources or models. 

The principal applied here is readability.  By defining these source CTEs, we explicitly specify what sources are used, along with (re)naming the source properly to reflect their usages in the model.  

In addition to promote code readability, we should also pay attention to performance:

1. Specify only necessary columns used in the model.  Mordern data warehouse such as Snowflake uses column-wise storage, so select only necessary columns can significantly improve performance. 

1. Add filters.  CTEs are in-session temporary table in RAM, so it perform best if the result size is limited. Rule of thumb, if a CTE is more than millions of rows, we may want to alternatives, such as tables. 


If you need all the collumns and rows from the source table, the recommended way is to skip CTE and use it in the next step directly.  For documentation, you may add a comment at the end of this block.

```
with source_orders as (
    select 
        order_id,
        user_id,
        product_id,
        order_date,
        status,
        quantity,
        price,    
     from {{ source('ecommerce_source', 'orders') }}
     where order_date > {{ dateadd(datepart="day", interval=-1, from_date_or_timestamp="CURRENT_DATE()") }}
),

source_users as (

    select 
    user_id,
    user_name,
    registration_date
    from {{ source('another_source', 'users') }}

),

stg_products as (

    select 
    product_id,
    product_name
    from {{ ref('stg_products') }}

),

-- source table 'abc'    -- a comment to indicate there is adition table used for this model

```

## Define local CTEs 
Perform transformations, joins, and business logic by breaking down complex logic into smaller, understandable steps.

The principal applied here is modulemodularity.  A big, messy SQL statement with many joins and filters is error prone and hard to read.  In adition, it may improve performance by avoiding large joins. 

This step is where we rename some columns from the sources and give them more end user friendly names.

```
renamed_cast_orders as (

    select
        order_id as id,                          -- Renaming
        user_id,
        product_id,
        order_date::date as order_at_date,       -- Casting
        status as order_status,                  -- Renaming
        quantity,
        price,
        (quantity * price) as gross_revenue     -- Simple calculation
    from source_orders
    where status != 'cancelled'                 -- Early filtering

),

enriched_orders as (

    select
        ro.id as order_id,
        ro.user_id,
        su.user_name,                            Joining
        su.registration_date as user_registration_date,
        sp.product_name,
        ro.order_at_date,
        ro.order_status,
        ro.gross_revenue
        Add more transformations, window functions, etc.
    from renamed_cast_orders ro
    left join source_users su on ro.user_id = su.user_id
    left join stg_products sp on ro.product_id = sp.product_id

),

aggregated_by_user as (

    select
        user_id,
        user_name,
        min(order_at_date) as first_order_date,
        max(order_at_date) as last_order_date,
        count(distinct order_id) as total_orders,
        sum(gross_revenue) as total_revenue_from_user
    from enriched_orders
    group by 1, 2 Use positional grouping or explicit column names

)
```

## Aseemble the model
A final SELECT Statement to assemble all logical CTEs.
This should be a simple select of the columns you want in your final model.
Avoid complex transformations here; they should be in the logical CTEs.

```
select
    user_id,
    user_name,
    first_order_date,
    last_order_date,
    total_orders,
    total_revenue_from_user,
    current_timestamp as etl_loaded_at Add metadata column
from aggregated_by_user
Optional: Add a final WHERE clause or ORDER BY if absolutely necessary for the model's definition,
but generally, filtering and sorting for presentation are done in BI tools.
where total_orders > 0
order by total_revenue_from_user desc
```

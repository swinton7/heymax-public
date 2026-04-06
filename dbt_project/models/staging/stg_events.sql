{{
    config(
        materialized   = 'incremental',
        unique_key     = 'event_id',
        on_schema_change = 'fail'
    )
}}

/*
  stg_events — append-only incremental model.

  On first run: full load from CSV.
  On subsequent runs: only rows with event_time > the current max watermark
  are processed, preventing reprocessing of already-loaded events.

  Production note: swap read_csv_auto path for an S3 URI when moving to
  partitioned daily files (e.g. s3://bucket/events/date={{ ds }}/). The
  incremental filter then naturally aligns with daily partitions.
*/

with raw as (
    select *
    from read_csv_auto(
        '{{ var("data_path", "data") }}/event_stream.csv',
        types = {
            'miles_amount': 'DOUBLE',
            'event_time':   'VARCHAR'
        }
    )
),

cleaned as (
    select
        -- timestamps
        event_time::timestamptz                                 as event_time,
        event_time::date                                        as event_date,

        -- user
        trim(user_id)                                           as user_id,
        trim(lower(gender))                                     as gender,

        -- event
        trim(lower(event_type))                                 as event_type,
        trim(lower(transaction_category))                       as transaction_category,
        miles_amount,

        -- acquisition
        trim(lower(platform))                                   as platform,
        trim(lower(utm_source))                                 as utm_source,
        trim(upper(country))                                    as country,

        -- surrogate event key
        md5(
            coalesce(event_time::varchar, '') || '|' ||
            coalesce(user_id, '')             || '|' ||
            coalesce(event_type, '')
        )                                                       as event_id

    from raw
    where
        event_time is not null
        and user_id is not null
        and event_type is not null
        and platform is not null
        and country is not null
),

incremental_filter as (
    select *
    from cleaned
    {% if is_incremental() %}
    where event_time::timestamptz > (select max(event_time) from {{ this }})
    {% endif %}
)

select * from incremental_filter

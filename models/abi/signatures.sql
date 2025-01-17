{{ config(
        alias = 'signatures',
        partition_by = ['created_at_month'],
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['created_at', 'unique_signature_id'],
        post_hook='{{ expose_spells(\'["ethereum","bnb","avalanche_c","optimism","arbitrum","gnosis","polygon"]\',
                        "sector",
                        "abi",
                        \'["ilemi"]\') }}'
        )
}}

{% set chains = ['ethereum', 'optimism', 'arbitrum', 'avalanche_c', 'polygon', 'bnb', 'gnosis'] %}

WITH
    signatures as (
        {% for chain in chains %}

            SELECT
                *
                , concat(id, signature, type) as unique_signature_id
            FROM {{ source(chain, 'signatures') }}
            
            {% if is_incremental() %}
            WHERE created_at >= date_trunc("day", now() - interval '2 days')
            {% endif %}

            {% if not loop.last %}
            union all
            {% endif %}

        {% endfor %}
    )

    SELECT
    *
    FROM (
        SELECT 
            id
            , signature
            , abi
            , type
            , created_at
            , date_trunc('month',created_at) as created_at_month
            , unique_signature_id 
            , row_number() over (partition by unique_signature_id order by created_at desc) recency
        FROM signatures
    ) a
    WHERE recency = 1
    {% if is_incremental() %}
    AND NOT EXISTS (SELECT 1 FROM {{ this }} WHERE unique_signature_id = a.unique_signature_id)
    {% endif %}




SELECT
      m.data_source
    , coalesce(m.dispensing_date,cast('1900-01-01' as date)) as source_date
    , 'MEDICATION' AS table_name
    , 'Medication ID' as drill_down_key
    , coalesce(medication_id, 'NULL') AS drill_down_value
    , 'MEDICATION_ID' AS field_name
    , case when m.medication_id is not null then 'valid' else 'null' end as bucket_name
    , cast(null as TEXT) as invalid_reason
    , cast(medication_id as TEXT) as field_value
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from tuva_synthetic.input_layer.medication m
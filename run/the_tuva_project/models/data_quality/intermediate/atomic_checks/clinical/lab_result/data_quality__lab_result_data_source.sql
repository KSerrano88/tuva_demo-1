
  
    

        create or replace transient table tuva_synthetic.data_quality.lab_result_data_source
         as
        (


SELECT
      m.data_source
    , coalesce(m.result_date,cast('1900-01-01' as date)) as source_date
    , 'LAB_RESULT' AS table_name
    , 'Lab Result ID' as drill_down_key
    , coalesce(lab_result_id, 'NULL') AS drill_down_value
    , 'DATA_SOURCE' AS field_name
    , case when m.data_source is not null then 'valid' else 'null' end as bucket_name
    , cast(null as TEXT) as invalid_reason
    , cast(data_source as TEXT) as field_value
    , '2024-10-04 19:08:24.316902+00:00' as tuva_last_run
from tuva_synthetic.input_layer.lab_result m
        );
      
  
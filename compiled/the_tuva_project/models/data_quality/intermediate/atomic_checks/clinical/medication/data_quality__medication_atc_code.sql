


SELECT
      m.data_source
    , coalesce(m.dispensing_date,cast('1900-01-01' as date)) as source_date
    , 'MEDICATION' AS table_name
    , 'Medication ID' as drill_down_key
    , coalesce(medication_id, 'NULL') AS drill_down_value
    , 'ATC_CODE' as field_name
    , case when coalesce(term_1.atc_1_name,term_2.atc_2_name,term_3.atc_3_name,term_4.atc_4_name) is not null then 'valid'
           when m.atc_code is not null then 'invalid'
           else 'null'
    end as bucket_name
    , case when m.atc_code is not null and coalesce(term_1.atc_1_name,term_2.atc_2_name,term_3.atc_3_name,term_4.atc_4_name) is null
           then 'ATC Code does not join to Terminology rxnorm_to_atc table on any atc level'
           else null end as invalid_reason
    , cast(atc_code as TEXT) as field_value
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from tuva_synthetic.input_layer.medication m
left join tuva_synthetic.terminology.rxnorm_to_atc term_1 on m.atc_code = term_1.atc_1_name
left join tuva_synthetic.terminology.rxnorm_to_atc term_2 on m.atc_code = term_2.atc_2_name
left join tuva_synthetic.terminology.rxnorm_to_atc term_3 on m.atc_code = term_3.atc_3_name
left join tuva_synthetic.terminology.rxnorm_to_atc term_4 on m.atc_code = term_4.atc_4_name
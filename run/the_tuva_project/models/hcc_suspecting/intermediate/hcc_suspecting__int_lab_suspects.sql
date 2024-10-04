
  
    

        create or replace transient table tuva_synthetic.hcc_suspecting._int_lab_suspects
         as
        (

with egfr_labs as (

    select
          patient_id
        , data_source
        , code_type
        , code
        , result_date
        , result
    from tuva_synthetic.hcc_suspecting._int_prep_egfr_labs

)

, seed_hcc_descriptions as (

    select distinct
          hcc_code
        , hcc_description
    from tuva_synthetic.hcc_suspecting._value_set_hcc_descriptions

)

, billed_hccs as (

    select distinct
          patient_id
        , data_source
        , hcc_code
        , current_year_billed
    from tuva_synthetic.hcc_suspecting._int_patient_hcc_history

)

/* BEGIN CKD logic */

/*
    Find a patient’s two most recent eGFR lab results that are spaced by at
    least 90 days.
*/
, max_lab_date as (

    select
          patient_id
        , data_source
        , max(result_date) as max_result_date
    from egfr_labs
    group by
          patient_id
        , data_source

)

, lab_lookback as (

    select
          egfr_labs.patient_id
        , egfr_labs.data_source
        , max_lab_date.max_result_date
        , max(egfr_labs.result_date) as lookback_result_date
    from egfr_labs
        left join max_lab_date
        on egfr_labs.patient_id = max_lab_date.patient_id
        and egfr_labs.data_source = max_lab_date.data_source
    where egfr_labs.result_date <= 

    dateadd(
        day,
        -90,
        max_result_date
        )


    group by
          egfr_labs.patient_id
        , egfr_labs.data_source
        , max_lab_date.max_result_date

)

/*
    Take the highest eGFR result that occurred between the date range.
*/
, eligible_labs as (

    select
          egfr_labs.patient_id
        , egfr_labs.data_source
        , egfr_labs.code_type
        , egfr_labs.code
        , egfr_labs.result_date
        , egfr_labs.result
        , row_number() over (
            partition by
                  egfr_labs.patient_id
                , egfr_labs.data_source
            order by egfr_labs.result desc
        ) as row_num
    from egfr_labs
        inner join lab_lookback
        on egfr_labs.patient_id = lab_lookback.patient_id
        and egfr_labs.data_source = lab_lookback.data_source
    where egfr_labs.result_date >= lab_lookback.lookback_result_date

)

/*
    Assign a patient's kidney disease stage based on the highest eGFR based on
    the following range:

    CKD 3a: eGFR in the range (45-59)
    CKD 3b: eGFR in the range (30-44)
    CKD 4: eGFR in the range (15-29)
    CKD 5: eGFR in the range (0-14)
*/
, ckd_suspects as (

    select
          patient_id
        , data_source
        , code_type
        , code as lab_code
        , result_date
        , result
        , case
            when result between 0 and 14 then '326'
            when result between 15 and 29 then '327'
            when result between 30 and 44 then '328'
            when result between 45 and 59 then '329'
          end as hcc_code
        , 'eGFR (' || code || ') result ' || result || ' on ' || result_date as contributing_factor
    from eligible_labs
    where row_num = 1

)
/* END CKD logic */

, unioned as (

    select * from ckd_suspects

)

, add_billed_flag as (

    select
          unioned.patient_id
        , unioned.data_source
        , unioned.result_date
        , unioned.result
        , unioned.lab_code
        , unioned.hcc_code
        , unioned.contributing_factor
        , seed_hcc_descriptions.hcc_description
        , billed_hccs.current_year_billed
    from unioned
        inner join seed_hcc_descriptions
            on unioned.hcc_code = seed_hcc_descriptions.hcc_code
        left join billed_hccs
            on unioned.patient_id = billed_hccs.patient_id
            and unioned.data_source = billed_hccs.data_source
            and unioned.hcc_code = billed_hccs.hcc_code

)

, add_standard_fields as (

    select
          patient_id
        , data_source
        , result_date
        , result
        , lab_code
        , hcc_code
        , hcc_description
        , contributing_factor
        , current_year_billed
        , cast('Lab result suspect' as TEXT) as reason
        , result_date as suspect_date
    from add_billed_flag

)

, add_data_types as (

    select
          cast(patient_id as TEXT) as patient_id
        , cast(data_source as TEXT) as data_source
        , cast(result_date as date) as result_date
        , cast(result as numeric(28,6)) as result
        , cast(lab_code as TEXT) as lab_code
        , cast(hcc_code as TEXT) as hcc_code
        , cast(hcc_description as TEXT) as hcc_description
        
            , cast(current_year_billed as boolean) as current_year_billed
        
        , cast(reason as TEXT) as reason
        , cast(contributing_factor as TEXT) as contributing_factor
        , cast(suspect_date as date) as suspect_date
    from add_standard_fields

)

select
      patient_id
    , data_source
    , result_date
    , result
    , lab_code
    , hcc_code
    , hcc_description
    , current_year_billed
    , reason
    , contributing_factor
    , suspect_date
    , '2024-10-04 19:08:24.316902+00:00' as tuva_last_run
from add_data_types
        );
      
  
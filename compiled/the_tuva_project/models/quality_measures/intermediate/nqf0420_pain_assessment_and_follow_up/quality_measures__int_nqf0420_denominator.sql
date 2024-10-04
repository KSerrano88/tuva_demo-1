

with  __dbt__cte__quality_measures__stg_core__encounter as (


select
      patient_id
    , encounter_id
    , encounter_type
    , length_of_stay
    , encounter_start_date
    , encounter_end_date
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from tuva_synthetic.core.encounter


),  __dbt__cte__quality_measures__stg_core__procedure as (

select
      patient_id
    , encounter_id
    , procedure_date
    , source_code_type
    , source_code
    , normalized_code_type
    , normalized_code
    , modifier_1
    , modifier_2
    , modifier_3
    , modifier_4
    , modifier_5
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from tuva_synthetic.core.procedure
),  __dbt__cte__quality_measures__stg_medical_claim as (



select
         cast(null as TEXT ) as patient_id
        , cast(null as TEXT ) as claim_id
        , try_cast( null as date ) as claim_start_date
        , try_cast( null as date ) as claim_end_date
        , cast(null as TEXT ) as place_of_service_code
        , cast(null as TEXT ) as hcpcs_code
        , cast(null as TEXT ) as hcpcs_modifier_1
        , cast(null as TEXT ) as hcpcs_modifier_2
        , cast(null as TEXT ) as hcpcs_modifier_3
        , cast(null as TEXT ) as hcpcs_modifier_4
        , cast(null as TEXT ) as hcpcs_modifier_5
        , cast(null as TIMESTAMP ) as tuva_last_run
    limit 0
),  __dbt__cte__quality_measures__stg_core__patient as (

select
      patient_id
    , sex
    , birth_date
    , death_date
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from tuva_synthetic.core.patient
), visit_codes as (

    select
          code
        , code_system
    from tuva_synthetic.quality_measures._value_set_codes
    where lower(concept_name) in (
          'home healthcare services'
        , 'office visit'
        , 'encounter to document medications'
        , 'psychological and/or neuropsychological test administration'
    )

)

, visits_encounters as (

    select 
          patient_id
        , coalesce(encounter.encounter_start_date, encounter.encounter_end_date) as min_date
        , coalesce(encounter.encounter_end_date, encounter.encounter_start_date) as max_date
    from __dbt__cte__quality_measures__stg_core__encounter encounter
    inner join tuva_synthetic.quality_measures._int_nqf0420__performance_period as pp
        on coalesce(encounter.encounter_end_date, encounter.encounter_start_date) >= pp.performance_period_begin
            and coalesce(encounter.encounter_start_date, encounter.encounter_end_date) <= pp.performance_period_end
    where lower(encounter_type) in (
          'home health'
        , 'office visit'
        , 'outpatient'
        , 'outpatient rehabilitation'
    )

)

, procedures as (

    select
        patient_id
      , procedure_date
      , coalesce (
              normalized_code_type
            , case
                when lower(source_code_type) = 'cpt' then 'hcpcs'
                when lower(source_code_type) = 'snomed' then 'snomed-ct'
                else lower(source_code_type)
              end
          ) as code_type
        , coalesce (
              normalized_code
            , source_code
          ) as code
    from __dbt__cte__quality_measures__stg_core__procedure
    where   coalesce(modifier_1, '') not in ('GQ', 'GT', '95')
        and coalesce(modifier_2, '') not in ('GQ', 'GT', '95')
        and coalesce(modifier_3, '') not in ('GQ', 'GT', '95')
        and coalesce(modifier_4, '') not in ('GQ', 'GT', '95')
        and coalesce(modifier_5, '') not in ('GQ', 'GT', '95')

)

, claims as (

    select 
          patient_id
        , coalesce(claim_start_date,claim_end_date) as min_date
        , coalesce(claim_end_date,claim_start_date) as max_date
        , hcpcs_code
    from __dbt__cte__quality_measures__stg_medical_claim
    where   coalesce(hcpcs_modifier_1, '') not in ('GQ', 'GT', '95')
        and coalesce(hcpcs_modifier_2, '') not in ('GQ', 'GT', '95')
        and coalesce(hcpcs_modifier_3, '') not in ('GQ', 'GT', '95')
        and coalesce(hcpcs_modifier_4, '') not in ('GQ', 'GT', '95')
        and coalesce(hcpcs_modifier_5, '') not in ('GQ', 'GT', '95')
        and coalesce(place_of_service_code, '') not in ('02')
        
)

, procedure_encounters as (

    select 
          procedures.patient_id
        , procedures.procedure_date as min_date
        , procedures.procedure_date as max_date
    from procedures
    inner join tuva_synthetic.quality_measures._int_nqf0420__performance_period  as pp
        on procedure_date between pp.performance_period_begin and pp.performance_period_end
    inner join visit_codes
        on procedures.code = visit_codes.code
            and procedures.code_type = visit_codes.code_system

)

, claims_encounters as (
    
    select 
          claims.patient_id
        , claims.min_date
        , claims.max_date
    from claims
    inner join tuva_synthetic.quality_measures._int_nqf0420__performance_period as pp 
        on claims.max_date >=  pp.performance_period_begin
            and claims.min_date <=  pp.performance_period_end
    inner join visit_codes
        on claims.hcpcs_code = visit_codes.code
            and visit_codes.code_system = 'hcpcs'

)

, all_encounters as (

    select *, 'v' as visit_enc, cast(null as TEXT) as proc_enc, cast(null as TEXT) as claim_enc
    from visits_encounters

    union all

    select *, cast(null as TEXT) as visit_enc, 'p' as proc_enc, cast(null as TEXT) as claim_enc
    from procedure_encounters

    union all
    
    select *, cast(null as TEXT) as visit_enc, cast(null as TEXT) as proc_enc, 'c' as claim_enc
    from claims_encounters

)

, encounters_by_patient as (

    select 
          patient_id
        , max(max_date) max_date
        , coalesce(min(visit_enc), '') || coalesce(min(proc_enc), '') || coalesce(min(claim_enc), '') as qualifying_types
    from all_encounters
    group by patient_id

)

, patients_with_age as (

    select
          p.patient_id
        , floor(datediff(
        hour,
        birth_date,
        e.max_date
        ) / 8760.0) as max_age
        , qualifying_types
    from __dbt__cte__quality_measures__stg_core__patient p
    inner join encounters_by_patient e
        on p.patient_id = e.patient_id
    where p.death_date is null

)

, qualifying_patients as (

    select
        distinct
          patient_id
        , max_age as age
        , pp.performance_period_begin
        , pp.performance_period_end
        , pp.measure_id
        , pp.measure_name
        , pp.measure_version
        , 1 as denominator_flag
    from patients_with_age
    cross join tuva_synthetic.quality_measures._int_nqf0420__performance_period pp
    where max_age >= 18

)

, add_data_types as (

    select
          cast(patient_id as TEXT) as patient_id
        , cast(age as integer) as age
        , cast(performance_period_begin as date) as performance_period_begin
        , cast(performance_period_end as date) as performance_period_end
        , cast(measure_id as TEXT) as measure_id
        , cast(measure_name as TEXT) as measure_name
        , cast(measure_version as TEXT) as measure_version
        , cast(denominator_flag as integer) as denominator_flag
    from qualifying_patients

)

select 
      patient_id
    , age
    , performance_period_begin
    , performance_period_end
    , measure_id
    , measure_name
    , measure_version
    , denominator_flag
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from add_data_types
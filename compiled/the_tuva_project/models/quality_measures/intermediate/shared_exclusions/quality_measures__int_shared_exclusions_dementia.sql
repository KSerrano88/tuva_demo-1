

with  __dbt__cte__quality_measures__stg_core__medication as (


select
      patient_id
    , encounter_id
    , prescribing_date   
    , dispensing_date
    , source_code_type
    , source_code
    , ndc_code
    , rxnorm_code
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from tuva_synthetic.core.medication


),  __dbt__cte__quality_measures__stg_pharmacy_claim as (



    select
      cast(null as TEXT ) as patient_id
    , try_cast( null as date ) as dispensing_date
    , cast(null as TEXT ) as ndc_code
    , try_cast( null as date ) as paid_date
    , cast(null as TIMESTAMP ) as tuva_last_run
    limit 0
), patients_with_frailty as (

    select
          patient_id
        , exclusion_date
        , exclusion_reason
    from tuva_synthetic.quality_measures._int_shared_exclusions_frailty

)

, exclusion_codes as (

    select
          code
        , code_system
        , concept_name
    from tuva_synthetic.quality_measures._value_set_codes
    where lower(concept_name) in (
        'dementia medications'
    )

)

, medications as (

    select
          patient_id
        , dispensing_date
        , source_code_type
        , source_code
        , ndc_code
        , rxnorm_code
    from __dbt__cte__quality_measures__stg_core__medication

)

, pharmacy_claim as (

    select
          patient_id
        , dispensing_date
        , ndc_code
        , paid_date
    from __dbt__cte__quality_measures__stg_pharmacy_claim

)

, medication_exclusions as (

    select
          medications.patient_id
        , medications.dispensing_date
        , exclusion_codes.concept_name
    from medications
         inner join exclusion_codes
            on medications.ndc_code = exclusion_codes.code
    where exclusion_codes.code_system = 'ndc'

    union all

    select
          medications.patient_id
        , medications.dispensing_date
        , exclusion_codes.concept_name
    from medications
         inner join exclusion_codes
            on medications.rxnorm_code = exclusion_codes.code
    where exclusion_codes.code_system = 'rxnorm'

    union all

    select
          medications.patient_id
        , medications.dispensing_date
        , exclusion_codes.concept_name
    from medications
         inner join exclusion_codes
            on medications.source_code = exclusion_codes.code
            and medications.source_code_type = exclusion_codes.code_system

)

, pharmacy_claim_exclusions as (

    select
          pharmacy_claim.patient_id
        , pharmacy_claim.dispensing_date
        , pharmacy_claim.ndc_code
        , pharmacy_claim.paid_date
        , exclusion_codes.concept_name
    from pharmacy_claim
         inner join exclusion_codes
            on pharmacy_claim.ndc_code = exclusion_codes.code
    where exclusion_codes.code_system = 'ndc'

)

, frailty_with_dementia as (

    select
          patients_with_frailty.patient_id
        , patients_with_frailty.exclusion_date
        , patients_with_frailty.exclusion_reason || ' with ' || pharmacy_claim_exclusions.concept_name as exclusion_reason
        , pharmacy_claim_exclusions.dispensing_date
        , pharmacy_claim_exclusions.paid_date
    from patients_with_frailty
         inner join pharmacy_claim_exclusions
            on patients_with_frailty.patient_id = pharmacy_claim_exclusions.patient_id

    union all

    select
          patients_with_frailty.patient_id
        , medication_exclusions.dispensing_date as exclusion_date
        , patients_with_frailty.exclusion_reason || ' with ' || medication_exclusions.concept_name as exclusion_reason
        , medication_exclusions.dispensing_date
        , null as paid_date
    from patients_with_frailty
         inner join medication_exclusions
         on patients_with_frailty.patient_id = medication_exclusions.patient_id

)

select
      patient_id
    , exclusion_date
    , exclusion_reason
    , 'dementia' as exclusion_type
    , dispensing_date
    , paid_date
    , '2024-10-04 19:11:18.274664+00:00' as tuva_last_run
from frailty_with_dementia
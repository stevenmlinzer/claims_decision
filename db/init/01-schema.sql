BEGIN;

CREATE SCHEMA IF NOT EXISTS claims;

CREATE TABLE claims.member (
    id INT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    zip int,
    birthday DATE,
    gender TEXT
);

CREATE TABLE claims.mem_policy (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mem_id INT REFERENCES claims.member(id),
    start_date TIMESTAMP ,
    end_date TIMESTAMP,
    car_make TEXT,
    car_model TEXT,
    car_year INT,
    blue_book_amt numeric(9,2),
    liab_body_amt numeric(9,2),
    liab_prop_amt numeric(9,2),
    liab_body_accident_amt numeric(9,2),
    uninc_body_amt numeric(9,2),
    uninc_prop_amt numeric(9,2),
    pip_passenger_amt numeric(9,2),
    pay_med_amt numeric(9,2),
    collision_deductable_amt numeric(6,2),
    comprehensive_deductable_amt numeric(6,2),
    car_rental TEXT
);

CREATE TABLE claims.claim (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_datetime TIMESTAMP,
    incident_address TEXT NOT NULL,
    incident_city TEXT NOT NULL,
    incident_state TEXT NOT NULL,
    incident_zip int,
    claimant_first_name TEXT NOT NULL,
    claimant_last_name TEXT NOT NULL,
    claimant_address TEXT NOT NULL,
    claimant_city TEXT NOT NULL,
    claimant_state TEXT NOT NULL,
    claimant_zip int,
    claimant_birthday DATE,
    claimant_gender TEXT,
    plaintiff_first_name TEXT NOT NULL,
    plaintiff_last_name TEXT NOT NULL,
    plaintiff_address TEXT NOT NULL,
    plaintiff_city TEXT NOT NULL,
    plaintiff_state TEXT NOT NULL,
    plaintiff_zip int,
    plaintiff_birthday DATE,
    plaintiff_gender TEXT,
    estimator_first_name TEXT,
    estimator_last_name TEXT,
    total_claim_amt numeric(9,2)
);

CREATE TABLE claims.claim_evidence (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id INT REFERENCES claims.claim(id),
    evidence_type TEXT NOT NULL,
    evd_incident_datetime TIMESTAMP,
    evd_gather_date DATE,
    evidence_description TEXT,
    evidence_conditions TEXT,
    evd_relation TEXT,
    evd_full_name TEXT
);

CREATE TABLE claims.claim_damage (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id INT REFERENCES claims.claim(id),
    damage_type TEXT NOT NULL,
    enter_date DATE,
    damage_description TEXT,
    business_address TEXT,
    business_name TEXT,
    damage_estimate numeric(9,2)
);

COMMIT;

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

COMMIT;

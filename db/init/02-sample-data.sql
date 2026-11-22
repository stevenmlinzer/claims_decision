BEGIN;

COPY claims.member (
    id,first_name,last_name,address,city,state,zip,birthday,gender
)
FROM '/seed/Members.csv'
WITH (
    FORMAT csv,
    HEADER true,
    ENCODING 'UTF8'
);

COPY claims.mem_policy (
    id,car_make,car_model,car_year,blue_book_amt,mem_id
)
FROM '/seed/Cars.csv'
WITH (
    FORMAT csv,
    HEADER true,
    ENCODING 'UTF8'
);

UPDATE claims.mem_policy targ
SET start_date = CURRENT_DATE - ((src.id % 10) * INTERVAL '1 month'),
    end_date = CURRENT_DATE + ((src.id-20) * INTERVAL '1 day'),
    liab_body_amt = ((src.id % 5) + 1) * 25000,
    liab_prop_amt = ((src.id % 4) + 1) * 10000,
    liab_body_accident_amt = ((src.id % 5) + 1) * 50000,
    uninc_body_amt = ((src.id % 5) + 1) * 25000,
    uninc_prop_amt = ((src.id % 4) + 1) * 10000,
    collision_deductable_amt = CASE WHEN (src.id % 4) = 0 THEN 100 WHEN (src.id % 2) = 0 THEN 250 ELSE 500 END,
    comprehensive_deductable_amt = CASE WHEN (src.id % 4) = 0 THEN 50 WHEN (src.id % 2) = 0 THEN 100 ELSE 250 END,
    pip_passenger_amt = CASE WHEN (src.id % 4) = 0 THEN 100 WHEN (src.id % 2) = 0 THEN 250 ELSE 500 END,
    pay_med_amt = CASE WHEN (src.id % 4) = 0 THEN 1000 WHEN (src.id % 2) = 0 THEN 2500 ELSE 5000 END,
    car_rental = CASE WHEN (src.id % 4) = 0 THEN 'Y' ELSE 'N' END
FROM claims.mem_policy src
WHERE targ.id = src.id;

COMMIT;

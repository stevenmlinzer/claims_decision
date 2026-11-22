-- Fictional policy and identity scenarios. Run after golden-claims.sql.
-- The negative member IDs are reserved for these fixtures; collisions abort the transaction.
BEGIN;
DO $fixtures$
DECLARE
    s RECORD;
    entry RECORD;
    member_key INT;
    policy_key INT;
    claim_key INT;
    evidence_key INT;
    damage_key INT;
BEGIN
    IF to_regclass('test_fixtures.golden_claims') IS NULL THEN
        RAISE EXCEPTION 'Load golden-claims.sql first';
    END IF;
    FOR s IN SELECT * FROM (VALUES
        ('birthday_inconsistent', -950001, 'Avery', 'FixtureBirthday', DATE '1986-04-12', DATE '1986-04-13',
         '2019', 'Honda', 'Civic', DATE '2025-06-15', DATE '2025-01-01', DATE '2025-12-31', 500.00::numeric, 2800.00::numeric,
         'I am Avery FixtureBirthday. The claim form lists my birthday as April 13, 1986; I was driving my 2019 Honda Civic.',
         'I saw the Honda Civic involved in the collision but cannot verify the driver identity or date of birth.',
         'The member record lists April 12, 1986; the claim form lists April 13, 1986. Neither date has been independently verified.'),
        ('owner_vehicle_not_listed', -950002, 'Blake', 'FixtureVehicle', DATE '1978-07-09', DATE '1978-07-09',
         '2020', 'Toyota', 'Camry', DATE '2025-06-15', DATE '2025-01-01', DATE '2025-12-31', 500.00::numeric, 3400.00::numeric,
         'I own the 2017 Nissan Altima involved in the collision. My policy lists my 2020 Toyota Camry; I have no policy document listing the Nissan.',
         'I observed the collision involving a 2017 Nissan Altima and my car.',
         'The member policy record lists a 2020 Toyota Camry, not the reported 2017 Nissan Altima. No VIN or complete policy schedule is available.'),
        ('estimate_below_deductible', -950003, 'Casey', 'FixtureDeductible', DATE '1990-11-06', DATE '1990-11-06',
         '2021', 'Subaru', 'Outback', DATE '2025-06-15', DATE '2025-01-01', DATE '2025-12-31', 500.00::numeric, 300.00::numeric,
         'My 2021 Subaru Outback sustained a scrape in the collision; the mechanic estimated repairs at $300.',
         'The collision involved a 2021 Subaru Outback; I observed a scrape after the collision.',
         'The mechanic estimate is $300. The member policy lists a $500 collision deductible for a 2021 Subaru Outback.'),
        ('accident_before_coverage', -950004, 'Drew', 'FixtureDates', DATE '1982-03-22', DATE '1982-03-22',
         '2022', 'Ford', 'Escape', DATE '2025-02-01', DATE '2025-03-01', DATE '2026-03-01', 500.00::numeric, 2500.00::numeric,
         'My 2022 Ford Escape was damaged in a collision on February 1, 2025. I added it to my policy on March 1, 2025.',
         'I saw the 2022 Ford Escape involved in a collision on February 1, 2025.',
         'The incident date is February 1, 2025. The policy record for the 2022 Ford Escape starts March 1, 2025; no earlier policy record is provided.')
    ) AS v(scenario, member_id, first_name, last_name, member_birthday, claim_birthday,
           car_year, car_make, car_model, incident_date, start_date, end_date, deductible, amount,
           claimant_story, plaintiff_story, verification)
    LOOP
        IF EXISTS (SELECT 1 FROM test_fixtures.golden_claims WHERE scenario = s.scenario) THEN
            CONTINUE;
        END IF;
        IF EXISTS (SELECT 1 FROM claims.member WHERE id = s.member_id) THEN
            RAISE EXCEPTION 'Fixture member ID % already exists; refusing to overwrite', s.member_id;
        END IF;
        INSERT INTO claims.member (id, first_name, last_name, address, city, state, zip, birthday)
        VALUES (s.member_id, s.first_name, s.last_name, '100 Test Avenue', 'Example City', 'TX', 77001, s.member_birthday)
        RETURNING id INTO member_key;
        IF EXISTS (SELECT 1 FROM claims.mem_policy WHERE id = s.member_id) THEN
            RAISE EXCEPTION 'Fixture policy ID % already exists; refusing to overwrite', s.member_id;
        END IF;
        INSERT INTO claims.mem_policy (id, mem_id, start_date, end_date, car_year, car_make, car_model, collision_deductable_amt)
        OVERRIDING SYSTEM VALUE
        VALUES (s.member_id, member_key, s.start_date, s.end_date, s.car_year::int, s.car_make, s.car_model, s.deductible)
        RETURNING id INTO policy_key;
        INSERT INTO claims.claim (incident_datetime, incident_address, incident_city, incident_state, incident_zip,
          claimant_first_name, claimant_last_name, claimant_address, claimant_city, claimant_state, claimant_zip, claimant_birthday,
          plaintiff_first_name, plaintiff_last_name, plaintiff_address, plaintiff_city, plaintiff_state, plaintiff_zip, total_claim_amt)
        VALUES (s.incident_date + TIME '12:00', '200 Test Road', 'Example City', 'TX', 77001,
          s.first_name, s.last_name, '100 Test Avenue', 'Example City', 'TX', 77001, s.claim_birthday,
          'Test', 'Plaintiff', '300 Test Road', 'Example City', 'TX', 77001, s.amount)
        RETURNING id INTO claim_key;
        INSERT INTO test_fixtures.golden_claims (scenario, claim_id) VALUES (s.scenario, claim_key);
        INSERT INTO claims.claim_damage (claim_id, damage_type, enter_date, damage_description, business_address, business_name, damage_estimate)
        VALUES (claim_key, 'Collision', s.incident_date + 2, 'Vehicle damage reported after a collision.', '400 Test Road, Example City, TX', 'Fixture Auto Repair', s.amount)
        RETURNING id INTO damage_key;
        FOR entry IN SELECT * FROM (VALUES
          ('claimant_statement', s.claimant_story, 'claimant', s.first_name || ' ' || s.last_name),
          ('plaintiff_statement', s.plaintiff_story, 'plaintiff', 'Test Plaintiff'),
          ('investigator_report', s.verification, 'investigator', 'Jordan Investigator')
        ) AS a(kind, story, role, person)
        LOOP
            INSERT INTO claims.claim_evidence (claim_id, evidence_type, evd_incident_datetime, evd_gather_date, evidence_description, evidence_conditions, evd_relation, evd_full_name)
            VALUES (claim_key, entry.kind, s.incident_date + TIME '12:00', s.incident_date + 1, entry.story, 'Fictional test record', entry.role, entry.person)
            RETURNING id INTO evidence_key;
            INSERT INTO claims.claim_document (claim_id, evidence_id, document_type, file_name, content_type, file_content, description)
            VALUES (claim_key, evidence_key, entry.kind, s.scenario || '-' || entry.kind || '.txt', 'text/plain',
                convert_to('FICTIONAL TEST DOCUMENT: ' || entry.story, 'UTF8'), 'Synthetic account for testing');
        END LOOP;
        INSERT INTO claims.claim_document (claim_id, damage_id, document_type, file_name, content_type, file_content, description)
        VALUES (claim_key, damage_key, 'mechanic_invoice', s.scenario || '-invoice.txt', 'text/plain',
            convert_to('FICTIONAL TEST INVOICE: collision estimate $' || s.amount::text, 'UTF8'), 'Synthetic mechanic invoice for testing');
    END LOOP;
END;
$fixtures$;
COMMIT;

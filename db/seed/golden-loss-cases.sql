-- Fictional loss scenarios; run after golden-claims.sql with nullable plaintiff columns.
-- Negative IDs are reserved for fixture members and policies; collisions abort.
BEGIN;
DO $fixtures$
DECLARE
    s RECORD;
    x RECORD;
    claim_key INT;
    damage_key INT;
    evidence_key INT;
BEGIN
    IF to_regclass('test_fixtures.golden_claims') IS NULL THEN
        RAISE EXCEPTION 'Load golden-claims.sql first';
    END IF;
    FOR s IN SELECT * FROM (VALUES
        ('damage_exceeds_value', -950005, 'Emery', 'FixtureValue', DATE '1985-02-15',
         '2016', 'Honda', 'Civic', 8000.00::numeric, 12500.00::numeric, false,
         'My 2016 Honda Civic was damaged in a collision. The repair estimate is $12,500.',
         'I saw the collision involving the Honda Civic but cannot assess the repair costs.',
         'The mechanic estimate is $12,500. The member policy lists the 2016 Honda Civic blue book amount as $8,000; no current independent valuation or salvage value is provided.'),
        ('hit_and_run_unknown_other_party', -950006, 'Finley', 'FixtureHitRun', DATE '1988-05-20',
         '2020', 'Toyota', 'Corolla', 15000.00::numeric, 2600.00::numeric, true,
         'My parked 2020 Toyota Corolla was damaged while I was away. The other vehicle and driver left and I do not know who they are.',
         NULL,
         'The police incident record describes reported damage to a parked car and an unknown driver. No witness or license plate has been identified.'),
        ('opposing_fault_accounts', -950007, 'Harper', 'FixtureFault', DATE '1979-09-10',
         '2019', 'Subaru', 'Outback', 14000.00::numeric, 4500.00::numeric, false,
         'I entered on a green light and the other driver ran a red light into my 2019 Subaru Outback.',
         'I entered on a green light and the claimant ran a red light into my vehicle.',
         'The police report records both accounts but no independent witness, usable video, or finding about the traffic signals.')
    ) AS v(scenario, fixture_id, first_name, last_name, birthday, car_year, car_make, car_model, car_value, amount, unknown_plaintiff,
           claimant_story, plaintiff_story, other_evidence)
    LOOP
        IF EXISTS (SELECT 1 FROM test_fixtures.golden_claims WHERE scenario = s.scenario) THEN CONTINUE; END IF;
        IF EXISTS (SELECT 1 FROM claims.member WHERE id = s.fixture_id)
          OR EXISTS (SELECT 1 FROM claims.mem_policy WHERE id = s.fixture_id) THEN
            RAISE EXCEPTION 'Fixture member or policy ID % exists; refusing to overwrite', s.fixture_id;
        END IF;
        INSERT INTO claims.member (id, first_name, last_name, address, city, state, zip, birthday)
        VALUES (s.fixture_id, s.first_name, s.last_name, '100 Test Avenue', 'Example City', 'TX', 77001, s.birthday);
        INSERT INTO claims.mem_policy (id, mem_id, start_date, end_date, car_year, car_make, car_model, blue_book_amt, collision_deductable_amt)
        OVERRIDING SYSTEM VALUE
        VALUES (s.fixture_id, s.fixture_id, DATE '2025-01-01', DATE '2025-12-31', s.car_year::int, s.car_make, s.car_model, s.car_value, 500.00);
        INSERT INTO claims.claim (incident_datetime, incident_address, incident_city, incident_state, incident_zip,
            claimant_first_name, claimant_last_name, claimant_address, claimant_city, claimant_state, claimant_zip, claimant_birthday,
            plaintiff_first_name, plaintiff_last_name, plaintiff_address, plaintiff_city, plaintiff_state, plaintiff_zip, total_claim_amt)
        VALUES (TIMESTAMP '2025-06-15 12:00', '200 Test Road', 'Example City', 'TX', 77001,
            s.first_name, s.last_name, '100 Test Avenue', 'Example City', 'TX', 77001, s.birthday,
            CASE WHEN s.unknown_plaintiff THEN NULL ELSE 'Test' END,
            CASE WHEN s.unknown_plaintiff THEN NULL ELSE 'Plaintiff' END,
            CASE WHEN s.unknown_plaintiff THEN NULL ELSE '300 Test Road' END,
            CASE WHEN s.unknown_plaintiff THEN NULL ELSE 'Example City' END,
            CASE WHEN s.unknown_plaintiff THEN NULL ELSE 'TX' END,
            CASE WHEN s.unknown_plaintiff THEN NULL ELSE 77001 END, s.amount)
        RETURNING id INTO claim_key;
        INSERT INTO test_fixtures.golden_claims (scenario, claim_id) VALUES (s.scenario, claim_key);
        INSERT INTO claims.claim_damage (claim_id, damage_type, enter_date, damage_description, business_address, business_name, damage_estimate)
        VALUES (claim_key, 'Collision', DATE '2025-06-17', 'Reported vehicle damage after collision.', '400 Test Road, Example City, TX', 'Fixture Auto Repair', s.amount)
        RETURNING id INTO damage_key;
        FOR x IN SELECT * FROM (VALUES
            ('claimant_statement', s.claimant_story, 'claimant', s.first_name || ' ' || s.last_name),
            ('plaintiff_statement', s.plaintiff_story, 'plaintiff', 'Test Plaintiff'),
            ('investigator_report', s.other_evidence, 'investigator', 'Jordan Investigator')
        ) AS v(kind, story, role, person)
        LOOP
            IF x.story IS NULL THEN CONTINUE; END IF;
            INSERT INTO claims.claim_evidence (claim_id, evidence_type, evd_incident_datetime, evd_gather_date, evidence_description, evidence_conditions, evd_relation, evd_full_name)
            VALUES (claim_key, x.kind, TIMESTAMP '2025-06-15 12:00', DATE '2025-06-16', x.story, 'Fictional test record', x.role, x.person)
            RETURNING id INTO evidence_key;
            INSERT INTO claims.claim_document (claim_id, evidence_id, document_type, file_name, content_type, file_content, description)
            VALUES (claim_key, evidence_key, x.kind, s.scenario || '-' || x.kind || '.txt', 'text/plain',
                convert_to('FICTIONAL TEST DOCUMENT: ' || x.story, 'UTF8'), 'Synthetic account for testing');
        END LOOP;
        INSERT INTO claims.claim_document (claim_id, damage_id, document_type, file_name, content_type, file_content, description)
        VALUES (claim_key, damage_key, 'mechanic_invoice', s.scenario || '-invoice.txt', 'text/plain',
            convert_to('FICTIONAL TEST INVOICE: estimate $' || s.amount::text, 'UTF8'), 'Synthetic mechanic invoice for testing');
    END LOOP;
END;
$fixtures$;
COMMIT;

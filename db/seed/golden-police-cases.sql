-- Fictional cases: run after golden-claims.sql and the document migration.
-- Reserved negative member/policy IDs avoid existing sample IDs.
BEGIN;
DO $cases$
DECLARE
    s RECORD;
    account RECORD;
    claim_key INT;
    damage_key INT;
    evidence_key INT;
BEGIN
    IF to_regclass('test_fixtures.golden_claims') IS NULL THEN
        RAISE EXCEPTION 'Load golden-claims.sql before this file';
    END IF;
    FOR s IN SELECT * FROM (VALUES
        ('police_contradicts_claimant', -950008, 'Lane', 'FixtureReportClaimant', DATE '1983-01-16',
         'I stopped at the stop sign and was struck while my car was stationary.',
         'The claimant entered the intersection without stopping and struck my car.',
         'The police report records an officer reviewing traffic camera footage showing the claimant vehicle passing the stop line without stopping before the collision. The footage is referenced but not attached.',
         'The report is a secondary account of footage; the recording has not been independently reviewed.'),
        ('police_contradicts_plaintiff', -950009, 'Reese', 'FixtureReportPlaintiff', DATE '1987-10-05',
         'I stopped at the stop sign and was struck while my car was stationary.',
         'The claimant entered the intersection without stopping and struck my car.',
         'The police report records an officer reviewing traffic camera footage showing the claimant vehicle stopping at the sign, then being struck by the plaintiff vehicle. The footage is referenced but not attached.',
         'The report is a secondary account of footage; the recording has not been independently reviewed.')
    ) AS v(scenario, fixture_id, first_name, last_name, birthday, claimant_story, plaintiff_story, police_story, limitations)
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
        VALUES (s.fixture_id, s.fixture_id, DATE '2025-01-01', DATE '2025-12-31', 2020, 'Honda', 'Civic', 14000, 500);
        INSERT INTO claims.claim (incident_datetime, incident_address, incident_city, incident_state, incident_zip,
            claimant_first_name, claimant_last_name, claimant_address, claimant_city, claimant_state, claimant_zip, claimant_birthday,
            plaintiff_first_name, plaintiff_last_name, plaintiff_address, plaintiff_city, plaintiff_state, plaintiff_zip, total_claim_amt)
        VALUES (TIMESTAMP '2025-06-15 12:00', '200 Test Road', 'Example City', 'TX', 77001,
            s.first_name, s.last_name, '100 Test Avenue', 'Example City', 'TX', 77001, s.birthday,
            'Test', 'Plaintiff', '300 Test Road', 'Example City', 'TX', 77001, 4500)
        RETURNING id INTO claim_key;
        INSERT INTO test_fixtures.golden_claims (scenario, claim_id) VALUES (s.scenario, claim_key);
        INSERT INTO claims.claim_damage (claim_id, damage_type, enter_date, damage_description, business_name, business_address, damage_estimate)
        VALUES (claim_key, 'Collision', DATE '2025-06-17', 'Vehicle damage reported after intersection collision.', 'Fixture Auto Repair', '400 Test Road, Example City, TX', 4500)
        RETURNING id INTO damage_key;
        FOR account IN SELECT * FROM (VALUES
            ('claimant_statement', s.claimant_story, 'claimant', s.first_name || ' ' || s.last_name),
            ('plaintiff_statement', s.plaintiff_story, 'plaintiff', 'Test Plaintiff'),
            ('police_report', s.police_story, 'police', 'Officer Example')
        ) AS a(kind, story, role, person)
        LOOP
            INSERT INTO claims.claim_evidence (claim_id, evidence_type, evd_incident_datetime, evd_gather_date, evidence_description, evidence_conditions, evd_relation, evd_full_name)
            VALUES (claim_key, account.kind, TIMESTAMP '2025-06-15 12:00', DATE '2025-06-16', account.story, s.limitations, account.role, account.person)
            RETURNING id INTO evidence_key;
            INSERT INTO claims.claim_document (claim_id, evidence_id, document_type, file_name, content_type, file_content, description)
            VALUES (claim_key, evidence_key, account.kind, s.scenario || '-' || account.kind || '.txt', 'text/plain',
                convert_to('FICTIONAL TEST DOCUMENT: ' || account.story, 'UTF8'), 'Synthetic source account for testing');
        END LOOP;
        INSERT INTO claims.claim_document (claim_id, damage_id, document_type, file_name, content_type, file_content, description)
        VALUES (claim_key, damage_key, 'mechanic_invoice', s.scenario || '-invoice.txt', 'text/plain',
            convert_to('FICTIONAL TEST INVOICE: estimate $4500.00', 'UTF8'), 'Synthetic mechanic invoice for testing');
    END LOOP;
END;
$cases$;
COMMIT;

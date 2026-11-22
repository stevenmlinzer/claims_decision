-- Fictional test fixtures. Requires migrations 03 and 04 and sample members 1-3.
-- Run with psql -v ON_ERROR_STOP=1. Re-running is a no-op once all cases exist.
BEGIN;
CREATE SCHEMA IF NOT EXISTS test_fixtures;
CREATE TABLE IF NOT EXISTS test_fixtures.golden_claims (
    scenario TEXT PRIMARY KEY,
    claim_id INT NOT NULL UNIQUE REFERENCES claims.claim(id)
);
DO $golden$
DECLARE
    s RECORD;
    m claims.member%ROWTYPE;
    new_claim_id INT;
    evidence_id INT;
    damage_id INT;
    incident_at TIMESTAMP;
    existing_count INT;
BEGIN
    SELECT count(*) INTO existing_count FROM test_fixtures.golden_claims
    WHERE scenario IN ('member_collision', 'member_weather', 'conflicting_accounts', 'unmatched_claimant', 'missing_birthday');
    IF existing_count = 5 THEN
        RAISE NOTICE 'Golden claims already loaded; no changes made.';
        RETURN;
    ELSIF existing_count <> 0 THEN
        RAISE EXCEPTION 'Incomplete golden fixture registry; inspect test_fixtures.golden_claims before retrying';
    END IF;
    IF (SELECT count(*) FROM claims.member WHERE id IN (1,2,3) AND birthday IS NOT NULL) <> 3 THEN
        RAISE EXCEPTION 'Sample members 1, 2 and 3 with birthdays are required';
    END IF;
    IF (SELECT count(DISTINCT mem_id) FROM claims.mem_policy WHERE mem_id IN (1,2,3) AND start_date IS NOT NULL AND end_date IS NOT NULL AND start_date <= end_date) <> 3 THEN
        RAISE EXCEPTION 'Each sample member needs a policy with valid start and end dates';
    END IF;
    FOR s IN SELECT * FROM (VALUES
        ('member_collision', 1, 'Collision', 'Two vehicles collided at an intersection.', 4250.00::numeric, 'Police report supports the reported collision.', 'support', 'police_report'),
        ('member_weather', 2, 'Weather', 'A tree branch fell on the parked vehicle.', 2800.00::numeric, 'Witness confirms a branch fell during the storm.', 'support', 'witness_statement'),
        ('conflicting_accounts', 3, 'Collision', 'Claimant reports a parked vehicle was struck.', 6100.00::numeric, 'Investigator reports the available timeline conflicts with the account.', 'contradict', 'investigator_report'),
        ('unmatched_claimant', 1, 'Collision', 'Claimant reports a collision; no member record matches.', 1950.00::numeric, 'Police report documents a collision.', 'support', 'police_report'),
        ('missing_birthday', 2, 'Theft', 'Claimant reports vehicle theft; birthday is missing.', 14500.00::numeric, 'Police report reference supplied; identity needs verification.', 'neutral', 'police_report')
    ) AS x(scenario, member_id, damage_type, description, amount, evidence, relation, doc_type)
    LOOP
        SELECT * INTO STRICT m FROM claims.member WHERE id = s.member_id;
        SELECT start_date + (end_date - start_date) / 2 INTO incident_at
        FROM claims.mem_policy WHERE mem_id = m.id AND start_date IS NOT NULL AND end_date IS NOT NULL AND start_date <= end_date ORDER BY id LIMIT 1;
        INSERT INTO claims.claim (incident_datetime, incident_address, incident_city, incident_state, incident_zip,
            claimant_first_name, claimant_last_name, claimant_address, claimant_city, claimant_state, claimant_zip, claimant_birthday, claimant_gender,
            plaintiff_first_name, plaintiff_last_name, plaintiff_address, plaintiff_city, plaintiff_state, plaintiff_zip,
            estimator_first_name, estimator_last_name, total_claim_amt)
        VALUES (incident_at, '100 Test Avenue', 'Example City', 'TX', 77001,
            CASE WHEN s.scenario = 'unmatched_claimant' THEN 'GoldenUnmatched' ELSE m.first_name END,
            CASE WHEN s.scenario = 'unmatched_claimant' THEN 'Claimant' ELSE m.last_name END,
            m.address, m.city, m.state, m.zip,
            CASE WHEN s.scenario = 'missing_birthday' THEN NULL ELSE m.birthday END, m.gender,
            'Test', 'Plaintiff', '200 Test Road', 'Example City', 'TX', 77001,
            'Morgan', 'Estimator', s.amount)
        RETURNING id INTO new_claim_id;
        INSERT INTO test_fixtures.golden_claims VALUES (s.scenario, new_claim_id);
        INSERT INTO claims.claim_damage (claim_id, damage_type, enter_date, damage_description, business_address, business_name, damage_estimate)
        VALUES (new_claim_id, s.damage_type, incident_at::date + 2, s.description, '300 Test Road, Example City, TX', 'Golden Test Auto', s.amount)
        RETURNING id INTO damage_id;
        INSERT INTO claims.claim_evidence (claim_id, evidence_type, evd_incident_datetime, evd_gather_date, evidence_description, evidence_conditions, evd_relation, evd_full_name)
        VALUES (new_claim_id, s.doc_type, incident_at, incident_at::date + 1, s.evidence, 'Fictional fixture; verify independently', s.relation, 'Taylor Example')
        RETURNING id INTO evidence_id;
        INSERT INTO claims.claim_document (claim_id, evidence_id, document_type, file_name, content_type, file_content, description)
        VALUES (new_claim_id, evidence_id, s.doc_type, s.scenario || '-evidence.txt', 'text/plain', convert_to('FICTIONAL TEST DOCUMENT: ' || s.evidence, 'UTF8'), 'Synthetic evidence for testing');
        INSERT INTO claims.claim_document (claim_id, damage_id, document_type, file_name, content_type, file_content, description)
        VALUES (new_claim_id, damage_id, 'mechanic_invoice', s.scenario || '-invoice.txt', 'text/plain', convert_to('FICTIONAL TEST INVOICE: ' || s.description || ' Estimate: $' || s.amount::text, 'UTF8'), 'Synthetic mechanic invoice for testing');
    END LOOP;
END;
$golden$;
COMMIT;

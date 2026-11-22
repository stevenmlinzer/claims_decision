-- Fictional claim accounts and witness cases. Run after golden-claims.sql.
-- Each scenario is inserted once. Existing real claims are never changed.
BEGIN;
DO $cases$
DECLARE
    s RECORD;
    m claims.member%ROWTYPE;
    claim_key INT;
    damage_key INT;
    evidence_key INT;
    incident_at TIMESTAMP;
    existing_claim INT;
    x RECORD;
BEGIN
    IF to_regclass('test_fixtures.golden_claims') IS NULL THEN
        RAISE EXCEPTION 'Load golden-claims.sql before this file';
    END IF;
    IF (SELECT count(*) FROM claims.member WHERE id IN (1, 2, 3) AND birthday IS NOT NULL) <> 3 THEN
        RAISE EXCEPTION 'Sample members 1, 2 and 3 with birthdays are required';
    END IF;
    FOR s IN SELECT * FROM (VALUES
      ('witness_corroborated', 1, 'The claimant says they stopped at a red light and were struck from behind.', 'The plaintiff says they struck the claimant after failing to stop in time.', 'A witness says they saw both vehicles and the rear impact while standing at the corner.', 'Police scene notes describe rear damage and debris behind the claimant vehicle.', 'Rain had stopped; witness reports an unobstructed view.', 4200.00::numeric),
      ('witness_uncertain_view', 2, 'The claimant says the plaintiff entered the intersection against a red light.', 'The plaintiff says their light was green and the claimant entered on red.', 'A witness heard a crash but had their back turned and did not see either signal.', 'The police report notes no independent signal evidence.', 'Witness says they did not see the lights.', 3500.00::numeric),
      ('witness_changed_account', 3, 'The claimant says the plaintiff changed lanes into them.', 'The plaintiff says the claimant changed lanes into them.', 'A witness initially said the claimant changed lanes; the following day they said they could not identify which car changed lanes.', 'The investigator documents both versions but could not resolve the lane position.', 'The witness says they were stressed and may have confused the vehicles.', 5100.00::numeric),
      ('witness_possible_bias', 1, 'The claimant says the plaintiff backed into their parked vehicle.', 'The plaintiff says the claimant drove into the plaintiff vehicle.', 'The claimant passenger says the plaintiff backed into the parked vehicle.', 'The investigator notes the witness is the claimant sibling; no independent recording was found.', 'Witness was inside the claimant vehicle.', 2800.00::numeric),
      ('witness_contradicted_time', 2, 'The claimant says the plaintiff struck their vehicle at 2:00 p.m.', 'The plaintiff says both vehicles made contact at about 2:00 p.m.', 'A witness says they personally saw the crash at 2:00 p.m. from inside a nearby store.', 'The store access log shows that witness entered at 2:18 p.m.; the log does not establish where the witness was at 2:00 p.m.', 'The access log is an independent record but has not been independently verified.', 4650.00::numeric),
      ('witness_fabrication_admitted', 3, 'The claimant says the plaintiff sideswiped their vehicle.', 'The plaintiff says no collision occurred between the vehicles.', 'A witness first reported seeing the collision, then signed a statement admitting they were not present and had invented the account.', 'The investigator obtained both signed statements; no independent cause evidence was found.', 'The signed admission concerns the witness account only.', 6300.00::numeric),
      ('witness_honest_mistake', 1, 'The claimant says the plaintiff vehicle was blue and hit their parked car.', 'The plaintiff says their blue vehicle was elsewhere at the time.', 'A witness says a blue sedan struck the parked car, but cannot read the plate or identify the driver.', 'A time-stamped video shows a different blue sedan at the scene; its plate does not match the plaintiff vehicle.', 'The video plate and timing appear clear; ownership still needs verification.', 2200.00::numeric),
      ('witnesses_disagree', 2, 'The claimant says the plaintiff ran a stop sign.', 'The plaintiff says they stopped and the claimant was speeding.', 'One witness says the plaintiff did not stop; a second witness says the plaintiff stopped but did not see the claimant approach.', 'The investigator reports no video or speed measurement.', 'Witnesses observed from different corners.', 3900.00::numeric)
    ) AS v(scenario, member_id, claimant_story, plaintiff_story, witness_story, independent_evidence, conditions, amount)
    LOOP
        SELECT claim_id INTO existing_claim FROM test_fixtures.golden_claims WHERE scenario = s.scenario;
        IF FOUND THEN CONTINUE; END IF;
        SELECT * INTO STRICT m FROM claims.member WHERE id = s.member_id;
        SELECT start_date + (end_date - start_date) / 2 INTO incident_at
        FROM claims.mem_policy WHERE mem_id = m.id AND start_date IS NOT NULL AND end_date IS NOT NULL
            AND start_date <= end_date ORDER BY id LIMIT 1;
        IF incident_at IS NULL THEN RAISE EXCEPTION 'Member % has no valid policy period', m.id; END IF;
        INSERT INTO claims.claim (incident_datetime, incident_address, incident_city, incident_state, incident_zip,
            claimant_first_name, claimant_last_name, claimant_address, claimant_city, claimant_state, claimant_zip, claimant_birthday, claimant_gender,
            plaintiff_first_name, plaintiff_last_name, plaintiff_address, plaintiff_city, plaintiff_state, plaintiff_zip,
            estimator_first_name, estimator_last_name, total_claim_amt)
        VALUES (incident_at, '100 Test Avenue', 'Example City', 'TX', 77001,
            m.first_name, m.last_name, m.address, m.city, m.state, m.zip, m.birthday, m.gender,
            'Test', 'Plaintiff', '200 Test Road', 'Example City', 'TX', 77001,
            'Morgan', 'Estimator', s.amount)
        RETURNING id INTO claim_key;
        INSERT INTO test_fixtures.golden_claims (scenario, claim_id) VALUES (s.scenario, claim_key);
        INSERT INTO claims.claim_damage (claim_id, damage_type, enter_date, damage_description, business_address, business_name, damage_estimate)
        VALUES (claim_key, 'Collision', incident_at::date + 2, 'Reported vehicle damage; cause remains subject to review.', '300 Test Road, Example City, TX', 'Golden Test Auto', s.amount)
        RETURNING id INTO damage_key;
        FOR x IN SELECT * FROM (VALUES
            ('claimant_statement', s.claimant_story, 'claimant', m.first_name || ' ' || m.last_name),
            ('plaintiff_statement', s.plaintiff_story, 'plaintiff', 'Test Plaintiff'),
            ('witness_statement', s.witness_story, 'witness', 'Alex Example'),
            ('investigator_report', s.independent_evidence, 'investigator', 'Jordan Investigator')
        ) AS a(evidence_type, description, relation, person)
        LOOP
            INSERT INTO claims.claim_evidence (claim_id, evidence_type, evd_incident_datetime, evd_gather_date, evidence_description, evidence_conditions, evd_relation, evd_full_name)
            VALUES (claim_key, x.evidence_type, incident_at, incident_at::date + 1, x.description, s.conditions, x.relation, x.person)
            RETURNING id INTO evidence_key;
            INSERT INTO claims.claim_document (claim_id, evidence_id, document_type, file_name, content_type, file_content, description)
            VALUES (claim_key, evidence_key, x.evidence_type, s.scenario || '-' || x.evidence_type || '.txt', 'text/plain',
                    convert_to('FICTIONAL TEST DOCUMENT: ' || x.description, 'UTF8'), 'Synthetic source account for testing');
        END LOOP;
        INSERT INTO claims.claim_document (claim_id, damage_id, document_type, file_name, content_type, file_content, description)
        VALUES (claim_key, damage_key, 'mechanic_invoice', s.scenario || '-invoice.txt', 'text/plain',
                convert_to('FICTIONAL TEST INVOICE. Estimate: $' || s.amount::text, 'UTF8'), 'Synthetic mechanic invoice for testing');
    END LOOP;
END;
$cases$;

-- Add party accounts to the original five fixtures, without duplicating them on reruns.
CREATE TABLE IF NOT EXISTS test_fixtures.golden_party_accounts (
    scenario TEXT NOT NULL REFERENCES test_fixtures.golden_claims(scenario),
    role TEXT NOT NULL CHECK (role IN ('claimant', 'plaintiff')),
    evidence_id INT NOT NULL UNIQUE REFERENCES claims.claim_evidence(id),
    PRIMARY KEY (scenario, role)
);
DO $accounts$
DECLARE s RECORD; x RECORD; claim_key INT; evidence_key INT; incident_at TIMESTAMP;
BEGIN
    FOR s IN SELECT * FROM (VALUES
      ('member_collision', 'I was struck by another vehicle at the intersection.', 'I was involved in the intersection collision; I dispute who had the right of way.'),
      ('member_weather', 'A branch fell on my parked vehicle during a storm.', 'I did not see the branch fall and cannot confirm when the damage occurred.'),
      ('conflicting_accounts', 'My parked vehicle was struck while I was away.', 'I dispute the reported time and do not know how the damage occurred.'),
      ('unmatched_claimant', 'I was involved in the reported collision.', 'I was involved in the collision but dispute the claimant account.'),
      ('missing_birthday', 'My vehicle was stolen from the parking area.', 'I do not know who took the vehicle or when it was removed.')
    ) AS v(scenario, claimant_story, plaintiff_story)
    LOOP
        SELECT c.id, c.incident_datetime INTO STRICT claim_key, incident_at
        FROM test_fixtures.golden_claims f JOIN claims.claim c ON c.id = f.claim_id
        WHERE f.scenario = s.scenario;
        FOR x IN SELECT * FROM (VALUES ('claimant', s.claimant_story), ('plaintiff', s.plaintiff_story)) AS v(role, story)
        LOOP
            IF EXISTS (SELECT 1 FROM test_fixtures.golden_party_accounts WHERE scenario = s.scenario AND role = x.role) THEN CONTINUE; END IF;
            INSERT INTO claims.claim_evidence (claim_id, evidence_type, evd_incident_datetime, evd_gather_date, evidence_description, evidence_conditions, evd_relation, evd_full_name)
            VALUES (claim_key, x.role || '_statement', incident_at, incident_at::date + 1, x.story, 'Fictional account for testing', x.role, NULL)
            RETURNING id INTO evidence_key;
            INSERT INTO test_fixtures.golden_party_accounts VALUES (s.scenario, x.role, evidence_key);
            INSERT INTO claims.claim_document (claim_id, evidence_id, document_type, file_name, content_type, file_content, description)
            VALUES (claim_key, evidence_key, x.role || '_statement', s.scenario || '-' || x.role || '-statement.txt', 'text/plain',
                    convert_to('FICTIONAL TEST DOCUMENT: ' || x.story, 'UTF8'), 'Synthetic party account for testing');
        END LOOP;
    END LOOP;
END;
$accounts$;
COMMIT;

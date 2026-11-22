# Golden claims test data

`golden-claims.sql` creates five fictional claims and records their generated IDs in `test_fixtures.golden_claims`. Each has one damage estimate, one evidence record, and two synthetic text documents. The script does not delete existing data. Once all five fixtures exist, running it again is a no-op. If the registry is incomplete, it stops for inspection.

| Scenario | Expected membership flag | Purpose |
| --- | --- | --- |
| member_collision | true | Member match, collision, supporting police report |
| member_weather | true | Member match, weather damage, supporting witness |
| conflicting_accounts | true | Member match, evidence contradicts reported account |
| unmatched_claimant | false | No matching member; rejection candidate |
| missing_birthday | false | Missing birthday; identity needs review |

The incident dates are chosen inside a policy period for the selected member, but a policy-period match alone does not prove coverage. The database has no claim-to-policy or vehicle link, so these fixtures do not establish which vehicle was involved or whether the loss is covered. Their descriptions and documents are fictional and are not coverage determinations.

## Load into an existing development database

Apply `db/init/03-claim-member-match.sql`, then `db/init/04-claim-documents.sql`, then `db/seed/golden-claims.sql` using `psql` with `ON_ERROR_STOP=1`, connected to the intended database. The database must contain sample members 1, 2, and 3 with birthdays and valid policy periods, as supplied by the project's sample data. Back up the database and verify the target before applying migrations. These files are not automatically applied to an existing PostgreSQL volume.

For an already-running Compose database, from the project directory, after configuring the required Compose environment:

```sh
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/init/03-claim-member-match.sql
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/init/04-claim-documents.sql
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/seed/golden-claims.sql
```

Verify:

```sql
SELECT f.scenario, c.id, c.claimant_is_member,
       (SELECT count(*) FROM claims.claim_damage d WHERE d.claim_id = c.id) AS damages,
       (SELECT count(*) FROM claims.claim_evidence e WHERE e.claim_id = c.id) AS evidence,
       (SELECT count(*) FROM claims.claim_document d WHERE d.claim_id = c.id) AS documents
FROM test_fixtures.golden_claims f
JOIN claims.claim c ON c.id = f.claim_id
ORDER BY f.scenario;
```

A fresh database initialized by Compose runs migrations 03 and 04 automatically, after which the seed script must still be run explicitly. PostgreSQL image initialization scripts do not rerun on an existing data volume.

import logging

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi import HTTPException, Query, Request
from fastapi.templating import Jinja2Templates

import psycopg
from psycopg.rows import dict_row

templates = Jinja2Templates(directory="templates")
logger = logging.getLogger(__name__)

app = FastAPI(title="Auto Claims Website")

@app.get("/", response_class=HTMLResponse)
def home():
    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>First Claims Website</title>
      <style>
        body {
          margin: 0;
          background: #101827;
          color: #edf2fa;
          font-family: system-ui, sans-serif;
        }
        main { max-width: 720px; margin: 12vh auto; padding: 24px; }
        h1 { font-size: clamp(2rem, 6vw, 4rem); }
        p { line-height: 1.7; color: #b8c8df; }
        a { color: #7dd3fc; }
      </style>
    </head>
    <body>
      <main>
        <p>DEVELOPMENT ENVIRONMENT</p>
        <h1>Claims First Decision Powered by AI</h1>
        <p>FastAPI is running inside Docker on AWS.
           This is the starting point for your LLM and AI-agent application.</p>
        <p><a href="/claims">View Claims Backlog</a></p>
        <p><a href="/members">View Members and Policies →</a></p>
        <a href="/docs">Explore the API →</a>
      </main>
    </body>
    </html>
    """


@app.get("/members", response_class=HTMLResponse)
def members_page(
    request: Request,
    page: int = Query(default=1, ge=1),
):
    page_size = 25

    try:
        # Psycopg reads the PG* environment variables from Compose.
        with psycopg.connect(
            connect_timeout=5,
            row_factory=dict_row,
            options="-c default_transaction_read_only=on",
        ) as conn:
            members = conn.execute(
                """
                SELECT id, first_name, last_name, address, city, state, zip
                FROM claims.member
                ORDER BY id
                LIMIT %s OFFSET %s
                """,
                (page_size + 1, (page - 1) * page_size),
            ).fetchall()

            has_next = len(members) > page_size
            members = members[:page_size]

            policies_by_member = {}
            if members:
                policies = conn.execute(
                    """
                    SELECT *
                    FROM claims.mem_policy
                    WHERE mem_id = ANY(%s)
                    ORDER BY mem_id, id
                    """,
                    ([member["id"] for member in members],),
                ).fetchall()

                for policy in policies:
                    policies_by_member.setdefault(
                        policy["mem_id"], []
                    ).append(policy)

    except psycopg.Error:
        logger.exception("Unable to load members and policies")
        raise HTTPException(
            status_code=503,
            detail="Database temporarily unavailable",
        ) from None

    return templates.TemplateResponse(
        request=request,
        name="members.html",
        context={
            "members": members,
            "policies_by_member": policies_by_member,
            "page": page,
            "has_next": has_next,
        },
    )


@app.get('/claims', response_class=HTMLResponse)
def claims_page(request: Request, q: str = Query(default='', max_length=100),
                claim_id: int | None = Query(default=None, ge=1),
                page: int = Query(default=1, ge=1)):
    """Read-only claims worklist. No coverage decision is made here."""
    page_size = 25
    search = q.strip()
    try:
        with psycopg.connect(connect_timeout=5, row_factory=dict_row,
                             options='-c default_transaction_read_only=on') as conn:
            # Escape wildcard characters so a search is interpreted literally.
            pattern = '%' + search.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'
            where = """WHERE (%s = '' OR CAST(c.id AS text) ILIKE %s
                       OR c.claimant_first_name ILIKE %s OR c.claimant_last_name ILIKE %s
                       OR (c.claimant_first_name || ' ' || c.claimant_last_name) ILIKE %s)"""
            params = (search, pattern, pattern, pattern, pattern)
            total = conn.execute('SELECT count(*) AS n FROM claims.claim c ' + where, params).fetchone()['n']
            rows = conn.execute('''SELECT c.id, c.claimant_first_name, c.claimant_last_name,
                c.incident_datetime, c.incident_city, c.incident_state, c.total_claim_amt
                FROM claims.claim c ''' + where + ''' ORDER BY c.incident_datetime DESC NULLS LAST, c.id DESC
                LIMIT %s OFFSET %s''', (*params, page_size, (page - 1) * page_size)).fetchall()
            selected = None
            matches, policies, damage, evidence = [], [], [], []
            if claim_id is None and rows:
                claim_id = rows[0]['id']
            if claim_id is not None:
                selected = conn.execute('SELECT * FROM claims.claim WHERE id = %s', (claim_id,)).fetchone()
                if selected:
                    matches = conn.execute('''SELECT id, first_name, last_name FROM claims.member
                        WHERE lower(trim(first_name)) = lower(trim(%s))
                          AND lower(trim(last_name)) = lower(trim(%s)) AND birthday = %s
                        ORDER BY id LIMIT 2''', (selected['claimant_first_name'], selected['claimant_last_name'], selected['claimant_birthday'])).fetchall()
                    if len(matches) == 1:
                        policies = conn.execute('''SELECT id, start_date, end_date, car_year, car_make, car_model,
                            collision_deductable_amt, comprehensive_deductable_amt, liab_body_amt, liab_prop_amt
                            FROM claims.mem_policy WHERE mem_id = %s ORDER BY id''', (matches[0]['id'],)).fetchall()
                    damage = conn.execute('SELECT * FROM claims.claim_damage WHERE claim_id = %s ORDER BY id', (claim_id,)).fetchall()
                    evidence = conn.execute('SELECT * FROM claims.claim_evidence WHERE claim_id = %s ORDER BY id', (claim_id,)).fetchall()
    except psycopg.Error:
        logger.exception('Unable to load claims backlog')
        raise HTTPException(status_code=503, detail='Database temporarily unavailable') from None
    return templates.TemplateResponse(request=request, name='claims.html', context={
        'claims': rows, 'selected': selected, 'matches': matches, 'policies': policies,
        'damage': damage, 'evidence': evidence, 'q': search, 'page': page,
        'total': total, 'page_size': page_size,
    })

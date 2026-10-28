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

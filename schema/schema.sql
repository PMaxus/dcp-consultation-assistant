-- DCP consultation & pricing assistant - sanitized PostgreSQL schema.
-- Column names are taken from the workflow nodes; types are representative.
-- The design keeps the "moving parts" in data: catalog/rules in Google Sheets,
-- prompts in prompt_library, per-request context in Postgres Memory.
--
-- prompt_library ships as STRUCTURE ONLY - the prompt texts are not published.

-- One row per client request / conversation.
CREATE TABLE public.dcp_sessions (
    session_id       TEXT        PRIMARY KEY,
    telegram_user_id BIGINT,
    memory_key       TEXT,                          -- truncated SHA-256(hash) / user_id; keys the memory below
    status           TEXT,                          -- open | escalated | closed ...
    closed_reason    TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ DEFAULT NOW()
);

-- n8n Postgres Chat Memory store (per-request context, window depth ~90).
-- One structure covers agent context, the window limit, logging and analytics;
-- filtering by a client's key returns the full history with one query.
CREATE TABLE public.dcp_chat_history (
    id         SERIAL PRIMARY KEY,
    session_id TEXT,                                 -- = dcp_sessions.memory_key
    message    JSONB
);

-- Issue tracker: the manager logs wrong / doubtful answers; fixes go through a
-- durable loop with history (human-in-the-loop), not one-off prompt edits.
CREATE TABLE public.issue_tracking (
    id            SERIAL      PRIMARY KEY,
    source        TEXT,
    client        TEXT,
    agent         TEXT,
    agent_guess   TEXT,
    issue_type    TEXT,
    issue_content TEXT,
    status        TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Shared prompt store (public schema). STRUCTURE ONLY - prompt rows not published.
-- The agent reads its active prompt by key at run time
-- (systemMessage = {{ $('get_prompt').item.json.prompt_text }}).
CREATE TABLE public.prompt_library (
    id          SERIAL      PRIMARY KEY,
    agent_key   TEXT,
    version     INTEGER,
    status      TEXT,                                 -- 'active' | 'deprecated'
    prompt_text TEXT,                                 -- NOT included in this repository
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

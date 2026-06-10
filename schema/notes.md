# Data model notes

The design keeps the **moving parts in data**, not in workflow code, so the assistant
survives rule changes without a rebuild:

- **catalog & pricing rules** → Google Sheets (loaded by the agent at run time);
- **prompts** → `prompt_library` table (read by key at run time);
- **per-request context** → Postgres Memory;
- **corrections** → `issue_tracking` (human-in-the-loop self-improvement loop).

## Tables

| Table | Role |
|---|---|
| `dcp_sessions` | one row per client request (session id, telegram user, memory key, status) |
| `dcp_chat_history` | n8n Postgres Chat Memory store (per-request context, window depth ~90) |
| `issue_tracking` | manager-logged corrections, with status and history |
| `public.prompt_library` *(shared)* | agent prompts as data — **structure only**, texts not published |

## Per-request memory

The request key is a **truncated SHA-256 (`hash / user_id`)** used as the Postgres Memory
session key. One structure covers agent context, the context-window limit, logging and
analytics at once; filtering by a client's `user_id` returns their full history with one
SQL query. This removed the "mixed-up dialogs" problem under parallel requests.

The working context resets on a direct request, on the agent's confirmation, or on an
inactivity timeout — the logs are kept.

## Prompts as data

The agent's system prompt is **not** stored in the AI node; it is read from
`prompt_library` at run time. To change a prompt, the current version is deprecated and a
new one inserted (history kept). The prompt texts are the product's content and are not
part of this repository.

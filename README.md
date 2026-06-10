# DCP consultation & pricing assistant (n8n)

**Stack:** n8n (self-hosted) · PostgreSQL (+ Postgres Memory) · Telegram · OpenRouter · Google Sheets

A Telegram assistant for a Digital Cinema Package (DCP) service. It handles the
first-line client questions — service questions, price calculations, explanations —
runs the consultation from a catalog and pricing rules, keeps context per request,
and escalates unclear cases to a human. In the pilot it took ~60% of first-line
requests off the manager.

> **Published for portfolio review, not for reuse.**
>
> Client-identifying details are removed (client name, the Google Sheet id, account
> names). Prompt texts live in a database table and are not published.

## Context & problem

The client is a cinema-industry service (Digital Cinema Package). First-line client
consultations were handled by the manager by hand. There was also no fixed spec — the
request kept changing — so a scenario hard-coded into a prompt would go stale fast. The
solution had to survive rule changes without being rebuilt.

## Solution

A Telegram agent on self-hosted n8n.

### Key decisions

- **Knowledge separated from logic.** The service catalog and pricing rules live in
  Google Sheets / PostgreSQL and are loaded by the agent at run time. Changing a rule or
  adding a service does not require touching the workflow.
- **Per-request memory.** Context is kept separately per client: the request key is a
  truncated SHA-256 (`hash / user_id`) over Postgres Memory (depth ~90). One structure
  covers agent context, the window limit, logging and analytics at once; filtering by
  `user_id` returns a client's full history with one SQL query. This removed the
  "mixed-up dialogs" problem under parallel requests. The working context resets on
  request, on the agent's confirmation, or on inactivity timeout — logs are kept.
- **Prompts as data.** The agent prompt is read from a `prompt_library` table, not from
  the AI node (texts are not published here).
- **Explicit escalation on uncertainty.** On edge cases the agent does not improvise — it
  hands the request to a human. The cost of a wrong answer about paid services is higher
  than the gain from a "confident" guess.
- **Self-improvement loop.** When the manager spots a wrong or doubtful answer, it is
  logged into a PostgreSQL issue tracker and handled (manually or by a separate
  human-in-the-loop agent), so fixes go through a durable loop with history — not one-off
  prompt edits.

### Engineering lesson (pilot trade-off)

In the pilot I over-engineered for model quality — a heavier model for accuracy, which
gave ~16s per answer. Wrong trade-off for a pilot. Principle for next time:
**pilot → speed and UX; scaling → architecture.**

## Data model

- **dcp_sessions** — one row per request (session id, telegram user, memory key, status).
- **dcp_chat_history** — the Postgres Memory store (per-request context).
- **issue_tracking** — manager-logged corrections (the self-improvement loop).
- **prompt_library** *(shared, structure only)* — agent prompts as data.

See [`/schema`](schema) for the sanitized DDL and notes.

## Results

- Pilot removed **~60%** of first-line requests from the manager on several topics.
- Pilot scale: **~10 real test requests**; ~1 week pilot + ~1.5 months of support.
- Freed time went to complex consultations; quality held thanks to explicit escalation.
- Rules and catalog changed live, without rebuilding the workflow.

## Possible next steps

- A curator agent that classifies issue-tracker items and proposes catalog/rule edits
  automatically, with a human confirming.
- Objective quality metrics: escalation rate, repeat-question rate, time-to-resolution.
- Move the catalog from Excel into versioned PostgreSQL tables.

## Repository structure

| Path | What |
|---|---|
| [`/workflows`](workflows) | sanitized n8n workflow JSON (the assistant) |
| [`/schema`](schema) | sanitized PostgreSQL DDL + notes |
| [`/assets`](assets) | architecture diagram + screenshots |
| [`.env.example`](.env.example) | names of the secrets to configure |

## Note on secrets

Secrets live in n8n's encrypted credential store, separated from workflow logic. The
exported JSON references credentials by name only. The Google Sheet id (the client's
catalog) was replaced with a placeholder, prompt texts are kept in the database, and
client-identifying names were removed.

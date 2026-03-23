# Overview

## What You Built

An AI-powered candidate pre-screening platform. A candidate visits a job page, uploads their CV (PDF, Markdown, or plain text), and the system automatically evaluates it against a job-specific criteria document using Claude. The result — a scored summary with gaps and follow-up questions — is ready for a recruiter without any manual screening.

**What's working end-to-end (Stage 1 — proof of concept):**

1. Candidate submits CV via a file upload or pasted text
2. The system extracts the CV content (Claude reads PDFs and converts them to Markdown)
3. Claude evaluates the CV against the job's evaluation scenario
4. The candidate sees a live status page that polls for progress
5. When evaluation completes, the result (pass / partial / fail, score, summary, gaps, follow-up questions) is displayed

---

## What Concept You Chose to Redesign

**Traditional CV screening** — the process where a recruiter manually reads CVs, compares them against a job description, and makes a subjective shortlisting decision.

This is typically the most time-consuming and inconsistency-prone part of hiring. Every recruiter interprets the same criteria differently, the same candidate gets a different outcome depending on who reads their CV that day, and the process doesn't scale.

The redesign replaces the manual read-and-judge step with a structured, AI-driven evaluation loop driven by a declarative **Scenario** document — a single source of truth that defines what a good candidate looks like for this role.

---

## Problem

### What problem you're solving

Recruiters spend a disproportionate amount of time on early-stage screening — reading CVs that don't meet the brief, manually cross-referencing skill requirements, and forming inconsistent shortlists. For high-volume roles, this is a bottleneck that delays hiring and introduces bias.

### Why it matters

- **Scale:** A recruiter can meaningfully review ~20–30 CVs per day. An AI system can process hundreds in minutes.
- **Consistency:** The same Scenario document is applied to every candidate — there's no "Friday afternoon" problem.
- **Signal quality:** The system doesn't just pass/fail — it outputs structured gaps and follow-up questions that make the recruiter's job easier even when the decision is marginal.
- **Speed:** Candidates get a faster response; recruiters spend their attention on candidates who already cleared a baseline.

---

## Approach

### How your solution works

```
CV Upload
  └─ ProcessCvJob
       ├─ PDF → Claude (extract to Markdown)
       └─ Text/MD → read directly
            └─ EvaluateCvJob
                 ├─ CV text + Scenario → Claude
                 └─ Structured JSON result stored on Candidate
```

**Key components:**

| Component | Role |
|---|---|
| `Scenario` | Declarative evaluation document. Defines required/preferred criteria and instructs Claude how to score. |
| `CvProcessor` | Extracts raw text from the uploaded file. PDFs go to Claude; plain text is read directly. |
| `CvEvaluator` | Sends CV text + Scenario to Claude. Gets back a JSON blob: overall, score, summary, gaps, questions. |
| `ProcessCvJob` / `EvaluateCvJob` | Solid Queue background jobs that run the pipeline. Retry on transient API errors. |
| `Candidate` state machine | Statesman-powered: `cv_processing → ready_for_evaluating → evaluating → evaluated`. Status column kept in sync for fast reads. |
| Status polling | Stimulus controller polls a JSON endpoint every 2.5 s. When the state reaches a terminal value, the UI renders the result. |

### Key design decisions

**1. The Scenario is the only source of truth.**
There is no separate business logic for evaluation. The Scenario document tells Claude what to look for, how to weight it, and what constitutes automatic rejection. To change evaluation criteria, you update the Scenario — no code changes required.

**2. Claude reads PDFs directly.**
Rather than integrating a PDF parser library and dealing with layout, tables, and encoding edge cases, the PDF is base64-encoded and sent to Claude as a document block. Claude extracts the content into clean Markdown. This handles unusual PDF layouts better than any rule-based parser would.

**3. Statesman for state management.**
The `Candidate` lifecycle has real business rules (you can't evaluate before extracting, you can't interview before evaluating). A state machine makes illegal transitions impossible at the model level, and the transition history is auditable. `statesman_scaffold` generates the boilerplate so the focus stays on the states and transitions themselves.

**4. Job-level retry on transient API errors.**
Rate limits and server errors from Anthropic are handled at the job level with `retry_on` and exponential backoff — not inside the service. Services raise, jobs decide what to do with the error. Billing errors are discarded immediately (retrying won't help).

**5. inquiry_attrs for status predicates.**
`candidate.status.evaluated?` reads more clearly than `candidate.status == 'evaluated'` and is nil-safe. Given how often status is checked across the codebase, the predicate style pays for itself quickly.

---

## AI Usage

### How you used AI

**Claude (Anthropic) is used for three things in this build:**

1. **PDF → Markdown extraction** (`CvProcessor`): Claude receives the raw PDF bytes and is instructed to extract all CV content into clean Markdown. No rule-based parsing.

2. **CV evaluation** (`CvEvaluator`): Claude receives the extracted CV text and the full Scenario document. It returns a structured JSON object with an overall verdict, a 0–100 score, a recruiter-facing summary, a list of gaps, and follow-up questions for the interview stage.

3. **Development tooling**: Claude Code (claude-sonnet-4-6) was used extensively to scaffold this build — generating models, migrations, services, jobs, state machine configuration, tests, and this document.

### Why you chose this approach

The entire value proposition depends on nuanced reading of unstructured text (a CV) against semi-structured criteria (the Scenario). A rules-based system would be brittle and require ongoing maintenance for every new job description format. Claude handles the semantic reasoning; the Scenario handles the domain logic. That separation keeps the system simple.

The model used is `claude-opus-4-6` for both extraction and evaluation. In a production system you'd likely use Haiku for extraction (deterministic task, cheap) and Sonnet or Opus for evaluation (reasoning-heavy).

---

## Tradeoffs & Limitations

### What doesn't work well yet

- **No interview stage (Stage 2)**: The follow-up questions are generated but not yet acted on. Stage 2 (the AI interview loop) is designed but not built.
- **No recruiter view**: There is no admin interface. Evaluation results are visible on the candidate-facing status page but not aggregated anywhere for recruiters.
- **Single job only**: The seed data creates one job. The routing supports `job_id`, but there's no job listing or selection UI.
- **Development mode runs jobs inline**: To avoid needing a running Solid Queue process, `ProcessCvJob` and `EvaluateCvJob` use `perform_now` in development. This blocks the HTTP request until the entire pipeline completes (typically 10–30 seconds for PDF + evaluation). In production, `perform_later` is used.
- **No authentication**: Anyone with the URL can submit a CV or view a result.
- **Evaluation result display is minimal**: The status page shows the raw structured data. A polished recruiter summary card is designed but not yet wired to the real result.

### Where this might fail

- **Malformed Claude responses**: The evaluator validates the JSON structure and raises on unexpected output, but Claude occasionally adds commentary outside the JSON even when instructed not to. The markdown fence stripper handles the most common case, but edge cases exist.
- **Large PDFs**: Files over 32 MB are rejected. Files close to that limit may hit Claude's token limits mid-extraction.
- **Credit exhaustion**: The pipeline fails hard if the Anthropic account runs out of credits. The job discards (rather than retries) billing errors, which is correct but means candidates get stuck in `cv_processing` with no visible error.
- **Concurrency**: If two jobs for the same candidate run simultaneously, the state machine will raise `Statesman::TransitionFailedError` on the second one. This is protected by unique indexes on the transitions table but could leave a candidate in a mid-transition state.

---

## Next Steps

Given more time, the priority order would be:

1. **Stage 2 — AI interview loop**: The Scenario already outputs follow-up questions. Wire those into a conversational UI (Turbo Streams for real-time messages, Claude for question generation and answer evaluation, ElevenLabs for voice output).

2. **Recruiter dashboard**: List candidates per job, show their score and verdict, link to the full evaluation. Basic auth is enough for an MVP.

3. **Error recovery for stuck candidates**: A background sweep that identifies candidates stuck in `cv_processing` or `evaluating` for more than N minutes and either retries or marks them failed with a user-facing message.

4. **Async in development**: Switch to `perform_later` in all environments and add a note to `README` about running Solid Queue. The inline `perform_now` in development makes the UX feel broken.

5. **Scenario editor**: Let a recruiter edit the Scenario document in the admin UI without a code deploy. The entire evaluation logic lives in that document — making it editable unlocks the system for non-engineers.

6. **Model cost optimisation**: Use Haiku for PDF extraction, Sonnet for evaluation. Opus is overkill for extraction and adds cost and latency.

---

## Setup Instructions

### Prerequisites

- Ruby (see `.ruby-version` or `mise.toml`)
- Node.js 22 LTS + Yarn
- `mise` (tool version manager) — `brew install mise`

### Environment variables

```bash
cp config/application.sample.yml config/application.yml
```

Edit `config/application.yml` and set:

```yaml
ANTHROPIC_API_KEY: "sk-ant-..."   # required — get from console.anthropic.com/settings/keys
ELEVENLABS_API_KEY: "..."          # optional — only needed for Stage 2 voice output
```

### Install and run

```bash
./bin/setup       # install Ruby gems + JS packages + prepare database
mise up           # start Rails + Vite + Caddy via Overmind
```

App runs at **`https://apl.localhost`** (Caddy reverse proxy with local TLS).

To stop: `mise down`

### Run tests

```bash
bin/rails test                     # all unit + integration tests
bin/rails test test/models         # model tests only
bin/rails test test/services       # service tests only
bin/rails test test/jobs           # job tests only
```

### Seed data

The seed creates one active job (Senior Rails Engineer) with a full evaluation Scenario:

```bash
bin/rails db:seed
```

---

## Evaluation notes

This build prioritises **working end-to-end logic over polished UI**. The CV upload, extraction, AI evaluation, and live status polling all work. The UI is functional but not final. Mocking and stubbing are used in tests (WebMock for Anthropic HTTP calls). Claude Code was used extensively throughout development — for scaffolding, debugging, writing tests, and generating this document.

## Time spent

- Idea & design: ~1h
- Development of the stage 1 prototype: ~5h

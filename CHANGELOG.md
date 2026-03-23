# Changelog

## [Unreleased] — Stage 1: CV Upload & AI Screening (Proof of Concept)

### What was built

The first working end-to-end stage of the AI screening pipeline:

**CV Upload flow**
- Candidate submits their name, email, and a CV file (PDF, Markdown, or plain text) via the application form
- Active Storage handles file upload and attachment to the `Candidate` record
- On submission the app immediately redirects to a live status page that polls for progress

**Background processing pipeline**
- `ProcessCvJob` downloads the attached file and extracts its text content:
  - PDFs are sent to the Claude API (claude-opus-4-6) which returns clean Markdown
  - Plain text / Markdown files are read directly
- `EvaluateCvJob` sends the extracted text plus the job's evaluation scenario to Claude, which returns a structured JSON result (overall pass/partial/fail, score 0–100, summary, skill gaps, follow-up questions)
- Both jobs include retry logic for transient Anthropic API errors (rate limits, server errors, connection failures) and discard on non-retryable billing/auth errors

**State machine (`Candidate` status)**
- Powered by Statesman via the `statesman_scaffold` gem
- States: `cv_processing → ready_for_evaluating → evaluating → evaluated` (plus future `interviewing`, `completed`, `accepted`, `rejected`)
- The `status` column is kept in sync after every transition via an `after_transition` callback
- `inquiry_attrs` adds nil-safe predicate methods: `candidate.status.cv_processing?`, `candidate.status.evaluated?`, etc.

**Job model**
- Added `Job.active` / `Job.closed` named scopes
- `job.status.active?` predicate available via `inquiry_attrs`

### Key gems added

| Gem | Purpose |
|-----|---------|
| `statesman` | State machine engine |
| `statesman_scaffold` | Generator + `with_state_machine` macro |
| `inquiry_attrs` | Nil-safe predicate methods on string attributes |
| `anthropic` | Claude API client |
| `pdf-reader` | PDF text extraction fallback |
| `figaro` | Environment variable management via `config/application.yml` |

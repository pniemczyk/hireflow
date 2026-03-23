# AI-Powered Candidate Screening Platform

> MVP - Automated pre-screening system that processes CVs, evaluates candidates against job-specific scenarios, and delivers scored summaries for recruiters.

---

## Project Overview

Rails application that automates candidate screening. A candidate uploads their CV, the system evaluates it against a job Scenario using AI, optionally conducts an AI-driven interview to fill gaps, and produces a scored summary for the recruiter.

---

## Core Concept

```
Candidate uploads CV  -->  AI evaluates against Scenario  -->  AI interview (if needed)  -->  Scored summary for recruiter
```

---

## Candidate Evaluation Flow (Simplified, AI-Driven)

### 1. Scenario-Driven Validation (Stage 1)

- Each job defines a **Scenario** (structured prompt / rule set).
- The Scenario is the **single source of truth** for evaluation logic.
- No additional business logic or hardcoded validation rules.

**Flow:**
1. Input: Candidate CV (raw or parsed).
2. Pass CV data + Scenario -> AI.
3. AI evaluates:
   - skills match
   - experience relevance
   - required criteria
4. Output:
   - structured validation result (pass / partial / fail)
   - missing data signals
   - follow-up questions (if needed)

---

### 2. Iterative Data Collection (Stage 2)

- If validation is incomplete -> enter **AI-driven loop**.

**Loop:**
- AI generates targeted questions based on:
  - Scenario requirements
  - missing / weak signals from CV
- Candidate provides answers
- AI re-evaluates context

**Constraints:**
- max 3 attempts per question
- if still insufficient -> mark as **failed / unknown**

---

### 3. Conversation Persistence

- Every interaction is stored as structured conversation:

```json
{
  "candidate_id": "...",
  "job_id": "...",
  "messages": [
    { "role": "ai", "content": "question" },
    { "role": "candidate", "content": "answer" }
  ],
  "state": "in_progress | completed | failed"
}
```

---

### 4. Aggregation Layer

- After loop completion, aggregate all signals:
  - CV data
  - AI evaluations
  - conversation responses

- Produce **Final Candidate Profile**:

```json
{
  "score": 0.0,
  "skills": [],
  "experience": {},
  "gaps": [],
  "confidence": 0.0,
  "decision": "accept | reject | review"
}
```

---

### 5. Review Stage

- Final profile is passed to recruiter:
  - full conversation history
  - AI reasoning
  - structured summary

---

## Key Principles

- **Scenario** = declarative evaluation layer
- **AI** = execution engine (no duplicated logic)
- **Conversation** = source of truth
- Loop until:
  - sufficient data OR
  - failure threshold reached

---

## User Flows

### Flow A: Candidate (Happy Path)

```
1. Candidate lands on job page
2. Uploads CV (PDF/MD) or pastes text
3. AI evaluates CV against Scenario
4. CV passes -> AI interview begins (if gaps exist)
5. Candidate answers targeted questions
6. Interview ends -> "Thank you, we will be in touch"
7. Recruiter receives scored summary
```

### Flow B: Candidate (Rejection after CV)

```
1-3. Same as above
4. CV fails Scenario criteria -> candidate sees rejection message
```

### Flow C: Candidate (Rejection after AI Interview)

```
1-5. Same as Flow A
6. Score too low or failure threshold reached -> rejection message
```

### Flow D: Recruiter

```
1. Recruiter logs in to admin panel
2. Views candidates per job opening
3. Sees scored summaries: overall score, gaps, AI reasoning
4. Makes final decision (invite / reject)
```

---

## Data Model

```
Job
  - title
  - description
  - status (active / closed)

Scenario
  - job_id (FK)
  - content (text/markdown - the full scenario document)
  - version

Candidate
  - name
  - email
  - job_id (FK)
  - status (new / evaluating / interviewing / completed / accepted / rejected)
  - cv_file (attachment)
  - cv_raw_text

Conversation
  - candidate_id (FK)
  - job_id (FK)
  - state (in_progress / completed / failed)
  - started_at
  - completed_at

Message
  - conversation_id (FK)
  - role (ai / candidate)
  - content
  - metadata (JSON - evaluation signals, flags)
  - timestamp

CandidateProfile (final output)
  - candidate_id (FK)
  - job_id (FK)
  - score
  - skills (JSON)
  - experience (JSON)
  - gaps (JSON)
  - confidence
  - decision (accept / reject / review)
  - summary (JSON - full recruiter summary)
  - ai_reasoning (JSON)
```

---

## Pages / Routes

| Route                              | Purpose                              | Auth        |
|------------------------------------|--------------------------------------|-------------|
| `GET /jobs/:id/apply`              | CV upload page                       | Candidate   |
| `POST /jobs/:id/apply`             | Submit CV                            | Candidate   |
| `GET /jobs/:id/apply/processing`   | Processing screen (polls for result) | Candidate   |
| `GET /jobs/:id/apply/interview`    | AI interview chat                    | Candidate   |
| `POST /jobs/:id/apply/interview`   | Send message in interview            | Candidate   |
| `GET /jobs/:id/apply/result`       | Result screen                        | Candidate   |
| `GET /admin/jobs`                  | Recruiter - list jobs                | Recruiter   |
| `GET /admin/jobs/:id/candidates`   | Recruiter - list candidates for job  | Recruiter   |
| `GET /admin/candidates/:id`        | Recruiter - candidate detail         | Recruiter   |
| `GET /admin/scenarios/:id`         | Recruiter - view/edit scenario       | Recruiter   |

---

## Tech Stack

| Layer              | Technology                          | Notes                              |
|--------------------|-------------------------------------|------------------------------------|
| **Framework**      | Rails 8                             | Hotwire / Turbo / Stimulus         |
| **Frontend**       | Hotwire + Stimulus                  | Turbo Frames for chat, Turbo Streams for real-time |
| **CSS**            | Tailwind CSS                        |                                    |
| **Database**       | PostgreSQL                          |                                    |
| **AI**             | Claude AI (Anthropic API)           | Single engine for all evaluation   |
| **Text-to-Speech** | ElevenLabs API                      | Optional voice for interview       |
| **Deployment**     | Kamal                               |                                    |

---

## AI Prompts Architecture

All AI interactions are driven by the Scenario. No separate hardcoded prompts per stage.

### Prompt 1: CV Evaluation
- Input: raw CV text + Scenario
- Task: evaluate candidate against Scenario criteria
- Output: structured validation result + missing data signals + follow-up questions

### Prompt 2: Interview Conductor
- Input: Scenario + conversation history + current gaps
- Task: generate targeted questions to fill gaps
- Output: next question + evaluation of previous answer

### Prompt 3: Summary Generator
- Input: all conversation messages + all evaluation signals
- Task: aggregate into final candidate profile
- Output: scored summary matching `CandidateProfile` schema

---

## File Structure

```
app/
  controllers/
    applications_controller.rb      # Candidate-facing: upload, interview, result
    admin/
      jobs_controller.rb            # Recruiter: manage jobs
      candidates_controller.rb      # Recruiter: view candidates + summaries
      scenarios_controller.rb       # Recruiter: view/edit scenarios
  models/
    job.rb
    scenario.rb
    candidate.rb
    conversation.rb
    message.rb
    candidate_profile.rb
  services/
    cv_extractor.rb                 # Parse PDF/MD -> raw text
    scenario_evaluator.rb           # AI: evaluate CV against Scenario
    interview_conductor.rb          # AI: manage interview conversation loop
    profile_aggregator.rb           # AI: generate final candidate profile
    elevenlabs_client.rb            # TTS API integration
  views/
    applications/
      new.html.erb                  # CV upload
      processing.html.erb           # Waiting screen
      interview.html.erb            # Chat interface
      result.html.erb               # Pass/reject
    admin/
      ...
  javascript/
    controllers/
      file_upload_controller.js     # Drag-and-drop, file validation
      interview_controller.js       # Chat UI, message sending
      voice_controller.js           # ElevenLabs playback

config/
  scenarios/                        # Default scenario files
    candidate_interview_scenario.md

design/
  1_CV_upload/
  2_AI_interview/
```

---

## MVP Scope

### In Scope
- Single job opening
- CV upload (PDF, MD, text)
- Synchronous CV processing
- AI-driven evaluation against Scenario
- Iterative interview loop (max 3 attempts per question)
- Conversation persistence
- Scored summary generation
- Automated pass/reject decision
- Basic recruiter view

### Out of Scope (MVP)
- OAuth / authentication
- Email notifications
- Async processing
- Human-in-the-loop decisions
- Multiple concurrent jobs
- Scenario editor UI
- Voice input from candidate
- Session resume
- Analytics

---

## Getting Started

```bash
# Prerequisites
# - Ruby 3.x
# - PostgreSQL
# - Node.js

# Setup
# bin/setup

# External Services
# - Claude API key (AI evaluation)
# - ElevenLabs API key (optional, text-to-speech)
```

---

## References

- Interview Scenario: `candidate_interview_scenario.md`
- Design: `design/1_CV_upload/`, `design/2_AI_interview/`

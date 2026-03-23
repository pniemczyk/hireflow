# API Specification

This is the API specification for the spec detailed in @.agent-os/specs/2026-03-23-ai-interview-stage2/spec.md

> Created: 2026-03-23
> Version: 1.0.0

---

## Routes

```ruby
# Candidate-facing interview
get  'jobs/:job_id/apply/interview',          to: 'applications#interview',       as: :job_application_interview
post 'jobs/:job_id/apply/interview/messages', to: 'applications#create_message',  as: :job_application_messages

# Result screen
get  'jobs/:job_id/apply/result',             to: 'applications#result',          as: :job_application_result

# TTS synthesize — promoted from dev-only to standard route
post 'tts/synthesize',                        to: 'tts#synthesize',               as: :tts_synthesize
```

---

## Endpoints

### GET /jobs/:job_id/apply/interview

**Purpose:** Renders the interview chat UI for a candidate.

**Parameters:**
- `job_id` — URL param
- `candidate_id` — query param

**Behaviour:**
- Loads `@candidate` from `job.candidates.find(candidate_id)`
- Guards: candidate must be in `interviewing` state; otherwise redirect to status page
- Finds or creates `@conversation` for the candidate
- If conversation has no messages yet → calls `InterviewConductor` to generate the opening AI message and first question, saves it as a `Message(role: :ai)`
- Assigns `@messages = @conversation.messages.order(:position)`
- Renders `applications/interview`

**Response:** HTML

---

### POST /jobs/:job_id/apply/interview/messages

**Purpose:** Accepts a candidate answer, calls Claude, returns the AI reply via Turbo Stream.

**Parameters:**
- `job_id` — URL param
- `candidate_id` — body param
- `content` — body param (the candidate's answer text)

**Behaviour:**
1. Load candidate (must be `interviewing`)
2. Load conversation
3. Create `Message(role: :candidate, content: content, position: next)`
4. Call `InterviewConductor.new(candidate).call`
5. Create `Message(role: :ai, content: result[:content], metadata: result.slice(:question_index, :attempt, :complete), position: next)`
6. If `result[:complete]`:
   - Save `candidate.interview_summary = result[:summary].to_json`
   - `candidate.transition_to!(:completed)`
   - Set `candidate.status` to `accepted` or `rejected` based on summary overall (for now: `pass/partial → accepted`, `fail → rejected`)
7. Respond with `turbo_stream.erb`

**Response:** `text/vnd.turbo-stream.html`

Turbo Stream actions:
- `turbo_stream.append "messages"` — candidate message bubble
- `turbo_stream.append "messages"` — AI message bubble (with `data-autoplay` attribute)
- `turbo_stream.replace "interview-input"` — clears the textarea
- If complete: `turbo_stream.replace "interview-frame"` — shows completion screen

**Error:** `422 Unprocessable Entity` with `turbo_stream.replace "interview-error"` if validation fails.

---

### GET /jobs/:job_id/apply/result

**Purpose:** Shows the final result screen (thank you / pass / rejection message).

**Parameters:**
- `job_id` — URL param
- `candidate_id` — query param

**Behaviour:**
- Loads candidate; must be in `completed`, `accepted`, or `rejected` state
- Renders `applications/result`

**Response:** HTML

---

### POST /tts/synthesize

**Purpose:** Proxies text to ElevenLabs and returns `audio_base64` + `alignment`. Promoted from dev-only to standard route (API key stays server-side).

**Parameters:**
- `text` — body param (string)

**Response:**
```json
{
  "audio_base64": "...",
  "alignment": {
    "characters": [...],
    "character_start_times_seconds": [...],
    "character_end_times_seconds": [...]
  }
}
```

**Error:** `422` with `{ "error": "..." }`

---

## Controllers

### `ApplicationsController` — new actions

```ruby
def interview
  # load candidate, guard state, find_or_create conversation,
  # generate opening message if none, render
end

def create_message
  # accept answer, run InterviewConductor, append messages,
  # handle completion, respond with turbo_stream
end

def result
  # load candidate, render result view
end
```

### `TtsController` (new, non-namespaced)

Extracted from `Dev::TextToSpeechController`. Identical `synthesize` logic, available in all environments.

`Dev::TextToSpeechController` delegates to `TtsController` or is updated to use the shared route.

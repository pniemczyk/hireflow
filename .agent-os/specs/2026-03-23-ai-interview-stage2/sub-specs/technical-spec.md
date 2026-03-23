# Technical Specification

This is the technical specification for the spec detailed in @.agent-os/specs/2026-03-23-ai-interview-stage2/spec.md

> Created: 2026-03-23
> Version: 1.0.0

---

## Technical Requirements

- Rails 8.1 with SQLite, Solid Queue, Turbo Streams, Stimulus
- No WebSockets required — synchronous request/response per message is sufficient for MVP
- ElevenLabs TTS reuses the `tts_controller.js` Stimulus controller from the dev prototype
- Claude (`claude-opus-4-6`) powers `InterviewConductor`; inherits `AnthropicClient` mixin
- Interview job inherits `AnthropicJob` for shared retry/discard policy
- UI follows `materials/design/2_AI_interview/` Ethereal Agent dark design system

---

## Architecture

### Data flow per message

```
Candidate submits answer (POST)
  → ApplicationsController#create_message
    → Conversation.find_or_create (for this candidate)
    → Message.create(role: :candidate, content: answer)
    → InterviewConductor.new(candidate).call
        → builds prompt: Scenario + eval gaps + full conversation history
        → calls Claude API
        → returns { action: :question|:follow_up|:close, content: "...", complete: bool }
    → Message.create(role: :ai, content: ai_response.content)
    → if ai_response.complete → candidate.transition_to!(:completed), store interview_summary
  → respond with turbo_stream: append new messages + (if done) redirect frame
```

### `InterviewConductor` service

Single `.call` interface. Inputs: `candidate` (with `evaluation` result and `job.scenario`).

**Prompt strategy:**

```
System context: "You are an AI technical interviewer conducting a structured interview..."

Scenario: <full scenario content>

CV Evaluation result:
  - overall: partial
  - score: 62
  - gaps: ["No evidence of Hotwire/Stimulus", "Background job experience unclear"]
  - questions: ["Describe your experience with background job processing..."]

Conversation history:
  [ai]: <previous question>
  [candidate]: <previous answer>
  ...

Instructions:
  - If no messages yet: generate a warm opening + first question
  - If candidate just answered: evaluate the answer against the Scenario criterion
    - sufficient → acknowledge, move to next question (or close if all done)
    - insufficient → ask a follow-up (max 3 attempts per question, then mark as unresolved)
  - If coding task required by scenario: pose the task clearly, evaluate submitted code as text
  - When all questions resolved or failure threshold reached: generate closing message

Return JSON:
  {
    "content": "<AI message text>",
    "complete": false,
    "question_index": 1,
    "attempt": 1,
    "summary": null   // populated only when complete=true
  }
```

**Interview completion summary** (when `complete: true`):
```json
{
  "overall": "pass|partial|fail",
  "score": 0-100,
  "answers": [{ "question": "...", "answer": "...", "verdict": "sufficient|insufficient" }],
  "summary": "..."
}
```

This summary is stored in `candidates.interview_summary` (new column, JSON text).

### State machine changes

Add to `Candidate::StateMachine`:
- `evaluated → interviewing` (enters interview)
- `evaluated → accepted` (clean pass, no interview needed)
- `evaluated → rejected` (clean fail)
- `interviewing → completed` (all questions resolved)
- `completed → accepted` / `completed → rejected` (future recruiter decision; for now auto-set from interview summary)

**Auto-routing logic in `ApplicationsController#status`:**
```ruby
# When polled and state == 'evaluated':
evaluation = candidate.evaluation
if evaluation[:overall] == 'fail'
  candidate.transition_to!(:rejected)
  render json: { ..., redirect_to: result_path }
elsif evaluation[:overall] == 'pass' && evaluation[:questions].empty?
  candidate.transition_to!(:accepted)
  render json: { ..., redirect_to: result_path }
else
  # partial or pass-with-questions → interview
  candidate.transition_to!(:interviewing)
  render json: { ..., redirect_to: interview_path }
end
```

### Conversation model

- `belongs_to :candidate`
- `has_many :messages`
- `state`: `in_progress | completed | failed`
- One conversation per candidate (find_or_create)

### Message model

- `belongs_to :conversation`
- `role`: enum `ai | candidate`
- `content`: text
- `metadata`: JSON text (attempt number, question_index, verdict, etc.)
- `position`: integer for ordering (auto-incremented)

### TTS integration

The interview view renders AI messages with a `data-tts-autoplay="true"` attribute on the latest AI message span. The `tts_controller.js` is extended with an `autoplay` value — when `true` and a new AI message is appended via Turbo Stream, the controller automatically triggers synthesis and playback. The synthesize endpoint is the existing `/dev/text_to_speech/synthesize` but promoted to a non-dev route: `POST /tts/synthesize`.

### Turbo Stream response

On message submission, the controller responds with a `turbo_stream.erb` that:
1. Appends the candidate message bubble to `#messages`
2. Appends the AI message bubble to `#messages`
3. Clears the input textarea
4. If `complete: true` — replaces `#interview-frame` with the completion partial

---

## Approach Options

**Option A: Full async (Solid Queue job per message)**
- Pros: Non-blocking request, progress indicator possible
- Cons: Requires polling or ActionCable; more infrastructure; adds latency UX complexity

**Option B: Synchronous inline (Selected)**
- Pros: Simple, no queue needed, immediate response, no extra infrastructure
- Cons: Request blocks for ~3–8s while Claude responds — acceptable for interview pacing (natural pause while "AI thinks")

**Rationale:** Interview pacing naturally accommodates a few seconds of latency. A subtle "AI is thinking…" spinner during the request is sufficient UX. Sync keeps the implementation simple and matches the existing CV processing pattern in development.

---

## External Dependencies

No new gems required. Uses existing:
- `anthropic` gem — already installed
- `statesman_scaffold` — already installed
- Turbo (via `importmap` / Vite) — already installed

The TTS synthesize endpoint is promoted from dev-only to a standard route (still proxy-based, key stays server-side).

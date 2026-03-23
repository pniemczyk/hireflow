# Tests Specification

This is the tests coverage details for the spec detailed in @.agent-os/specs/2026-03-23-ai-interview-stage2/spec.md

> Created: 2026-03-23
> Version: 1.0.0

---

## Test Coverage

### Unit Tests

**`Conversation`**
- `belongs_to :candidate`
- `has_many :messages` ordered by position
- validates state inclusion

**`Message`**
- `belongs_to :conversation`
- validates role inclusion (`ai`, `candidate`)
- `#metadata_hash` returns parsed JSON
- position increments correctly within a conversation

**`Candidate`**
- `has_one :conversation`
- `#interview_summary_hash` returns parsed JSON (mirrors `#evaluation`)
- state transitions: `evaluated → interviewing`, `interviewing → completed`

**`InterviewConductor`**
- `.call` raises `Error` when candidate has no evaluation result
- `.call` raises `Error` when job has no scenario
- `.call` returns hash with required keys (`content`, `complete`, `question_index`, `attempt`, `summary`)
- when `complete: false` — `summary` is nil
- when `complete: true` — `summary` contains `overall`, `score`, `answers`, `summary` keys
- `complete: true` is returned when all questions resolved
- `complete: true` with `overall: fail` when failure threshold exceeded
- Anthropic API errors bubble up (no rescue — handled by `AnthropicJob`)

**`TtsController`**
- `POST /tts/synthesize` with blank text returns 422
- `POST /tts/synthesize` with valid text calls ElevenLabs and returns audio_base64 + alignment (WebMock stub)
- `POST /tts/synthesize` when ElevenLabs returns non-200 returns 422 with error message

---

### Integration Tests

**`ApplicationsController` — interview flow**
- `GET interview` with candidate not in `interviewing` state redirects to status page
- `GET interview` with fresh candidate in `interviewing` state creates opening AI message and renders page
- `GET interview` with existing conversation messages does not re-generate opening
- `POST create_message` appends candidate message and AI response to conversation
- `POST create_message` responds with Turbo Stream
- `POST create_message` when AI returns `complete: true` transitions candidate to `completed`
- `POST create_message` when AI returns `complete: true` with `fail` transitions to `rejected`
- `POST create_message` with blank content returns 422

**`ApplicationsController` — status auto-routing**
- `GET status` when state is `evaluated` with `fail` transitions to `rejected` and returns redirect JSON
- `GET status` when state is `evaluated` with `pass` and no questions transitions to `accepted` and returns redirect JSON
- `GET status` when state is `evaluated` with `partial` transitions to `interviewing` and returns interview redirect JSON

**`ApplicationsController` — result**
- `GET result` with `completed` candidate renders result view
- `GET result` with candidate not in terminal state redirects to status page

---

### Mocking Requirements

- **Anthropic API (`InterviewConductor`):** WebMock stub on `https://api.anthropic.com/v1/messages` returning a valid JSON interview response fixture.
- **ElevenLabs API (`TtsController`):** WebMock stub on `https://api.elevenlabs.io/v1/text-to-speech/*/with-timestamps` returning `{ audio_base64: "...", alignment: { characters: [], ... } }`.
- **No real API calls** in any test — CI must pass without `ANTHROPIC_API_KEY` or `ELEVENLABS_API_KEY`.

---

### Test Fixtures / Factories

```ruby
# factories or create helpers needed:
create(:candidate, :evaluated)           # has evaluation_result JSON, state: evaluated
create(:candidate, :interviewing)        # state: interviewing, has conversation
create(:conversation, :with_messages)    # has 2 ai + 2 candidate messages
create(:message, role: :ai)
create(:message, role: :candidate)
```

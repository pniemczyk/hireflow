# Spec Tasks

These are the tasks to be completed for the spec detailed in @.agent-os/specs/2026-03-23-ai-interview-stage2/spec.md

> Created: 2026-03-23
> Status: Ready for Implementation

## Tasks

- [x] 1. Database — `conversations`, `messages`, `interview_summary`
  - [x] 1.1 Write model tests for `Conversation` and `Message` (associations, validations, ordering)
  - [x] 1.2 Write migration: `create_conversations`
  - [x] 1.3 Write migration: `create_messages`
  - [x] 1.4 Write migration: `add_interview_summary_to_candidates`
  - [x] 1.5 Create `Conversation` model with associations, validations, and `state` enum
  - [x] 1.6 Create `Message` model with `role` enum, `metadata_hash` helper, auto-position
  - [x] 1.7 Extend `Candidate` model: `has_one :conversation`, `interview_summary_hash` helper
  - [x] 1.8 Verify all model tests pass

- [x] 2. `InterviewConductor` service
  - [x] 2.1 Write unit tests for `InterviewConductor` (WebMock Anthropic stub, all response cases)
  - [x] 2.2 Create `app/services/interview_conductor.rb` inheriting `AnthropicClient`
  - [x] 2.3 Implement prompt builder: Scenario + eval result + conversation history
  - [x] 2.4 Implement response parser + validator (required JSON keys, `complete` logic)
  - [x] 2.5 Verify all `InterviewConductor` tests pass

- [x] 3. TTS route promotion
  - [x] 3.1 Write controller tests for `TtsController#synthesize` (happy path + errors via WebMock)
  - [x] 3.2 Create `app/controllers/tts_controller.rb` (extract synthesize logic from `Dev::TextToSpeechController`)
  - [x] 3.3 Add `POST /tts/synthesize` to routes (non-dev)
  - [x] 3.4 Update `Dev::TextToSpeechController` to delegate to shared logic or point view at new route
  - [x] 3.5 Verify TTS tests pass

- [x] 4. State machine + status auto-routing
  - [x] 4.1 Write tests for new state transitions and status auto-routing behaviour
  - [x] 4.2 Add `evaluated → accepted/rejected` transitions to `Candidate::StateMachine`
  - [x] 4.3 Update `ApplicationsController#status`: auto-transition on `evaluated`, return `redirect_url` in JSON
  - [x] 4.4 Update `status_poll_controller.js` to follow `redirect_url` from status JSON
  - [x] 4.5 Verify state machine + routing tests pass

- [x] 5. Interview controller actions + Turbo Stream response
  - [x] 5.1 Write integration tests for `interview`, `create_message`, and `result` actions
  - [x] 5.2 Implement `ApplicationsController#interview` (load/guard/create opening message)
  - [x] 5.3 Implement `ApplicationsController#create_message` (append messages, run conductor, handle completion)
  - [x] 5.4 Implement `ApplicationsController#result`
  - [x] 5.5 Add routes for `interview`, `messages`, and `result`
  - [x] 5.6 Create `create_message.turbo_stream.erb` (append bubbles, clear input, completion swap)
  - [x] 5.7 Verify all controller tests pass

- [x] 6. Interview UI — Ethereal Agent chat view
  - [x] 6.1 Create `applications/interview.html.erb` using 2_AI_interview design (message thread + input)
  - [x] 6.2 Create message bubble partials: `_ai_message.html.erb` and `_candidate_message.html.erb`
  - [x] 6.3 Create `applications/result.html.erb` (thank-you / pass / rejection screen)
  - [x] 6.4 Create `interview_controller.js` Stimulus controller (submit on Enter, loading state, scroll to bottom)
  - [x] 6.5 Wire TTS click-to-play on AI messages: per-message state machine (idle/loading/playing/paused/ended) with word highlighting
  - [ ] 6.6 Smoke-test full candidate flow in browser: CV upload → eval → interview → completion

- [ ] 7. Final verification
  - [x] 7.1 Run full test suite (`bin/rails test`)
  - [x] 7.2 Run `bin/ci` (lint + security + tests)
  - [ ] 7.3 Manual browser test: partial CV → interview starts, voice plays, answers submitted, completion screen shown
  - [ ] 7.4 Manual browser test: failing CV → rejected without interview

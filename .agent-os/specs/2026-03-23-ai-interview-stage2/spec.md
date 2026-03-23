# Spec Requirements Document

> Spec: AI Interview — Stage 2 (Iterative Data Collection)
> Created: 2026-03-23
> Status: Planning

## Overview

After CV evaluation, candidates with gaps or a `partial` result enter an AI-driven interview loop where Claude asks targeted follow-up questions (including coding tasks and experience deep-dives) based on the Scenario and the identified gaps. Each candidate answer is validated by AI, stored in a conversation record, and contributes to the final evaluation. The interview is presented in the Ethereal Agent chat UI with ElevenLabs voice output for AI messages.

## User Stories

### Candidate: Complete the AI Interview

As a candidate, I want to answer targeted follow-up questions after my CV is evaluated, so that I can demonstrate skills or experience that wasn't clear from my CV alone.

After the status page shows "Evaluation complete", the candidate is redirected to the interview page. The AI greets them, then asks questions one at a time based on the gaps identified in Stage 1. Each AI message is spoken aloud via ElevenLabs. The candidate types their response and submits. The AI acknowledges the answer and either asks a follow-up (if the answer was insufficient) or moves to the next question. When all questions are addressed, the AI closes the interview with a thank-you message and the candidate sees a completion screen.

### Candidate: Coding Task

As a candidate, I want to be able to submit code as part of the interview, so that I can demonstrate technical ability when the Scenario requires it.

The AI poses a coding question in the chat. The candidate types their code (multiline) in the input area and submits. The AI evaluates the code response via Claude and responds with feedback or moves to the next question. No execution sandbox is needed — evaluation is AI-based.

### Recruiter: See Interview Data

As a recruiter, I want the candidate's interview answers stored alongside their evaluation result, so that I can see the full conversation history when reviewing a candidate.

The candidate's conversation and messages are persisted. The existing admin candidate detail view (future scope) will surface this data.

## Spec Scope

1. **Conversation + Message models** — persist the full interview as structured `conversations` + `messages` records linked to the candidate.
2. **`InterviewConductor` service** — Claude-powered service that receives the Scenario, evaluation gaps, and conversation history, then returns the next AI action (question, follow-up, or close).
3. **Interview page** — chat UI at `GET /jobs/:job_id/apply/interview` using the Ethereal Agent 2_AI_interview design, showing the message thread and a text input.
4. **Message submission** — `POST /jobs/:job_id/apply/interview/messages` accepts a candidate message, runs it through `InterviewConductor`, appends both messages, and returns the AI response via Turbo Stream.
5. **ElevenLabs TTS on AI messages** — each new AI message is automatically spoken via ElevenLabs using the same word-sync + waveform pattern from the dev prototype.
6. **State machine integration** — transition `evaluated → interviewing` when the interview starts; `interviewing → completed` when finished; attach the `interview_summary` to the candidate for downstream use.
7. **Auto-routing after evaluation** — once a candidate reaches `evaluated`, the status page redirects to the interview page (if `partial`/gaps present) or a result screen (if clean `pass` or `fail`).

## Out of Scope

- Recruiter admin view for conversation history (future)
- Voice input from candidate (future)
- Code execution / sandbox for coding tasks — AI evaluates code as text
- Session resume after browser close
- Email notifications
- Async job processing for interview messages (synchronous is fine for MVP)
- Multiple simultaneous questions (one question at a time)

## Expected Deliverable

1. After CV evaluation completes with `partial` result, the candidate is automatically redirected to the interview page and sees an AI greeting message.
2. The candidate can type answers, submit them, and receive AI follow-up — the full exchange is saved to `conversations` + `messages`.
3. Each AI message is spoken aloud with word highlighting and waveform animation matching the dev prototype behaviour.
4. After all questions are resolved (or the failure threshold is reached), the interview ends, the candidate sees a thank-you screen, and the candidate's state transitions to `completed`.

## Spec Documentation

- Tasks: @.agent-os/specs/2026-03-23-ai-interview-stage2/tasks.md
- Technical Specification: @.agent-os/specs/2026-03-23-ai-interview-stage2/sub-specs/technical-spec.md
- API Specification: @.agent-os/specs/2026-03-23-ai-interview-stage2/sub-specs/api-spec.md
- Database Schema: @.agent-os/specs/2026-03-23-ai-interview-stage2/sub-specs/database-schema.md
- Tests Specification: @.agent-os/specs/2026-03-23-ai-interview-stage2/sub-specs/tests.md

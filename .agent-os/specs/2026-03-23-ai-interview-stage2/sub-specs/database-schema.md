# Database Schema

This is the database schema implementation for the spec detailed in @.agent-os/specs/2026-03-23-ai-interview-stage2/spec.md

> Created: 2026-03-23
> Version: 1.0.0

---

## New Tables

### `conversations`

Stores the interview session for a candidate.

```ruby
create_table :conversations do |t|
  t.integer  :candidate_id, null: false
  t.string   :state,        null: false, default: 'in_progress'
  t.datetime :started_at,   null: false, default: -> { 'CURRENT_TIMESTAMP' }
  t.datetime :completed_at
  t.timestamps
end

add_index :conversations, :candidate_id
add_foreign_key :conversations, :candidates
```

**Rationale:** One conversation per candidate interview session. `state` tracks lifecycle. `completed_at` is set when the interview concludes.

---

### `messages`

Stores each individual message in the conversation.

```ruby
create_table :messages do |t|
  t.integer  :conversation_id, null: false
  t.string   :role,            null: false   # 'ai' | 'candidate'
  t.text     :content,         null: false
  t.text     :metadata,        default: '{}'  # JSON: attempt, question_index, verdict
  t.integer  :position,        null: false    # ordering within conversation
  t.timestamps
end

add_index :messages, :conversation_id
add_index :messages, [:conversation_id, :position]
add_foreign_key :messages, :conversations
```

**Rationale:** `position` ensures deterministic ordering without relying on `created_at`. `metadata` stores AI-side evaluation state (attempt number, whether answer was sufficient) without polluting main columns.

---

## Modified Tables

### `candidates` — add `interview_summary`

```ruby
add_column :candidates, :interview_summary, :text
# Stores the JSON summary produced by InterviewConductor when complete: true
# { overall:, score:, answers: [...], summary: "..." }
```

**Rationale:** Mirrors `evaluation_result` pattern. Keeps the final aggregated interview outcome on the candidate record for easy access in future recruiter views and Stage 3 summary generation.

---

## Migration Files

```
db/migrate/TIMESTAMP_create_conversations.rb
db/migrate/TIMESTAMP_create_messages.rb
db/migrate/TIMESTAMP_add_interview_summary_to_candidates.rb
```

---

## Model Relationships

```
Candidate
  has_one  :conversation
  has_many :messages, through: :conversation

Conversation
  belongs_to :candidate
  has_many   :messages, -> { order(:position) }

Message
  belongs_to :conversation
```

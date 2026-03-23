# frozen_string_literal: true

# Conducts a single turn of the AI-driven interview for a candidate.
#
# Builds a prompt from the job scenario, the candidate's CV evaluation result,
# and any existing conversation history, then calls Claude to produce the next
# interviewer message (or a completion summary when all questions are covered).
#
# @example Starting an interview
#   result = InterviewConductor.new(candidate).call
#   # => { content: "Tell me about...", complete: false, question_index: 0, attempt: 1, summary: nil }
#
# @example Completing an interview
#   result = InterviewConductor.new(candidate).call
#   # => { content: "Thanks!", complete: true, question_index: 0, attempt: 2,
#   #      summary: { overall: "pass", score: 78, answers: [...], summary: "..." } }
class InterviewConductor
  include AnthropicClient

  REQUIRED_KEYS    = %i[content complete question_index attempt summary].freeze
  SUMMARY_KEYS     = %i[overall score answers summary].freeze
  VALID_OVERALL    = %w[pass fail].freeze

  def initialize(candidate)
    @candidate    = candidate
    @conversation = candidate.conversation
  end

  # @return [Hash] structured turn result
  # @raise [InterviewConductor::Error] on validation or parse failure
  def call
    raise Error, "No evaluation result — run CV evaluator first" if @candidate.evaluation_result.blank?

    scenario = @candidate.job.scenario
    raise Error, "Job has no scenario — cannot conduct interview" unless scenario

    response = client.messages.create(
      model:      "claude-opus-4-6",
      max_tokens: 2048,
      messages:   build_messages(scenario)
    )

    parse_response!(response.content.first.text)
  end

  class Error < StandardError; end

  private

  def build_messages(scenario)
    [ { role: "user", content: build_prompt(scenario) } ]
  end

  def build_prompt(scenario)
    eval_hash = JSON.parse(@candidate.evaluation_result, symbolize_names: true)

    parts = []
    parts << system_instructions
    parts << "## Job Scenario\n\n#{scenario.content}"
    parts << "## CV Evaluation Result\n\n#{JSON.pretty_generate(eval_hash)}"

    if @conversation&.messages&.any?
      parts << "## Conversation History\n\n#{format_history}"
    end

    parts << interview_response_instructions
    parts.join("\n\n")
  end

  def system_instructions
    <<~INSTRUCTIONS.strip
      You are an expert technical interviewer AI conducting a structured interview.
      Your job is to ask the candidate the questions identified during CV evaluation,
      probe their answers for depth, and decide when each question has been sufficiently answered.
      Be professional, encouraging, and concise.
    INSTRUCTIONS
  end

  def interview_response_instructions
    <<~INSTRUCTIONS.strip
      ## Response Instructions

      Return ONLY a valid JSON object — no markdown, no code fences, no commentary.

      Required JSON structure:
      {
        "content": "<your next message to the candidate>",
        "complete": <true when all questions are covered, false otherwise>,
        "question_index": <0-based index of the question currently being discussed>,
        "attempt": <how many times this question has been asked/probed, starting at 1>,
        "summary": <null when complete is false, or an object when complete is true>
      }

      When complete is true, summary must be:
      {
        "overall": "pass" | "fail",
        "score": <integer 0-100>,
        "answers": [
          { "question": "<question text>", "answer": "<candidate's answer summary>", "verdict": "sufficient" | "insufficient" }
        ],
        "summary": "<2-3 sentence recruiter-facing interview summary>"
      }
    INSTRUCTIONS
  end

  def format_history
    @conversation.messages.map { |m|
      label = m.role == "ai" ? "Interviewer" : "Candidate"
      "**#{label}:** #{m.content}"
    }.join("\n\n")
  end

  def parse_response!(text)
    json_text = text.gsub(/\A```(?:json)?\s*/m, "").gsub(/\s*```\z/m, "").strip
    result    = JSON.parse(json_text, symbolize_names: true)

    validate_result!(result)
    result
  rescue JSON::ParserError => e
    raise Error, "Could not parse interview response: #{e.message}\nRaw: #{text.truncate(300)}"
  end

  def validate_result!(result)
    missing = REQUIRED_KEYS - result.keys
    raise Error, "Interview response missing keys: #{missing.join(', ')}" if missing.any?

    return unless result[:complete]

    summary = result[:summary] || {}
    missing_summary = SUMMARY_KEYS - summary.keys
    raise Error, "Interview summary missing keys: #{missing_summary.join(', ')}" if missing_summary.any?

    overall = summary[:overall].to_s
    raise Error, "Invalid summary overall: #{overall.inspect}" unless VALID_OVERALL.include?(overall)
  end
end

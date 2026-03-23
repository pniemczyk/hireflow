# frozen_string_literal: true

# Evaluates a candidate's CV against the job's scenario using Claude.
#
# Returns a hash with:
#   overall:  'pass' | 'partial' | 'fail'
#   score:    0–100 integer
#   summary:  2-3 sentence recruiter-facing summary
#   gaps:     array of strings — missing or weak signals
#   questions: array of strings — follow-up questions for the interview stage
#
# @example
#   result = CvEvaluator.new(candidate).call
#   candidate.update!(evaluation_result: result.to_json)
class CvEvaluator
  include AnthropicClient

  def initialize(candidate)
    @candidate = candidate
  end

  # @return [Hash] structured evaluation result
  # @raise [CvEvaluator::Error] when evaluation fails or response is unparseable
  def call
    raise Error, 'No CV text to evaluate' if @candidate.cv_raw_text.blank?

    scenario = @candidate.job.scenario
    raise Error, 'Job has no evaluation scenario' unless scenario

    response = client.messages.create(
      model:      'claude-opus-4-6',
      max_tokens: 2048,
      messages: [
        { role: 'user', content: build_prompt(scenario.content, @candidate.cv_raw_text) }
      ]
    )

    parse_response!(response.content.first.text)
    # Anthropic::Errors::* bubble up to the job for retry handling.
  end

  class Error < StandardError; end

  private

  def build_prompt(scenario_content, cv_text)
    <<~PROMPT
      You are an expert technical recruiter AI. Evaluate the candidate's CV against the provided evaluation scenario.

      ## Evaluation Scenario

      #{scenario_content}

      ## Candidate CV

      #{cv_text}

      ## Instructions

      Follow the evaluation instructions in the scenario exactly.
      Return ONLY a valid JSON object — no markdown, no code fences, no commentary.

      Required JSON structure:
      {
        "overall": "pass" | "partial" | "fail",
        "score": <integer 0-100>,
        "summary": "<2-3 sentence recruiter-facing summary>",
        "gaps": ["<gap 1>", "<gap 2>"],
        "questions": ["<follow-up question 1>", "<follow-up question 2>"]
      }
    PROMPT
  end

  def parse_response!(text)
    # Strip any accidental markdown fences Claude might add.
    json_text = text.gsub(/\A```(?:json)?\s*/m, '').gsub(/\s*```\z/m, '').strip
    result    = JSON.parse(json_text, symbolize_names: true)

    validate_result!(result)
    result
  rescue JSON::ParserError => e
    raise Error, "Could not parse evaluation response: #{e.message}\nRaw: #{text.truncate(300)}"
  end

  def validate_result!(result)
    required = %i[overall score summary gaps questions]
    missing  = required - result.keys
    raise Error, "Evaluation response missing keys: #{missing.join(', ')}" if missing.any?

    unless %w[pass partial fail].include?(result[:overall])
      raise Error, "Invalid overall value: #{result[:overall]}"
    end
  end
end

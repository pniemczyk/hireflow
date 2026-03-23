# frozen_string_literal: true

# Extracts plain Markdown text from an uploaded CV file.
#
# Supports:
#   - .md / .txt  — reads the file directly
#   - .pdf        — sends to Claude API for extraction
#
# @example
#   result = CvProcessor.new(candidate).call
#   candidate.update!(cv_raw_text: result)
class CvProcessor
  # Maximum PDF size accepted by the Claude API (32 MB).
  MAX_PDF_BYTES = 32 * 1024 * 1024

  def initialize(candidate)
    @candidate = candidate
  end

  # @return [String] extracted Markdown text
  # @raise [CvProcessor::Error] when extraction fails
  def call
    blob = @candidate.cv_file.blob
    raise Error, 'No attached file' unless blob

    case blob.content_type
    when 'application/pdf'
      extract_pdf(blob)
    else
      read_text(blob)
    end
  end

  class Error < StandardError; end

  private

  # Plain text / Markdown — just read the bytes.
  def read_text(blob)
    blob.download.force_encoding('UTF-8')
  end

  # Send the PDF to Claude and ask it to return Markdown.
  def extract_pdf(blob)
    bytes = blob.download

    if bytes.bytesize > MAX_PDF_BYTES
      raise Error, "PDF is too large (#{bytes.bytesize / 1.megabyte} MB). Max 32 MB."
    end

    client = Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'))

    response = client.messages.create(
      model:      'claude-opus-4-6',
      max_tokens: 4096,
      messages: [
        {
          role:    'user',
          content: [
            {
              type:   'document',
              source: {
                type:         'base64',
                media_type:   'application/pdf',
                data:         Base64.strict_encode64(bytes)
              }
            },
            {
              type: 'text',
              text: <<~PROMPT
                Convert the attached CV/résumé to clean Markdown.

                Rules:
                - Preserve all relevant information (contact details, work experience, education, skills, etc.)
                - Use ## for section headings, ### for sub-headings where appropriate
                - Use bullet lists for experience and skill items
                - Keep dates and employer names on the same line where possible (e.g. **Company** — Jan 2020 – Present)
                - Strip decorative page elements (headers/footers, watermarks, page numbers)
                - Output only the Markdown — no preamble, no code fences, no commentary
              PROMPT
            }
          ]
        }
      ]
    )

    response.content.first.text
  end
end

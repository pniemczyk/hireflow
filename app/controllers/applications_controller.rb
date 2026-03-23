# frozen_string_literal: true

class ApplicationsController < ApplicationController
  before_action :set_job

  STATUS_META = {
    "cv_processing"        => { label: "Extracting CV…",                    progress: 20 },
    "ready_for_evaluating" => { label: "Queued for evaluation…",             progress: 40 },
    "evaluating"           => { label: "AI is evaluating your profile…",     progress: 65 },
    "evaluated"            => { label: "Evaluation complete",                progress: 100 },
    "interviewing"         => { label: "AI interview in progress…",          progress: 75 },
    "completed"            => { label: "All stages complete",                progress: 100 },
    "accepted"             => { label: "Profile accepted",                   progress: 100 },
    "rejected"             => { label: "Profile reviewed",                   progress: 100 }
  }.freeze

  TERMINAL_STATES         = %w[evaluated accepted rejected completed].freeze
  RESULT_TERMINAL_STATES  = %w[completed accepted rejected].freeze

  def new
    # In proof-of-concept, we'll just create new candidates for each job.
    @candidate = Candidate.new
  end

  def create
    @candidate = Candidate.new(candidate_params)
    @candidate.job = @job

    if params.dig(:candidate, :cv_file).present?
      @candidate.cv_file.attach(params[:candidate][:cv_file])
    end

    unless @candidate.cv_provided?
      @candidate.errors.add(:base, "Please upload a CV file or paste your CV text.")
      return render :new, status: :unprocessable_entity
    end

    if @candidate.save
      dispatch_processing(@candidate)
      redirect_to submitted_job_application_path(@job, candidate_id: @candidate.id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def submitted
    @candidate = @job.candidates.find(params[:candidate_id])
  end

  def status
    candidate    = @job.candidates.find(params[:candidate_id])
    redirect_url = auto_route_evaluated!(candidate)
    state        = candidate.current_state
    meta         = STATUS_META.fetch(state, { label: state.humanize, progress: 50 })

    render json: {
      status:       state,
      label:        meta[:label],
      progress:     meta[:progress],
      done:         TERMINAL_STATES.include?(state),
      evaluation:   (candidate.evaluation if state == "evaluated"),
      redirect_url: redirect_url
    }.compact
  end

  # GET /jobs/:job_id/apply/:candidate_id/interview
  def interview
    @candidate    = @job.candidates.find(params[:candidate_id])
    unless @candidate.current_state == "interviewing"
      return redirect_to candidate_application_status_path(@job, candidate_id: @candidate.id)
    end

    @conversation = @candidate.conversation || @candidate.create_conversation!
    if @conversation.messages.none?
      result = InterviewConductor.new(@candidate).call
      @conversation.messages.create!(role: "ai", content: result[:content],
                                     metadata: result.slice(:question_index, :attempt, :complete).to_json)
    end
    @messages = @conversation.messages.order(:position)
  end

  # POST /jobs/:job_id/apply/:candidate_id/interview/messages
  def create_message
    @candidate    = @job.candidates.find(params[:candidate_id])
    @conversation = @candidate.conversation

    content = params[:content].to_s.strip
    if content.blank?
      @error_message = "Answer can't be blank."
      return render "applications/create_message_error", formats: [ :turbo_stream ], status: :unprocessable_entity
    end

    @candidate_message = @conversation.messages.create!(role: "candidate", content: content)

    result      = InterviewConductor.new(@candidate.reload).call
    @ai_message = @conversation.messages.create!(
      role:     "ai",
      content:  result[:content],
      metadata: result.slice(:question_index, :attempt, :complete).to_json
    )
    @complete = result[:complete]

    if @complete
      @candidate.update!(interview_summary: result[:summary].to_json)
      @candidate.transition_to!(:completed)
      @candidate.transition_to!(:rejected) if result[:summary][:overall] == "fail"
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  # GET /jobs/:job_id/apply/:candidate_id/result
  def result
    @candidate = @job.candidates.find(params[:candidate_id])
    unless RESULT_TERMINAL_STATES.include?(@candidate.current_state)
      redirect_to candidate_application_status_path(@job, candidate_id: @candidate.id)
    end
  end

  private

  def set_job
    @job = Job.find(params[:job_id])
  end

  # Sets the correct initial state and dispatches background processing.
  #
  # Text-only submissions skip cv_processing and go straight to evaluation.
  # File uploads stay in cv_processing; ProcessCvJob advances the state.
  def dispatch_processing(candidate)
    if candidate.cv_file.attached?
      # Stays in :cv_processing (initial state) — ProcessCvJob will advance it.
      enqueue(ProcessCvJob, candidate.id)
    else
      # Text pasted directly — skip extraction, go straight to evaluation.
      candidate.transition_to!(:ready_for_evaluating)
      enqueue(EvaluateCvJob, candidate.id)
    end
  end

  # Runs synchronously in development so results are visible immediately;
  # defers to the queue in all other environments.
  def enqueue(job_class, *args)
    Rails.env.development? ? job_class.perform_now(*args) : job_class.perform_later(*args)
  end

  # When a candidate just reached `evaluated`, immediately determine the
  # correct next state and transition — returning the redirect URL so the
  # status poller can navigate the browser to the right page.
  #
  # @param candidate [Candidate]
  # @return [String, nil] redirect URL, or nil if no transition was triggered
  def auto_route_evaluated!(candidate)
    return nil unless candidate.current_state == "evaluated"

    evaluation = candidate.evaluation
    return nil unless evaluation

    if evaluation[:overall] == "fail"
      candidate.transition_to!(:rejected)
      job_application_result_path(@job, candidate_id: candidate.id)
    elsif evaluation[:overall] == "pass" && evaluation[:questions].blank?
      candidate.transition_to!(:accepted)
      job_application_result_path(@job, candidate_id: candidate.id)
    else
      # partial, or pass with follow-up questions → interview
      candidate.transition_to!(:interviewing)
      job_application_interview_path(@job, candidate_id: candidate.id)
    end
  end

  def candidate_params
    params.require(:candidate).permit(:name, :email, :cv_raw_text, :cv_file)
  end
end

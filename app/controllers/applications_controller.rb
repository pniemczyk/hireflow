# frozen_string_literal: true

class ApplicationsController < ApplicationController
  before_action :set_job

  STATUS_META = {
    'cv_processing'        => { label: 'Extracting CV…',                    progress: 20 },
    'ready_for_evaluating' => { label: 'Queued for evaluation…',             progress: 40 },
    'evaluating'           => { label: 'AI is evaluating your profile…',     progress: 65 },
    'evaluated'            => { label: 'Evaluation complete',                progress: 100 },
    'interviewing'         => { label: 'AI interview in progress…',          progress: 75 },
    'completed'            => { label: 'All stages complete',                progress: 100 },
    'accepted'             => { label: 'Profile accepted',                   progress: 100 },
    'rejected'             => { label: 'Profile reviewed',                   progress: 100 }
  }.freeze

  TERMINAL_STATES = %w[evaluated accepted rejected completed].freeze

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
      @candidate.errors.add(:base, 'Please upload a CV file or paste your CV text.')
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
    candidate = @job.candidates.find(params[:candidate_id])
    state     = candidate.current_state
    meta      = STATUS_META.fetch(state, { label: state.humanize, progress: 50 })

    render json: {
      status:       state,
      label:        meta[:label],
      progress:     meta[:progress],
      done:         TERMINAL_STATES.include?(state),
      evaluation:   (candidate.evaluation if state == 'evaluated')
    }
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
      if Rails.env.development?
        ProcessCvJob.perform_now(candidate.id)
      else
        ProcessCvJob.perform_later(candidate.id)
      end
    else
      # Text pasted directly — skip extraction, go straight to evaluation.
      candidate.transition_to!(:ready_for_evaluating)
      if Rails.env.development?
        EvaluateCvJob.perform_now(candidate.id)
      else
        EvaluateCvJob.perform_later(candidate.id)
      end
    end
  end

  def candidate_params
    params.require(:candidate).permit(:name, :email, :cv_raw_text, :cv_file)
  end
end

# frozen_string_literal: true

class WelcomeController < ApplicationController
  def index
    job = Job.active.first
    redirect_to new_job_application_path(job) if job
  end
end

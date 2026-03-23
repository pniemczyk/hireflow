Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  post "tts/synthesize", to: "tts#synthesize", as: :tts_synthesize

  get  "jobs/:job_id/apply",                                  to: "applications#new",            as: :new_job_application
  post "jobs/:job_id/apply",                                  to: "applications#create",         as: :job_application
  get  "jobs/:job_id/apply/submitted",                        to: "applications#submitted",      as: :submitted_job_application
  get  "jobs/:job_id/apply/:candidate_id/status",             to: "applications#status",         as: :candidate_application_status
  get  "jobs/:job_id/apply/:candidate_id/interview",          to: "applications#interview",      as: :job_application_interview
  post "jobs/:job_id/apply/:candidate_id/interview/messages", to: "applications#create_message", as: :job_application_messages
  get  "jobs/:job_id/apply/:candidate_id/result",             to: "applications#result",         as: :job_application_result

  # Dev-only playground routes
  if Rails.env.development?
    namespace :dev do
      get  "text_to_speech",            to: "text_to_speech#show",      as: :text_to_speech
      post "text_to_speech/synthesize", to: "text_to_speech#synthesize", as: :text_to_speech_synthesize
    end
  end

  # Defines the root path route ("/")
  root "welcome#index"
end

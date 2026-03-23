# frozen_string_literal: true

job = Job.find_or_create_by!(title: "Senior Rails Engineer") do |j|
  j.status = "active"
  j.short_description = <<~MD
    **Platform Engineering** · Remote · Full-time

    Own critical backend systems on a high-traffic Rails platform.
    Work alongside a small, senior team and have a direct impact on architecture.
  MD
  j.description = <<~MD
    ## About the Role

    We are looking for a **seasoned Ruby on Rails engineer** to join our core platform team.
    You will own critical backend systems, lead architectural decisions, and help shape
    the engineering culture as we scale.

    This is a high-impact, senior individual-contributor role with direct influence on
    product and infrastructure direction.

    ## What You'll Do

    - Design and build robust, scalable Rails services used by thousands of users daily
    - Lead code reviews and set the quality bar for the engineering team
    - Drive architectural decisions for new features and system improvements
    - Collaborate closely with product, design, and data teams
    - Mentor junior and mid-level engineers

    ## Requirements

    - **5+ years** of professional Ruby on Rails experience
    - Deep understanding of Ruby — idiomatic code, performance, memory management
    - Strong PostgreSQL skills — schema design, indexing, query optimisation, migrations
    - Solid testing practice — TDD/BDD with RSpec or Minitest
    - Experience designing and maintaining RESTful APIs
    - Proficiency with background job processing (Sidekiq, Solid Queue, or similar)

    ## Nice to Have

    - Experience with Hotwire (Turbo + Stimulus)
    - Familiarity with cloud infrastructure (AWS, GCP, DigitalOcean)
    - Open source contributions in the Ruby/Rails ecosystem
    - Experience with high-traffic or data-intensive applications

    ## What We Offer

    - Competitive salary + equity
    - Fully remote — work from anywhere
    - Async-first culture with minimal meetings
    - Annual learning & conference budget
    - Top-of-the-line hardware of your choice
  MD
end

Scenario.find_or_create_by!(job: job) do |s|
  s.version = 1
  s.content = <<~SCENARIO
    # Senior Rails Engineer — Evaluation Scenario

    ## Role Context
    We are hiring a senior backend engineer to lead development of our Rails-based platform.
    The ideal candidate is deeply experienced with Ruby on Rails, comfortable with system
    design, and has a track record of delivering production-grade software.

    ## Required Criteria (Must-Have)

    - **Rails experience:** 5+ years building production Rails applications
    - **Ruby proficiency:** Strong Ruby knowledge, idiomatic code, performance awareness
    - **Database:** PostgreSQL or equivalent — schema design, indexing, query optimisation
    - **Testing:** Solid TDD/BDD practice — RSpec or Minitest, integration and system tests
    - **API design:** RESTful APIs, JSON serialisation, versioning strategies
    - **Background jobs:** Sidekiq, Solid Queue, or similar async processing

    ## Preferred Criteria (Nice-to-Have)

    - Experience with Hotwire (Turbo + Stimulus) or similar reactive frontend approaches
    - Familiarity with cloud infrastructure (AWS, GCP, DigitalOcean)
    - Contributions to open source Ruby/Rails projects
    - Experience with high-traffic or data-intensive applications

    ## Evaluation Instructions

    Assess the candidate's CV against the required and preferred criteria above.

    1. For each required criterion, determine: met / partially met / not evidenced
    2. For each preferred criterion, determine: present / absent
    3. Identify any significant gaps or red flags
    4. Generate targeted follow-up questions for anything that is unclear or only partially evidenced
    5. Produce a structured validation result:
       - overall: pass / partial / fail
       - score: 0–100
       - summary: 2–3 sentence recruiter-facing summary
       - gaps: list of missing or weak signals
       - questions: list of follow-up questions (if any)

    ## Rejection Criteria (Automatic Fail)

    - Fewer than 3 years of professional Rails experience
    - No evidence of working with relational databases
    - No evidence of any automated testing practice
  SCENARIO
end

puts "Seeded: #{job.title} (id: #{job.id})"

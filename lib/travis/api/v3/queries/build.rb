require 'travis/api/enqueue/services/restart_model'
require 'travis/api/enqueue/services/cancel_model'

module Travis::API::V3
  class Queries::Build < Query
    params :id

    PRIORITY = { high: 5, normal: nil, low: -5 }

    def find
      return Models::Build.find_by_id(id) if id
      raise WrongParams, 'missing build.id'.freeze
    end

    def cancel(user)
      raise BuildNotCancelable if %w(passed failed canceled errored).include? find.state

      payload = { id: id, user_id: user.id, source: 'api' }
      service = Travis::Enqueue::Services::CancelModel.new(user, { build_id: id })
      service.push("build:cancel", payload)
      payload
    end

    def restart(user)
      raise BuildAlreadyRunning if %w(received queued started).include? find.state

      service = Travis::Enqueue::Services::RestartModel.new(user, { build_id: id })
      payload = { id: id, user_id: user.id }

      restart_status = service.push("build:restart", payload)

      if restart_status == "abuse_detected"
        restart_status
      else
        payload
      end
    end

    def priority(user)
      raise NotFound, "Job not found" if find.jobs.blank?
      build_job = find.jobs.find_by_commit_id(find.commit_id)
      priority_status = build_job.update_column(:priority, PRIORITY[:high]) if build_job
      raise UnprocessableEntity unless priority_status
    end
  end
end

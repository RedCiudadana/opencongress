require 'beanstalk-client'

module ImportQueueWorkerJob
  def self.perform ()
    beanstalk = Beanstalk::Pool.new(Settings.beanstalk_servers)
    beanstalk.watch(Settings.unitedstates_import_queue)
    begin
      OCLogger.log "Monitoring '#{Settings.unitedstates_import_queue}' beanstalk queue for import tasks."
      loop do
        job = beanstalk.reserve
        begin
          OCLogger.log "Processing import task: #{job.body}"
          import_job = JSON.parse(job.body, :object_class => HashWithIndifferentAccess)
          if import_job[:bill_id]
            ImportBillsJob.perform(import_job)
          elsif import_job[:amendment_id]
            ImportAmendmentsJob.perform(import_job)
          elsif import_job[:vote_id]
            ImportRollCallsJob.perform(import_job)
          end
          job.delete

        rescue JSON::ParserError => e
          OCLogger.log "Failed to parse import job as JSON: '#{import_job}': #{e}"
          job.bury

        rescue StandardError => e
          OCLogger.log "Error while processing import job: '#{import_job}': #{e}"
          job.bury
        end
      end

    rescue Interrupt
      # Ignore
    end
  end
end
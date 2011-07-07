require 'rubygems'
require 'optparse.rb'
require "net/http"
require "uri"
require "yaml"
require "json"
require "parallel"

require "jenkins_helpers"


@config = YAML.load_file("jenkins_conductor_config.yml")
cli_params = ARGV.getopts("c:", "current_job:")

root_job = cli_params["c"].nil? ? cli_params["current_job"] : cli_params["c"]

@artifact_dir = @config["artifact_destination"] || "artifacts"

`rm -rf #{@artifact_dir}`
`mkdir #{@artifact_dir}`


@all_job_statuses = Hash.new

serial_jobs = @config["jobs"][root_job]["downstream_jobs"]["serial_jobs"]
unless serial_jobs.nil? or serial_jobs.empty?
  serial_jobs.each do |serial_project|
    status, link_to_job = launch_project_and_monitor_progress(serial_project)
    puts get_artifact_from_job(serial_project, link_to_job)

    if status == "fail"
      puts "#{serial_project} Failed and was set to stop build on failure"
      exit 1
    end

  end
end


parallel_jobs_to_run = @config["jobs"][root_job]["downstream_jobs"]["parallel_jobs"]
unless parallel_jobs_to_run.nil? or parallel_jobs_to_run.empty?
  Parallel.map(parallel_jobs_to_run, :in_threads => parallel_jobs_to_run.size) do |current_project|
    status, link_to_job = launch_project_and_monitor_progress(current_project)
    puts get_artifact_from_job(current_project, link_to_job)
  end
end

check_if_any_job_failed(@all_job_statuses)
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

@all_job_statuses = Hash.new

@config["jobs"][root_job]["downstream_jobs"]["serial_jobs"].each do |serial_project|
  launch_project_and_monitor_progress(serial_project)
end



downstream_parallel_jobs_to_run = @config["jobs"][root_job]["downstream_jobs"]["parallel_jobs"]
Parallel.map(downstream_parallel_jobs_to_run, :in_threads => downstream_parallel_jobs_to_run.size) do |current_project|
  launch_project_and_monitor_progress(current_project)
end

puts @all_job_statuses.inspect
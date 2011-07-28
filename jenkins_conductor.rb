require 'rubygems'
require 'optparse.rb'
require "yaml"
require "json"
require "parallel"

require 'build_history_helper'
require "http_helper"
require "jenkins_job"


@config = YAML.load_file("jenkins_conductor_config.yml")
cli_params = ARGV.getopts("c:", "current_job:", "b:", "build_id:", "p:", "params:")


parent_job           = cli_params["c"].nil? ? cli_params["current_job"] : cli_params["c"]
@parent_job_build_id = cli_params["b"].nil? ? cli_params["build_id"] : cli_params["b"]
cli_params           = cli_params["p"].nil? ? cli_params["params"] : cli_params["p"]


throw "Job #{parent_job} could not be found in jenkins_conductor_config.yml"                 unless @config["jobs"][parent_job]
throw "Please add current build number to the launch, or we have hard time triggering jobs"  unless @parent_job_build_id


artifact_dir = @config["artifact_destination"] || "artifacts"

`rm -rf #{artifact_dir}`
`mkdir #{artifact_dir}`


serial_jobs = @config["jobs"][parent_job]["downstream_jobs"]["serial_jobs"]
serial_jobs = serial_jobs.nil? ? [] : serial_jobs.collect {|yaml_job| JenkinsJob.new(parent_job, @parent_job_build_id, yaml_job, @config, artifact_dir, cli_params)}

parallel_jobs = @config["jobs"][parent_job]["downstream_jobs"]["parallel_jobs"]
parallel_jobs = parallel_jobs.nil? ? [] : parallel_jobs.collect {|yaml_job| JenkinsJob.new(parent_job, @parent_job_build_id, yaml_job, @config, artifact_dir, cli_params)}


serial_jobs.each do |serial_build|
  serial_build.trigger_job
  serial_build.get_artifacts

  if serial_build.result.upcase != "SUCCESS"
    error_message = "#{serial_build.job_name} has finished with status of #{serial_build.result}\n\n"
    error_message += "This job was explicitly set to exit on failure"
    raise error_message if serial_build.continue_on_failure == false
  end
end



max_parallel_jobs = @config["max_parallel_jobs"] || parallel_jobs.size
Parallel.map(parallel_jobs, :in_threads => max_parallel_jobs) do |parallel_build|
  parallel_build.trigger_job
  parallel_build.get_artifacts
end

all_builds_passed = true

(serial_jobs + parallel_jobs).each do |build|
  puts "#{build.job_name} - #{build.result} - #{build.url}/#{build.build_id}"
  if build.result.upcase != "SUCCESS"
    all_builds_passed = false unless build.result.upcase.include? "- STATUS WAS IGNORED"
  end
end

exit 1 unless all_builds_passed

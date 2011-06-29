require 'rubygems'
require 'optparse.rb'
require "net/http"
require "uri"
require "yaml"
require "json"
require "parallel"

config = YAML.load_file("jenkins_conductor_config.yml")
params = ARGV.getopts("c:", "current_job:")

root_job = params["c"].nil? ? params["current_job"] : params["c"]

all_job_statuses = Hash.new

config["jobs"][root_job]["downstream_jobs"]["serial_jobs"].each do |serial_project|
  current_job_name = serial_project.keys.first
  url_to_job = "#{config["jenkins_base_url"]}/view/All/job/#{current_job_name}"
  all_jobs_for_current_project = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/api/json")).body)

  previous_job_number = all_jobs_for_current_project["builds"].first["number"]
  current_job_number = previous_job_number + 1

  uri = URI.parse("#{url_to_job}/buildWithParameters")

  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Post.new(uri.request_uri)
  request.set_form_data(serial_project[current_job_name]["params"])

  response = http.request(request)
  throw "Error with post to #{uri.to_s} with #{serial_project[current_job_name]["params"]} return was not 'Net::HTTPFound 302 Found'" unless response.kind_of?(Net::HTTPFound)

  puts "Waiting for job #{current_job_name} build #{current_job_number} to start"
  begin
    current_job_start_status = Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_job_number}/api/json"))
    sleep 5
  end while current_job_start_status.kind_of?(Net::HTTPNotFound)

  puts "Job #{current_job_name} build #{current_job_number} started"

  puts "waiting for job #{current_job_name} build #{current_job_number} to finish"
  begin
    current_job = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_job_number}/api/json")).body)
    sleep 5
  end while current_job["result"].nil?


  all_job_statuses[current_job_name] = {:status => current_job['result'],
                                        :test_result_artifact => serial_project[current_job_name]["test_result_artifact"] }

  puts "Job #{current_job_name} build #{current_job_number} with result of #{current_job['result']}"
end




downstream_parallel_jobs_to_run = config["jobs"][root_job]["downstream_jobs"]["parallel_jobs"]

Parallel.map(downstream_parallel_jobs_to_run, :in_threads => downstream_parallel_jobs_to_run.size) do |current_project|

  current_job_name = current_project.keys.first
  url_to_job = "#{config["jenkins_base_url"]}/view/All/job/#{current_job_name}"


  all_jobs_for_current_project = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/api/json")).body)
  previous_job_number = all_jobs_for_current_project["builds"].first["number"]
  current_job_number = previous_job_number + 1

  uri = URI.parse("#{url_to_job}/buildWithParameters")


  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Post.new(uri.request_uri)
  request.set_form_data(current_project[current_job_name]["params"])

  response = http.request(request)
  throw "Error with post to #{uri.to_s} with #{current_project[current_job_name]["params"]} return was not 'Net::HTTPFound 302 Found'" unless response.kind_of?(Net::HTTPFound)


  puts "Waiting for job #{current_job_name} build #{current_job_number} to start"
  begin
    current_job_start_status = Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_job_number}/api/json"))
    sleep 5
  end while current_job_start_status.kind_of?(Net::HTTPNotFound)

  puts "Job #{current_job_name} build #{current_job_number} started"

  puts "waiting for job #{current_job_name} build #{current_job_number} to finish"
  begin
    current_job = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_job_number}/api/json")).body)
    sleep 5
  end while current_job["result"].nil?

  all_job_statuses[current_job_name] = {:status => current_job['result'],
                                        :test_result_artifact => current_project[current_job_name]["test_result_artifact"] }

  puts "Job #{current_job_name} build #{current_job_number} with result of #{current_job['result']}"

end

puts all_job_statuses.inspect
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


downstream_jobs_to_run = config["jobs"][root_job]["downstream_jobs"]

Parallel.map(downstream_jobs_to_run, :in_threads => downstream_jobs_to_run.size) do |current_project|

  current_job_name = current_project.keys.first
  url_to_job = "#{config["jenkins_base_url"]}/view/All/job/#{current_job_name}"


  all_jobs_for_current_project = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/api/json")).body)
  previous_job_number = all_jobs_for_current_project["builds"].first["number"]

  uri = URI.parse("#{url_to_job}/buildWithParameters")


  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Post.new(uri.request_uri)
  request.set_form_data(current_project[current_job_name]["params"])

  response = http.request(request)
  throw "Error with post to #{uri.to_s} with #{current_project[current_job_name]["params"]} return was not 'Net::HTTPFound 302 Found'" unless response.kind_of?(Net::HTTPFound)


  current_job_number = previous_job_number + 1

  begin
    current_job_start_status = Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_job_number}/api/json"))
    puts "Waiting for job #{current_job_number} to start"
    sleep 5
  end while current_job_start_status.kind_of?(Net::HTTPNotFound)

  puts "Job #{current_job_number} started"

  begin
    puts "waiting for job #{current_job_number} to finish"
    current_job = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_job_number}/api/json")).body)
    sleep 5
  end while current_job["result"].nil?

  puts current_job["result"]

end
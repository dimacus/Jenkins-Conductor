def launch_project_and_monitor_progress(current_project)
  current_job_name = current_project.keys.first
  url_to_job = "#{@config["jenkins_base_url"]}/view/All/job/#{current_job_name}"


  all_jobs_for_current_project = get_all_builds_for_project(url_to_job)
  current_build_number = get_current_build_number(all_jobs_for_current_project)

  trigger_job(url_to_job, current_project[current_job_name]["params"])

  wait_for_build_to_start(url_to_job, current_job_name, current_build_number)
  result = wait_for_build_to_finish(url_to_job, current_job_name, current_build_number)



  @all_job_statuses[current_job_name] = {:result => result,
                                        :test_result_artifact => current_project[current_job_name]["test_result_artifact"] }

end

def get_all_builds_for_project(url_to_job)
  JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/api/json")).body)
end

def get_current_build_number(all_jobs_for_current_project)
  previous_job_number = all_jobs_for_current_project["builds"].first.empty? ? all_jobs_for_current_project["builds"].first["number"] : 0
  previous_job_number + 1
end

def trigger_job(url_to_job, params)
  uri = URI.parse("#{url_to_job}/buildWithParameters")

 http = Net::HTTP.new(uri.host, uri.port)

 request = Net::HTTP::Post.new(uri.request_uri)
 request.set_form_data(params)

 response = http.request(request)
 throw "Error with post to #{uri.to_s} with #{current_project[current_job_name]["params"]} return was not 'Net::HTTPFound 302 Found'" unless response.kind_of?(Net::HTTPFound)
end

def wait_for_build_to_start(url_to_job, current_job_name, current_build_number)
  puts "Waiting for job #{current_job_name} build #{current_build_number} to start"
  begin
    current_job_start_status = Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_build_number}/api/json"))
    sleep 5
  end while current_job_start_status.kind_of?(Net::HTTPNotFound)

  puts "Job #{current_job_name} build #{current_build_number} started"
end

def wait_for_build_to_finish(url_to_job, current_job_name, current_build_number)
  puts "waiting for job #{current_job_name} build #{current_build_number} to finish"
  begin
    current_job = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/#{current_build_number}/api/json")).body)
    sleep 5
  end while current_job["result"].nil?
  puts "Job #{current_job_name} build #{current_build_number} with result of #{current_job['result']}"

  current_job["result"]
end

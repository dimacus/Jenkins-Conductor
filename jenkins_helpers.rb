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
  return "pass", "#{url_to_job}/#{current_build_number}" if result.upcase == "SUCCESS"

  if current_project[current_job_name]["continue_on_fail"] == false
    puts "#{current_job_name} was explicitly set to exit on failure.\n\n"
    puts "Current project statuses\n #{@all_job_statuses.inspect}\n\n"
    puts "#{current_job_name} configs\n #{current_project.inspect}\n\n"
    return "fail", "#{url_to_job}/#{current_build_number}"
  end

  return "fail-continue", "#{url_to_job}/#{current_build_number}"
end

def get_all_builds_for_project(url_to_job)
  JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/api/json")).body)
end

def get_current_build_number(all_jobs_for_current_project)
  previous_job_number = all_jobs_for_current_project["builds"].first.empty? ?  0 : all_jobs_for_current_project["builds"].first["number"]
  previous_job_number + 1
end

def trigger_job(url_to_job, params)
  uri = URI.parse("#{url_to_job}/buildWithParameters")

 http = Net::HTTP.new(uri.host, uri.port)

 request = Net::HTTP::Post.new(uri.request_uri)
 request.set_form_data(params)

 response = http.request(request)
 throw "Error with post to #{uri.to_s} with #{url_to_job} return was not 'Net::HTTPFound 302 Found'" unless response.kind_of?(Net::HTTPFound)
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

def get_artifact_from_job(project, url_to_job)
  artifacts_to_get = project[project.keys.first]["test_result_artifacts"]
  return "No artifact to get from config" unless artifacts_to_get

  job = JSON.parse(Net::HTTP.get_response(URI.parse(url_to_job + "/api/json")).body)
  return "Project didn't have any artifacts" if job["artifacts"].empty?

  files_to_download = artifacts_to_get.collect do |current_artifact|
    matched_artifact_info = job["artifacts"].select do |published_artifact|
      published_artifact["fileName"] == current_artifact
    end.first

    "#{url_to_job}/artifact/#{matched_artifact_info['relativePath']}"
  end



  unless files_to_download.empty?
    files_to_download.each do |file|
      download_file(file)
      unzip_file(file)
    end
  end

  "Artifact(s) downloaded"

end

def download_file(url)
  puts "Downloading #{url}"
  url =~ /([\w\.]*)$/
  file = $1

  uri = URI.parse(url)

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)

  open("#{@artifact_dir}/#{file}", "wb") {|save_file| save_file.write(response.body)}
end

def unzip_file(url)

  url =~ /([\w\.]*)$/
  file = $1

 if file.include? ".zip"
   puts "Unzipping #{file}"
  `cd #{@artifact_dir}; tar xvf #{file}; cd -`
  `rm -rf #{@artifact_dir}/#{file}`
 end
end
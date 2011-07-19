def launch_project_and_monitor_progress(current_project, parent_job_build_id)
  current_job_name = current_project.keys.first
  url_to_job = "#{@config["jenkins_base_url"]}/view/All/job/#{current_job_name}"

  child_job_params = current_project[current_job_name]["params"].merge({"parent_job_name" =>current_job_name,
                                                                        "parent_job_build_id" => parent_job_build_id})

  trigger_job(url_to_job, child_job_params)

  require 'debug'
  all_jobs_for_current_project = get_all_builds_for_project(url_to_job)
  current_build_number = get_current_build_number(all_jobs_for_current_project, parent_job_build_id)



  wait_for_build_to_start(url_to_job, current_job_name, current_build_number)
  result = wait_for_build_to_finish(url_to_job, current_job_name, current_build_number)

  @all_job_statuses[current_job_name] = {:result => result,
                                         :test_result_artifact => current_project[current_job_name]["test_result_artifact"],
                                         :link_to_job_console => url_to_job + "/#{current_build_number}/console"}
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
  JSON.parse(make_get_request(url_to_job + "/api/json").body)
end

def get_current_build_number(all_jobs_for_current_project, job_id_to_look_for)
  current_job_number = ""
  all_jobs_for_current_project["builds"].each do |current_job|
    if get_jobs_params(current_job["url"])["parent_job_build_id"] == job_id_to_look_for
      current_job_number = current_job["number"]
      break
    end
  end

  current_job_number
end

def get_jobs_params(url_to_job)
  parameters_to_return = {}
  url_to_job = url_to_job.gsub(/http:\/\/[\w\.]*/, @config["jenkins_base_url"])
  job_info = JSON.parse(make_get_request(url_to_job + "api/json").body)
  job_info["actions"].first["parameters"].each {|parameter| parameters_to_return[parameter["name"]] = parameter["value"] }

  parameters_to_return
end

def trigger_job(url_to_job, params)
  response = make_post_request("#{url_to_job}/buildWithParameters", params)
  throw "Error with post to #{url_to_job} with #{params} return was not 'Net::HTTPFound 302 Found'" unless response.kind_of?(Net::HTTPFound)
end

def wait_for_build_to_start(url_to_job, current_job_name, current_build_number)
  puts "Waiting for job #{current_job_name} build #{current_build_number} to start"
  begin
    current_job_start_status = make_get_request(url_to_job + "/#{current_build_number}/api/json")
    sleep 15
    puts "_"
  end while current_job_start_status.kind_of?(Net::HTTPNotFound)

  puts "Job #{current_job_name} build #{current_build_number} started"
end

def wait_for_build_to_finish(url_to_job, current_job_name, current_build_number)
  puts "waiting for job #{current_job_name} build #{current_build_number} to finish"
  begin
    current_job = JSON.parse(make_get_request(url_to_job + "/#{current_build_number}/api/json").body)
    sleep 15
    puts "_"
  end while current_job["result"].nil?
  puts "Job #{current_job_name} build #{current_build_number} with result of #{current_job['result']}"

  current_job["result"]
end

def get_artifact_from_job(project, url_to_job)
  artifacts_to_get = project[project.keys.first]["test_result_artifacts"]
  return "No artifact to get from config" unless artifacts_to_get

  job = JSON.parse(make_get_request(url_to_job + "/api/json").body)
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

  response = make_get_request url
  open("#{@artifact_dir}/#{file}", "wb") {|save_file| save_file.write(response.body)}
end

def unzip_file(url)

  url =~ /([\w\.]*)$/
  file = $1

 if file.include? ".zip"
   puts "Unzipping #{file}"
   puts `cd #{@artifact_dir}; unzip #{file}; cd -`
#  `rm -rf #{@artifact_dir}/#{file}`
 end
end



def get_basic_auth_credentials
  if @config["basic_auth"]
    username = @config["basic_auth"]["username"]
    password = @config["basic_auth"]["password"]

    unless username.nil? or password.nil?
      return username, password
    end
  end
end

def check_if_any_job_failed(job_results)
  job_failed = false

  job_results.keys.each do |job_name|
    puts "#{job_name} - #{job_results[job_name][:result]} - #{job_results[job_name][:link_to_job_console]}"

    job_failed = true if job_results[job_name][:result] != "SUCCESS"
  end

  exit 1 if job_failed

end

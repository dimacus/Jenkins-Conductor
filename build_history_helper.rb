module BuildHistoryHelper

  def get_all_builds_for_job
    JSON.parse(make_get_request(url + "/api/json").body)["builds"]
  end

  def is_current_job?(job_info, parent_build_id, parent_job_name)
    historical_build = get_historical_build_info("#{url}/#{job_info["number"]}")
    build_match      = historical_build["parent_job_build_id"].to_i == parent_build_id.to_i
    project_match    = historical_build["parent_job_name"]          == parent_job_name

    build_match == true and project_match == true
  end

  def get_historical_build_info(url_to_build)
    parameters_to_return = {}
    job_info = JSON.parse(make_get_request(url_to_build + "/api/json").body)
    
    if job_info["actions"].first["parameters"]
      job_info["actions"].first["parameters"].each {|parameter| parameters_to_return[parameter["name"]] = parameter["value"] }
    end
    
    parameters_to_return
  end

end

class JenkinsJob
  include HttpHelper

  attr_reader :parent_job_name, :parent_job_id, :jenkins_base_url, :job_name

  def initialize(parent_job, parent_job_id, job_config, full_config)
    @job_name         = job_config.keys.first
    @parent_job_name  = parent_job
    @parent_job_id    = parent_job_id
    @jenkins_base_url = full_config["jenkins_base_url"]
    @basic_auth       = {"username" => full_config["basic_auth"]["username"], "password" => full_config["basic_auth"]["password"]} if full_config["basic_auth"]
    @job_config       = job_config
  end


  def trigger_job
    make_post_request("#{url}/buildWithParameters", params)
    wait_for_job_to_start()
  end

  def url
    @job_url ||= "#{@jenkins_base_url}/view/All/job/#{@job_name}"
  end

  def params
    @params ||= @job_config[@job_name]["params"].merge({"parent_job_name" => @parent_job_name, "parent_job_build_id" => @parent_job_id})
  end

  private

  def wait_for_job_to_start()
      require 'debug'
      get_all_builds_for_job
  end

  def get_all_builds_for_job
    JSON.parse(make_get_request(url + "/api/json").body)
  end


end
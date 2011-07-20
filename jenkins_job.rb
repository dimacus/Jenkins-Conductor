
class JenkinsJob
  include HttpHelper
  include BuildHistoryHelper

  attr_reader :parent_job_name,
              :parent_build_id,
              :jenkins_base_url,
              :job_name,
              :build_id,
              :result,
              :continue_on_failure,
              :test_artifacts,
              :cli_params

  def initialize(parent_job, parent_job_id, job_config, full_config, artifact_dir, cli_params)
    @job_name                    = job_config.keys.first
    @parent_job_name             = parent_job
    @parent_build_id             = parent_job_id
    @jenkins_base_url            = full_config["jenkins_base_url"]
    @basic_auth                  = {"username" => full_config["basic_auth"]["username"],
                                  "password" => full_config["basic_auth"]["password"]} if full_config["basic_auth"]
    @job_config                  = job_config
    @historical_builds_to_ignore = []
    @continue_on_failure         = job_config[@job_name].nil? ? true : job_config[@job_name]["continue_on_fail"]
    @test_artifacts              = job_config[@job_name].nil? ? "artifacts" : job_config[@job_name]["test_result_artifacts"]
    @artifact_dir                = artifact_dir
    @cli_params                  = parse_cli_params(cli_params)
  end


  def trigger_job
    make_post_request("#{url}/buildWithParameters", params)
    @build_id = wait_for_build_to_start
    @result   = wait_for_build_to_finish
  end

  def url
    @job_url ||= "#{@jenkins_base_url}/view/All/job/#{@job_name}"
  end

  def params
    return_params = {}
    return_params.merge!(params_from_yaml)
    return_params.merge!(@cli_params)
    return_params.merge!({"parent_job_name" => @parent_job_name,
                          "parent_job_build_id" => @parent_build_id})
    return_params
  end

  def get_artifacts

    unless @test_artifacts
      puts "No artifacts were specified to be downloaded"
      return
    end

    files_to_download = generate_links_to_artifacts(@test_artifacts)

    unless files_to_download.empty?
      files_to_download.each do |file|
        if file
          download_file(file)
          unzip_file(file)
        end
      end
      puts "Artifact(s) downloaded for #{@job_name}"
    else
      puts "No artifacts were specified to be downloaded for #{@job_name}"
    end

  end

  private

  def parse_cli_params(cli_params)
    return_hash = {}
    cli_params.split(/,/).each do |single_param|
      key, value = single_param.split(/=/)
      return_hash[key] = value
    end

    return_hash
  end

  def params_from_yaml
    params = {}
    unless @job_config[@job_name].nil?
     params = params.merge(@job_config[@job_name]["params"]) if @job_config[@job_name]["params"]
    end
    
    params
  end

  def unzip_file(url)

    url =~ /([\w\.]*)$/
    file = $1

   if file.include? ".zip"
     puts "Unzipping #{file}"
     `cd #{@artifact_dir}; unzip #{file}; cd -`
   end
  end

  def wait_for_build_to_finish
    puts "Waiting for job #{@job_name} - #{url}/#{@build_id} to finish"
    begin

      current_build = JSON.parse(make_get_request(url + "/#{@build_id}/api/json").body)
      sleep 15
    end while current_build["building"]

    puts "Job #{@job_name} build #{@build_id} with result of #{current_build['result']}"

    @build_api_response = current_build

    current_build["result"]
  end

  def wait_for_build_to_start(timeout = 1200) #Wait for 20 mins before timing out

    puts "Waiting for job #{@job_name} build  to start"
    start_time = Time.now
    begin

      build_history = get_all_builds_for_job

      build_history.each do |historical_build|
        unless @historical_builds_to_ignore.include?(historical_build["number"].to_i)
          if is_current_job?(historical_build, @parent_build_id, @parent_job_name)
            return historical_build["number"]
          else
            @historical_builds_to_ignore << historical_build["number"].to_i
          end
        end
      end

    sleep 10

    end while (Time.now - start_time).to_i < timeout

    throw "Waited for job to start for #{timeout} seconds and timed out"
  end

  def generate_links_to_artifacts(artifact_array = [])

    files_to_download = artifact_array.collect do |artifact|

      matched_artifact_info = @build_api_response["artifacts"].select do |published_artifact|
        published_artifact["fileName"] == artifact
      end.first

      if matched_artifact_info
        link = "#{url}/#{@build_id}/artifact/#{matched_artifact_info['relativePath']}"
      else
        puts "Artifact '#{artifact}' was marked to be downloaded, but was not published in the job"
        link = nil
      end

      link
    end

    files_to_download
  end
end
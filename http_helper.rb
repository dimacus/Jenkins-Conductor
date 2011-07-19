require "net/http"
require "uri"

module HttpHelper
  def make_get_request(url)
   uri = URI.parse(url)

   http = Net::HTTP.new(uri.host, uri.port)

   request = Net::HTTP::Get.new(uri.request_uri)

   if get_basic_auth_credentials
     username, password = get_basic_auth_credentials
     request.basic_auth username, password
   end

   http.request(request)
  end

  def make_post_request(url, params)
   uri = URI.parse(url)

   http = Net::HTTP.new(uri.host, uri.port)

   request = Net::HTTP::Post.new(uri.request_uri)

   if get_basic_auth_credentials
     username, password = get_basic_auth_credentials
     request.basic_auth username, password
   end

   request.set_form_data(params) if params

   begin
    http.request(request)
   rescue
      puts "\n\nERROR:\n\nCould not reach #{url}\n\n"
      exit 1
   end
  end

  def download_file(url)
    puts "Downloading #{url}"
    url =~ /([\w\.]*)$/
    file = $1

    response = make_get_request url
    open("#{@artifact_dir}/#{file}", "wb") {|save_file| save_file.write(response.body)}
  end

  def get_basic_auth_credentials
    if @basic_auth
      username = @basic_auth["username"]
      password = @basic_auth["password"]

      unless username.nil? or password.nil?
        return username, password
      end
    end
  end
end
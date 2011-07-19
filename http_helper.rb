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

   http.request(request)
  end
end
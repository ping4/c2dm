require 'httparty'
require 'cgi'

class C2DM
  include HTTParty
  default_timeout 30

  attr_accessor :timeout, :auth_token

  AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
  PUSH_URL = 'https://android.apis.google.com/c2dm/send'

  def initialize()
  end

  def authenticate!(username, password, source = nil)
    auth_options = {
      'accountType' => 'HOSTED_OR_GOOGLE',
      'service'     => 'ac2dm',
      'Email'       => username,
      'Passwd'      => password,
      'source'      => source || 'MyCompany-MyAppName-1.0'
    }
    response = post_message(AUTH_URL,auth_options, nil)

    # check for authentication failures
    if response['Error=']
      raise response.parsed_response
    else
      @auth_token = response.body.split("\n")[2].gsub('Auth=', '')
    end

    self
  end

  def send_notifications(notifications = [])
    notifications.collect do |notification|
      {
        :body => c2dm.send_notification(notification),
        :registration_id => notification[:registration_id]
      }
    end
  end

  # {
  #   :registration_id => "...",
  #   :data => {
  #     :some_message => "Hi!", 
  #     :another_message => 7
  #   }
  #   :collapse_key => "optional collapse_key string"
  # }
  def send_notification(options)
    options[:collapse_key] ||= 'foo'
    response = post_message(PUSH_URL, options)

  end

  private

  def build_post_body(options={})
    post_body = []

    # data attributes need a key in the form of "data.key"...
    data_attributes = options.delete(:data)
    data_attributes.each_pair do |k,v|
      post_body << "data.#{k}=#{CGI::escape(v.to_s)}"
    end if data_attributes

    options.each_pair do |k,v|
      post_body << "#{k}=#{CGI::escape(v.to_s)}"
    end

    post_body.join('&')
  end

  def post_message(url, params, auth_token=@auth_token)
    post_body = build_post_body(params)

    post_params = {
      :body    => post_body,
      :headers => {
        'Content-type'   => 'application/x-www-form-urlencoded',
        'Content-length' => post_body.length.to_s
      }
    }
    post_params[:headers]['Authorization'] = "GoogleLogin auth=#{auth_token}" if auth_token

    http_post(url, post_params)
  end

  def http_post(url, params)
    response = self.class.post(url, params)
  end
end

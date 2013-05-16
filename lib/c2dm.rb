require 'httparty'
require 'cgi'
require 'uri'

class C2DM
  class InvalidAuth < StandardError ; end
  include HTTParty
  default_timeout 30

  attr_accessor :timeout, :auth_token

  AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
  PUSH_URL = 'https://android.apis.google.com/c2dm/send'

  def initialize()
  end

  def authenticate!(username, password, source)
    auth_options = {
      'accountType' => 'HOSTED_OR_GOOGLE',
      'service'     => 'ac2dm',
      'Email'       => username,
      'Passwd'      => password,
      'source'      => source
    }
    response = post_message(AUTH_URL,auth_options, nil)
    body = Hash[response.body.split("\n").map {|r| r.split("=")}]

    # check for authentication failures
    if body['Error']
      raise raise InvalidAuth.new(body['Error'])
    else
      @auth_token = body['Auth']
    end

    self
  end

  def send_notifications(notifications = [])
    notifications.collect { |notification| c2dm.send_notification(notification) }
  end

  # input:
  # {
  #   :registration_id => "...",
  #   :data => {
  #     :some_message => "Hi!", 
  #     :another_message => 7
  #   }
  #   :collapse_key => "optional collapse_key string"
  # }
  # results:
  # {
  #   registration_id: "...",
  #   body: response
  # }
  def send_notification(options)
    options[:collapse_key] ||= 'foo'
    response = post_message(PUSH_URL, options)
    body = Hash[URI.decode_www_form(response.body)]

    result = {
      code:            response.code,
      response:        body['Error'],
      body:            response,
      registration_id: options[:registration_id]
    }


#    body = Hash[response.body.split(('&').map{|l| l.split('=')})]
    headers = response.headers

    case response.code
    when 200
      case body['Error']
      when 'QuotaExceeded', 'DeviceQuotaExceeded' #406 Not Acceptable
        result[:code]=406
      when 'DeviceQuotaExceeded' #406 Not Acceptable
        result[:code]=406
      when 'InvalidRegistration', 'NotRegistered' #404 Not Found
        result[:code]=404
      when 'MessageTooBig', 'MissingCollapseKey' #400 Bad Request
        result[:code]=400
        #invalid message
      else
        result[:response]='Success' #200 Created
      end
    when 401
      result[:response]='AUTH_TOKEN' #401 Unauthorized
      raise InvalidAuth.new(response.body)
    when 404
      # concerned that a 404 will get confused with token not found
      raise InvalidAuth.new(response.body)
    when 503
      result[:response]='Retry' #503 Server Unavailable
      result[:retry_after]=response.headers['Retry-After']
    end

    result
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
      body:    post_body,
      headers: {
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

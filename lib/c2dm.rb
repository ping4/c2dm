require 'net/http/persistent'
require 'cgi'
require 'uri'

class C2DM
  class InvalidAuth < StandardError ; end

  attr_accessor :timeout, :auth_token

  AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
  PUSH_URL = 'https://android.apis.google.com/c2dm/send'

  def initialize(options={})
    @http     = Net::HTTP::Persistent.new 'c2dm'
    #@http.debug_output = $stderr
    # google certificate for c2dm is not valid, turn off VERIFY_PEER (default)
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @auth_uri = URI(options[:auth_url] || AUTH_URL)
    @push_uri = URI(options[:push_url] || PUSH_URL)
    @auth_token = options[:auth_token]
  end

  def authenticate!(username, password, source)
    return if @auth_token
    auth_options = {
      'accountType' => 'HOSTED_OR_GOOGLE',
      'service'     => 'ac2dm',
      'Email'       => username,
      'Passwd'      => password,
      'source'      => source
    }
    response = post_message(@auth_uri, auth_options, nil)
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
    notifications.collect { |notification| send_notification(notification) }
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
  #   body: response,
  #   code: [200,400,401,404,406,503]
  # }
  def send_notification(options)
    if ! authenticated?
      return {
        code: 401,
        response: 'no AUTH_TOKEN',
        body: nil,
        registration_id: options[:registration_id]
      }
    end
    options[:collapse_key] ||= 'foo'
    response = post_message(@push_uri, options)
    body = Hash[URI.decode_www_form(response.body)]
#    body = Hash[response.body.split(('&').map{|l| l.split('=')})]

    result = {
      code:            response.code,
      response:        body['Error'],
      body:            response,
      registration_id: options[:registration_id]
    }

    case response.code.to_i
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
      unauthenticate!
      raise InvalidAuth.new(response.body)
    when 404
      # concerned that a 404 will get confused with token not found
      unauthenticate!
      raise InvalidAuth.new(response.body)
    when 503
      result[:response]='Retry' #503 Server Unavailable
      result[:retry_after]=response.get_field('Retry-After')
    end

    result
  end

  def close
    @http.shutdown
  end

  def authenticated?
    !! @auth_token
  end

  def unauthenticate!
    @auth_token=nil
  end

  private

  def flatten_post_body(options={})
    options = options.dup
    if data_attributes = options.delete(:data)
      data_attributes.each_pair do |k,v|
        options["data.#{k}"] = v
      end
    end
    options
  end

  def post_message(url, params, auth_token=@auth_token)
    http_post(url, flatten_post_body(params), auth_token)
  end

  def http_post(url, body, auth_token)
    post = Net::HTTP::Post.new url.path

    post.form_data = body
    post.add_field('Authorization', "GoogleLogin auth=#{auth_token}") if auth_token

    @http.request url, post
  end
end

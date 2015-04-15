require 'rest_client'
require 'hmac-sha1'
require 'base64'
require 'uri'
class Quickblox

  QUICKBLOX_URL  = "https://api.quickblox.com/"
  CREATE_DIALOG = QUICKBLOX_URL + "chat/Dialog"
  ACCOUNT_SETTINGS = QUICKBLOX_URL + "account_settings"
  START_SESSION = QUICKBLOX_URL + 'session'
  LOGIN = QUICKBLOX_URL + 'login'
  
  def initialize(token=nil, type='json')
    configs
    @type = type
    @token = token
    @token_type = nil
    @headers = {'QuickBlox-REST-API-Version' => '0.1.1'}#, 'QB-Token' => @token_type}
    @headers['QB-Token'] = @token if @token 
  end

  def type
    @type
  end
  
  def headers
    @headers
  end
  
  def destroy_token
    delete_for('session')
  end
  
  def get_token(type= 'app', login=nil, password=nil)
    destroy_token if @token
    response = post_for('session', signed_params(type, login, password))
    @token_type = type
    @user_id = response["session"]["user_id"]
    @token = response["session"]["token"]
    @headers['QB-Token'] = @token 
    return @token
  end

  def token
    @token
  end
  
  def login(login, password)
    set_qb_header
    params = {'login' => login, 'password' => password}
    post_for('login', params)
  end
  
  def signup(login, password, email, optional={})
    set_qb_header
    params = {:user => {:login => login, :email => email, :password => password}}
    add_optional_parameter(params[:user], optional) unless optional.empty?
    p params
    post_for('users', params)
  end
  
  def update_user(id, optional={})
    set_qb_header
    params = {user: optional}
    put_for("users/#{id}", params)
  end

  def delete_user(id)
    set_qb_header
    delete_for("users/#{id}")
  end

  def get_user_by_id(id)
    set_qb_header 
    get_for("users/#{id}") 
  end

  def get_user_by_login(login)
    set_qb_header
    get_for("users/by_login", {login: login})
  end

  def get_user_by_email(email)
    set_qb_header
    get_for("users/by_email", {email: email})
  end

  def get_user_by_full_name(full_name)
    set_qb_header
    get_for("users/by_full_name", {full_name: full_name})
  end
  
  def get_user_by_facebook_id(fb_id)
    set_qb_header
    get_for("users/by_facebook_id", {facebook_id: fb_id})
  end

  def get_user_by_twitter_id(twitter_id)
    set_qb_header
    get_for('users/by_twitter_id', {twitter_id: twitter_id})
  end


  def get_dialog
    set_qb_header
    get_for('chat/Dialog')
  end

  def create_dialog(type, name, occupants_ids, optionals={})
    set_qb_header 
    occupants_ids = occupants_ids.join(',')
    params = {:type => type, :name => name, :occupants_ids => occupants_ids}
    add_optional_parameter(params, optionals)
    post_for('chat/Dialog', params)
  end

  def update_chat_dialog(muc_id, push_all, pull_all, name=nil)
    set_qb_header
    params = create_query_string_for_update_dialog(push_all, pull_all, name)
    p params
    put_for("chat/Dialog/#{muc_id}", params)
  end

private
  def create_query_string_for_update_dialog(push_all, pull_all, name)
    query = {}
    query["push_all"] = {:occupants_ids => push_all} if push_all
    query["pull_all"] = {:occupants_ids => pull_all} if pull_all
    query["name"] = name if name
    query
  end

  def add_optional_parameter(params, optional)
    optional.keys.each do |key| 
      params[key] = optional[key]
    end
  end

  def set_qb_header
    get_token unless @token
  end
 
  def configs
    config = YAML.load_file("config.yml")
    @application_id = config["quickblox"]["application_id"]
    @auth_key = config["quickblox"]["auth_key"]
    @auth_secret = config["quickblox"]["auth_secret"]
    @user_owner_id = config["quickblox"]["user_owner_id"]
    @server=config["quickblox"]["server"]
    #to remove - for debug
    @user_login=config["quickblox"]["user_login"]
    @user_password=config["quickblox"]["user_password"]
    @device_platform= config["quickblox"]["device_platform"]
    @device_udid= config["quickblox"]["device_udid"]
  end

  
  def generate_url(target)
    QUICKBLOX_URL + target + '.' + type
  end

#-------Token-------#

  def signed_params(type, login, password)
    qp = query_params(type, login, password)
    qp[:signature]  = generate_signature(qp)
    qp
  end

  def generate_signature(qp)
    p convert_to_params(qp)
    HMAC::SHA1.hexdigest(@auth_secret, convert_to_params(qp))
  end

  def query_params(type, login, password)
    timestamp = Time.now.to_i
    nonce = rand(10000)
    qp = {:application_id => @application_id, :nonce => nonce, :auth_key => @auth_key, :timestamp => timestamp}
    add_user_info(qp, login, password) if ['user', 'user_device'].include?(type)
    add_device_info(qp) if ['device', 'user_device'].include?(type)
    qp
  end

  def add_user_info(qp, login, password)
    if login
      qp.merge!({:user => {:login => login, :password => password}}) #, :owner_id => @user_owner_id}})
    else
      qp.merge!({:user => {:login => @user_login, :password => @user_password, :owner_id => @user_owner_id}})
    end
  end
  
  def add_device_info(qp)
    qp.merge!({:device => {:platform => @device_platform, :udid => @device_udid }})
  end

  def convert_to_params(hash)
    hash.collect { |k, v|
      if v.is_a? Hash
        v.collect{|k1, v1| "#{k}[#{k1}]=#{v1}" }.sort.join('&')
      else
        "#{k}=#{v}"
      end
    }.sort.join('&')
  end


#------end----------#

def generate_url_with_parmeter(resource, params)
  URI.escape(generate_url(resource) + '?' +  convert_to_params(params))
end
'-------HTTP CALLS-----------'
  def delete_for(resource)
    p generate_url(resource)
    p parse_json_nil(RestClient.delete generate_url(resource), headers)
  end

  def get_for(resource, params={})
    p generate_url_with_parmeter(resource, params)
    parse_json_nil(RestClient.get generate_url_with_parmeter(resource, params), headers)
  end

  def post_for(resource, params)
    begin
      parse_json_nil(RestClient.post generate_url(resource), params, headers)
    rescue => e
      p e
    end
  end
  
  def put_for(resource, params)
    begin
      parse_json_nil(RestClient.put generate_url(resource), params, headers)
    rescue => e
      p e
    end
  end

  def parse_json_nil(json)
    JSON.parse(json) if json && json.length >= 2
  end
end

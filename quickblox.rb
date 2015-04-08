require 'rest_client'
require 'hmac-sha1'
require 'base64'
require 'uri'
class QuickBlox
  QUICKBLOX_URL  = "https://api.quickblox.com/"
  
  def initialize(type='json')
    configs
    @type = type
    @token = nil
    @token_type = nil
    @headers = {'QuickBlox-REST-API-Version' => '0.1.1'}
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
  
  def get_token(type= 'app')
    destroy_token if @token
    response = post_for('session', signed_params(type))
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
    set_qb_header if not @token 
    params = {'login' => login, 'password' => password}
    post_for('login', params)
  end
  
  def create_dialog(type, occupants_ids, name, optionals={})
    set_qb_header if not @token
    occupants_ids = occupants_ids.join(',')
    params = {:type => type, :name => name, :occupants_ids => occupants_ids}
    post_for('chat/Dialog', params)
  end
  
private
  
  def set_qb_header
    get_token
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

  def signed_params(type)
    qp = query_params(type)
    qp[:signature]  = generate_signature(qp)
    qp
  end

  def generate_signature(qp)
    HMAC::SHA1.hexdigest(@auth_secret, convert_to_params(qp))
  end

  def query_params(type)
    timestamp = Time.now.to_i
    nonce = rand(10000)
    qp = {:application_id => @application_id, :nonce => nonce, :auth_key => @auth_key, :timestamp => timestamp}
    add_user_info(qp) if ['user', 'user_device'].include?(type)
    add_device_info(qp) if ['device', 'user_device'].include?(type)
    qp
  end

  def add_user_info(qp)
    qp.merge!({:user => {:login => @user_login, :password => @user_password, :owner_id => @user_owner_id}})
  end
  
  def add_device_info(qp)
    qp.merge!({:device => {:platform => @device_platform, :udid => @device_udid }})
  end

  def convert_to_params(hash)
    hash.collect { |k, v|
      if v.is_a? Hash
        v.collect{|k1, v1| "#{k}[#{k1}=#{v1}" }.sort.join('&')
      else
        "#{k}=#{v}"
      end
    }.sort.join('&')
  end


#------end----------#


'-------HTTP CALLS-----------'
  def delete_for(resource)
    p generate_url(resource)
    p parse_json_nil(RestClient.delete generate_url(resource), headers)
  end

  def post_for(resource, params, headers=headers)
    p headers 
    parse_json_nil(RestClient.post generate_url(resource), params, headers)
  end
  
  def parse_json_nil(json)
    JSON.parse(json) if json && json.length >= 2
  end
end

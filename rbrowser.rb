# A scriptable web browser for use with crawlers/scrapers/automators.
#
# @author Daniel Tomasiewicz
#
# Example usage:
# 
#   b = Browser.new :chrome
#   b.get 'http://google.ca' do
#     b.get '/?q=hello+world' do |res|
#       puts res
#     end
#   end
#
# The above will:
#  - make a GET request to http://google.ca
#  - follow the redirect to https://www.google.ca
#  - make a GET request to https://www.google.ca/?q=hello+world with
#    http://www.google.ca as the referer and print the output
#  - and it will appear to the web server as though all this was done by a 
#    human using Google Chrome (except, of course, it'll be faster)
#

require 'net/http'
require 'uri'
require 'cgi'
require 'openssl'
require 'date'
require 'nokogiri'

class Browser

  USER_AGENTS = {
    default: 'rBrowser',
    chrome: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.79 Safari/535.11'
  }
  
  attr_accessor :user_agent, :cookies
  
  def initialize(user_agent = :default)
    @user_agent = USER_AGENTS[user_agent] || user_agent
    @cookies = {}
    @conns = {}
  end
  
  def post(url, data = {}, params = {}, &block)
    request Net::HTTP::Post, url, params.dup.merge(:data => data), &block
  end
  
  def get(url, params = {}, &block)
    request Net::HTTP::Get, url, params, &block
  end
  
  private
  
  def ssl_version
    [:SSLv3,:SSLv23,:SSLv2].each do |v|
      return v if OpenSSL::SSL::SSLContext::METHODS.include? v
    end
    raise "Could not find a suitable SSL version for use with OpenSSL."
  end
  
  def request(klass, url, params = {})
    url = URI.parse url
    if !url.scheme
      # if only a path is given, get rest from referer
      if @referer
        ref = URI.parse @referer
        url.scheme = ref.scheme
        url.host = ref.host
        url.port = ref.port
      else
        raise "Must give a full URL when outside of a block."
      end
    end
    url.path = '/' if url.path.empty?
    
    http = conn url.host, url.port
    if url.scheme == 'https'
      http.use_ssl = true
      http.ssl_version = ssl_version
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE #insecure!
    else
      http.use_ssl = false
    end
    
    req = klass.new url.path
    if params[:data]
      req.set_form_data params[:data]
    end
    request_headers.each_pair do |h,v|
      req[h] = v
    end
      
    res = http.request req
    
    # parse all Set-Cookie headers
    if scfields = res.get_fields('Set-Cookie')
      scfields.each do |sc|
        set_cookie sc
      end
    end
    
    # follow redirects
    unless params[:no_follow]
      while loc = res['Location']
        if loc =~ /^\//
          # compensate for spec-defying path-passers
          loc = "#{url.scheme}://#{url.host}:#{url.port}"+loc
        end
        with_referer url.to_s do
          res = request(Net::HTTP::Get, loc, :no_follow => true).http
        end
      end
    end
    
    res = BrowserResponse.new res
    
    if block_given?
      with_referer url.to_s do
        yield res if block_given?
      end
    end
    
    res
  end
  
  def with_referer(ref, &block)
    old_ref = @referer
    @referer = ref
    yield if block_given?
    @referer = old_ref
  end
  
  def set_cookie(sc)
    name, sc = sc.split '=', 2
    name = CGI::unescape(name)
    value, sc = sc.split ';', 2
    value = CGI::unescape(value)
    opts = {}
    sc && sc.split(';').each do |opt|
      opt, optval = opt.split '=', 2
      opts[opt.downcase] = (optval && CGI::unescape(optval)) || true
    end
    @cookies[name] = CGI::Cookie.new({
      'name' => name,
      'value' => value,
      'path' => opts['path'] || '/',
      'domain' => opts['domain'],
      'expires' => opts['expires'] ? DateTime.parse(opts['expires']) : nil,
      'secure' => opts['secure']
    })
  end
  
  def request_headers
    headers = {'User-Agent' => @user_agent}
    if @cookies.length > 0
      headers['Cookie'] = @cookies.values.map do |c|
        "#{CGI::escape(c.name)}=#{CGI::escape(c.value.first)}"
      end.join ';'
    end
    headers
  end
  
  def conn(host, port)
    @conns[[host,port]] ||= Net::HTTP.new host, port
  end
  
end

class BrowserResponse
  attr_reader :http
  
  def initialize(http_response)
    @http = http_response
  end
  
  def dom
    @dom ||= Nokogiri::HTML(@http.body)
  end
  
  def form_data(selector)
    node = dom.at_css selector
    node ? collect_form_data(node) : nil
  end
  
end

def collect_form_data(form_node)
  data = {}
  form_node.css('input,select,textarea,button').each do |el|
    if el['name']
      case el.name.downcase
      when 'input'
        case el['type'].downcase
        when 'radio','checkbox'
          data[el['name']] = el['value'] || 1 if el.matches?('[@checked="checked"]')
        when 'submit', 'reset'
          # do nothing
        else
          data[el['name']] = el['value']
        end
      when 'select'
        selected = el.at_css 'option[@selected="selected"]'
        data[el['name']] = selected['value'] if selected
      when 'textarea'
        data[el['name']] = el.inner_text # should this be decoded?
      # do nothing with BUTTON
      end
    end
  end
  data
end

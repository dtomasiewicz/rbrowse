# A scriptable web browser for use with crawlers/scrapers/automators.
#
# @author Daniel Tomasiewicz
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
  
  DEFAULT_PORTS = {
    https: 443,
    http: 80
  }
  
  attr_accessor :user_agent
  
  def initialize(user_agent = :default)
    @user_agent = USER_AGENTS[user_agent] || user_agent
    @cookies = []
    @conns = {}
  end
  
  def post(url, data = {}, params = {}, &block)
    request Net::HTTP::Post, url, params.dup.merge(:data => data), &block
  end
  
  def get(url, params = {}, &block)
    request Net::HTTP::Get, url, params, &block
  end
  
  # injects the given data into the query string
  def get_with_data(url, data = {}, params = {}, &block)
    # stringify keys
    data.keys.each do |k|
      data[k.to_s] = data.delete k
    end
    url = split_url url
    qs = (url[:query] ? CGI::parse(url[:query]) : {}).merge data
    url[:query] = qs.keys.map{|k|"#{CGI::escape k}=#{CGI::escape qs[k]}"}.join '&'
    get join_url(url), params, &block
  end
  
  def cookies(domain, path = '/')
    # delete expired cookies
    @cookies = @cookies.reject{|c|c[:expires] && c[:expires] <= DateTime.now}
    
    # TODO: this is slow; come up with a better way to index cookies by domain/path
    matched_cookies = {}
    @cookies.each do |c|
      if domain == c[:domain] || c[:domain].end_with?('.'+domain)
        if path.start_with?(c[:path])
          matched_cookies[c[:name]] = c
        end
      end
    end
    matched_cookies
  end
  
  private
  
  def ssl_version
    [:SSLv3,:SSLv23,:SSLv2].each do |v|
      return v if OpenSSL::SSL::SSLContext::METHODS.include? v
    end
    raise "Could not find a suitable SSL version for use with OpenSSL."
  end
  
  def request(klass, url, params = {})
    url = split_url url
    if !url[:scheme]
      # if only a path is given, get rest from referer
      if @referer
        url = full_url url, split_url(@referer)
      else
        raise "Must give a full URL when outside of a block."
      end
    end
    url[:path] = '/' if url[:path] == ''
    
    http = conn url[:host], (url[:port] || DEFAULT_PORTS[url[:scheme].to_sym])
    if url[:scheme] == 'https'
      http.use_ssl = true
      http.ssl_version = ssl_version
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE # unsafe
    else
      http.use_ssl = false
    end
    
    # create request object
    req = klass.new "#{url[:path]}#{'?'+url[:query] if url[:query]}"
    
    # set request headers
    req['Host'] = url[:host]
    req['Host'] += ':'+url[:port] if url[:port]
    req['User-Agent'] = @user_agent
    if cookie = get_url_cookie(url)
      req['Cookie'] = cookie 
    end
    
    # append data
    if params[:data]
      req.set_form_data params[:data]
    end
    
    # execute
    res = http.request req
    
    # parse Set-Cookie response headers
    if scfields = res.get_fields('Set-Cookie')
      scfields.each do |sc|
        set_url_cookie url, sc
      end
    end
    
    # follow redirects
    unless params[:no_follow]
      while loc = res['Location']
        loc = split_url loc
        if !loc[:scheme]
          # compensate for spec-defying path-passers
          loc = full_url loc, url
        end
        with_referer join_url(url) do
          res = request(Net::HTTP::Get, join_url(loc), :no_follow => true).http
        end
        url = loc
      end
    end
    
    res = BrowserResponse.new res
    
    if block_given?
      with_referer join_url(url) do
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
  
  # produces a cookie header for a split request url
  def get_url_cookie(url)
    matched_cookies = cookies url[:host], url[:path]
    if matched_cookies.length > 0
      return matched_cookies.values.map do |c|
        "#{CGI::escape(c[:name])}=#{CGI::escape(c[:value])}"
      end.join ';'
    else
      return nil
    end
  end
  
  def set_url_cookie(url, cookie)
    name, cookie = cookie.split '=', 2
    name = CGI::unescape(name)
    value, cookie = cookie.split ';', 2
    value = CGI::unescape(value)
    opts = {}
    cookie && cookie.split(';').each do |opt|
      opt, optval = opt.split '=', 2
      opts[opt.downcase] = (optval && CGI::unescape(optval)) || true
    end
    
    parsed = {
      name: name,
      value: value,
      path: opts['path'],
      domain: opts['domain'],
      expires: opts['expires'] ? DateTime.parse(opts['expires']) : nil,
      secure: opts['secure']
    }
    parsed[:path] ||= url[:path][0..url[:path].rindex('/')]
    # restrict to setting domain
    # not spec-compliant and possibly unsafe (allows infinite levels of subdomains)
    unless parsed[:domain] &&
      (parsed[:domain] == url[:host] || parsed[:domain].end_with?('.'+url[:host]))
      parsed[:domain] = url[:host]
    end
    
    @cookies << parsed
  end
  
  def conn(host, port)
    @conns[[host,port]] ||= Net::HTTP.new host, port
  end
  
  def split_url(url)
    Hash[[:scheme, :userinfo, :host, :port, :registry, :path, :opaque, :query, :fragment].zip URI::split(url)]
  end
  
  def join_url(url)
    out = ""
    out += url[:scheme]+"://" if url[:scheme]
    if url[:scheme] || url[:host]
      out += url[:userinfo]+"@" if url[:userinfo]
      out += url[:host]
      out += ":"+url[:port] if url[:port]
    end
    out += url[:path] if url[:path]
    out += "?"+url[:query] if url[:query]
    out += "#"+url[:fragment] if url[:fragment]
    #todo: not sure what to do with registry, opaque
    out
  end
  
  def full_url(partial, ref)
    partial.merge :scheme => ref[:scheme],
                  :userinfo => ref[:userinfo],
                  :host => ref[:host],
                  :port => ref[:port]
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
  
  def to_s
    @http.body
  end
  
end

# note: values from BUTTON and input[type=button|submit|image|reset] are 
#   traditionally only sent when clicked to provoke form submission, any 
#   many websites rely on browsers behaving this way. because of this,
#   collect_form_data does ignores any such values. if you want the website
#   to think you selected a particular submission component, you'll have to
#   add in that element's value manually.
def collect_form_data(form_node)
  data = {}
  form_node.css('input,select,textarea').each do |el|
    if el['name']
      case el.name.downcase
      when 'input'
        case el['type'].downcase
        when 'radio', 'checkbox'
          if el.matches?('[@checked="checked"]')
            data[el['name']] = el['value'] || 1
          end
        when 'submit', 'reset', 'image', 'button'
          # ignore
        else # assume a text box at this point
          data[el['name']] = el['value']
        end
      when 'select'
        selected = el.at_css 'option[@selected="selected"]'
        data[el['name']] = selected['value'] if selected
      when 'textarea'
        data[el['name']] = el.inner_text # TODO: check if this should be decoded
      end
    end
  end
  data
end

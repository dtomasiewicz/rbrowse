module RBrowse

  class Browser
    
    DEFAULT_PORTS = {
      'https' => 443,
      'http' => 80
    }
    
    attr_accessor :user_agent
    
    def initialize(user_agent = 'RBrowse')
      @user_agent = user_agent
      @cookies = CookieJar.new
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
      url = normalize_url url
      qs = (url.query ? CGI::parse(url.query) : {}).merge data
      url.query = qs.keys.map{|k|"#{CGI::escape k}=#{CGI::escape qs[k]}"}.join '&'
      get url, params, &block
    end
    
    def cookies(url)
      @cookies.for_url normalize_url(url)
    end
    
    def connection(url)
      url = normalize_url url
      port = url.port || DEFAULT_PORTS[url.scheme]
      id = [url.host, port, url.scheme]
      unless conn = @conns[id]
        conn = @conns[id] = Net::HTTP.new(url.host, port)
        if url.scheme == 'https'
          conn.use_ssl = true
          conn.ssl_version = ssl_version
          conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
      end
      conn
    end
    
    private
    
    def normalize_url(url)
      # dup it in case it's changed
      url = url.kind_of?(String) ? URL.new(url) : url.dup
      url.path = '/' if url.path.empty?
      
      if !url.full?
        # if only a path is given, get rest from referer
        if @referer
          url.absolute! @referer
        else
          raise "Must give a full URL when outside of a block."
        end
      end
      
      url
    end
    
    def ssl_version
      [:SSLv3,:SSLv23,:SSLv2].each do |v|
        return v if OpenSSL::SSL::SSLContext::METHODS.include? v
      end
      raise "Could not find a suitable SSL version for use with OpenSSL."
    end
    
    def request(klass, url, params = {})
      url = normalize_url url
      
      # create request object
      req = klass.new "#{url.path}#{'?'+url.query if url.query}"
      
      # set request headers
      req['Host'] = url.host
      req['Host'] += ':'+url.port if url.port
      req['User-Agent'] = @user_agent
      if cookie = @cookies.request_header(url)
        req['Cookie'] = cookie
      end
      
      # append data
      req.set_form_data params[:data] if params[:data]
      
      # execute          
      http = connection url
      http.start if !http.started?
      res = http.request req
      
      # parse Set-Cookie response headers
      if sc_fields = res.get_fields('Set-Cookie')
        sc_fields.each{|sc| @cookies.set_cookie url, sc}
      end
      
      # follow redirects
      unless params[:no_follow]
        while res['Location']
          # allows relative locations
          loc = normalize_url res['Location']
          with_referer url do
            res = request(Net::HTTP::Get, loc, :no_follow => true).http
          end
          url = loc
        end
      end
      
      res = Page.new res
      
      if block_given?
        with_referer url do
          yield res
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
    
  end
  
end
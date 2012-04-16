module RBrowse

  class Browser

    USER_AGENTS = {
      default: 'rBrowser',
      chrome: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.79 Safari/535.11'
    }
    
    DEFAULT_PORTS = {
      'https' => 443,
      'http' => 80
    }
    
    attr_accessor :user_agent
    
    def initialize(user_agent = :default)
      @user_agent = USER_AGENTS[user_agent] || user_agent
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
      url = URL.new url if url.kind_of?(String)
      qs = (url.query ? CGI::parse(url.query) : {}).merge data
      url.query = qs.keys.map{|k|"#{CGI::escape k}=#{CGI::escape qs[k]}"}.join '&'
      get url, params, &block
    end
    
    def cookies(url)
      url = URL.new url if url.kind_of?(String)
      @cookies.for_url url
    end
    
    private
    
    def ssl_version
      [:SSLv3,:SSLv23,:SSLv2].each do |v|
        return v if OpenSSL::SSL::SSLContext::METHODS.include? v
      end
      raise "Could not find a suitable SSL version for use with OpenSSL."
    end
    
    def request(klass, url, params = {})
      # dup the url since it may be modified
      url = url.kind_of?(String) ? URL.new(url) : url.dup
      
      if !url.scheme
        # if only a path is given, get rest from referer
        if @referer
          url.absolute! @referer
        else
          raise "Must give a full URL when outside of a block."
        end
      end
      url.path = '/' if url.path == ''
      
      http = conn url
      
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
      res = http.request req
      
      # parse Set-Cookie response headers
      if sc_fields = res.get_fields('Set-Cookie')
        sc_fields.each{|sc| @cookies.set_cookie url, sc}
      end
      
      # follow redirects
      unless params[:no_follow]
        while loc = res['Location']
          loc = URL.new loc
          if !loc.scheme
            # compensate for spec-defying path-passers
            loc.absolute! url
          end
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
    
    def conn(url)
      port = url.port || DEFAULT_PORTS[url.scheme]
      id = [url.host, port, url.scheme]
      unless (c = @conns[id]) && c.started?
        c = @conns[id] = Net::HTTP.new(url.host, port)
        if url.scheme == 'https'
          c.use_ssl = true
          c.ssl_version = ssl_version
          c.verify_mode = OpenSSL::SSL::VERIFY_NONE # unsafe
        end
        c.start
      end
      c
    end
    
  end
  
end
module RBrowse

  class Browser
    
    attr_accessor :user_agent
    
    def initialize(user_agent = 'RBrowse')
      @user_agent = user_agent
      @cookies = CookieJar.new
      @conns = {}
    end
    
    def post(uri, data = {}, params = {}, &block)
      request Net::HTTP::Post, uri, params.merge(:data => data), &block
    end
    
    def get(uri, params = {}, &block)
      request Net::HTTP::Get, uri, params, &block
    end
    
    def cookies(uri)
      @cookies.for_uri resolve(uri)
    end
    
    def connection(uri)
      uri = resolve uri
      id = [uri.host, uri.port, uri.scheme]
      unless conn = @conns[id]
        conn = @conns[id] = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme.downcase == 'https'
          conn.use_ssl = true
          conn.ssl_version = ssl_version
          conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
      end
      conn
    end
    
    private
    
    # TODO implement RFC-1808 compliant relative link expansion
    def resolve(uri)
      uri = uri.kind_of?(URI) ? uri.dup : URI.parse(uri)
      uri.path = '/' unless uri.path =~ /[^\s]/
      
      if !uri.kind_of?(URI::HTTP)
        # resolve relative URIs using the referer
        if @referer
          if !uri.path.start_with?('/')
            uri.path = @referer.path[0..@referer.path.rindex('/')]+uri.path
          end
          
          # dup the referer so that URI.to_s doesn't insert the port number unless
          # it was originally given
          uri = URI::HTTP.new @referer.scheme, @referer.userinfo, @referer.host,
            @referer.port, uri.registry, uri.path, uri.opaque, uri.query, uri.fragment
        else
          raise "Must give a full URI when outside of a block."
        end
      end
      
      # case-insensitive hosts
      uri.host = uri.host.downcase
      
      uri
    end
    
    def ssl_version
      [:SSLv3,:SSLv23,:SSLv2].each do |v|
        return v if OpenSSL::SSL::SSLContext::METHODS.include? v
      end
      raise "Could not find a suitable SSL version for use with OpenSSL."
    end
    
    def request(klass, uri, params = {})
      uri = resolve uri
      
      # create request object
      req = klass.new "#{uri.path}#{'?'+uri.query if uri.query}"
      
      # set request headers
      req['Host'] = uri.host
      req['Host'] += ":#{uri.port}" if uri.port
      req['Referer'] = @referer.to_s if @referer
      req['User-Agent'] = @user_agent
      if cookie = @cookies.request_header(uri)
        req['Cookie'] = cookie
      end
      
      # append data
      if params[:data]
        if req.kind_of?(Net::HTTP::Get)
          # inject data into querystring
          qs = (uri.query ? CGI::parse(uri.query) : {}).merge params[:data]
          uri.query = qs.keys.map{|k| encode_pair k, qs[k]}.join '&'
        else
          req.set_form_data params[:data]
        end
      end
      
      # execute
      http = connection uri
      http.start if !http.started?
      res = http.request req
      
      # parse Set-Cookie response headers
      if sc_fields = res.get_fields('Set-Cookie')
        sc_fields.each{|sc| @cookies.set_cookie uri, sc}
      end
      
      # follow redirects
      unless params[:no_follow]
        while res['Location']
          # allows relative locations
          loc = resolve res['Location']
          with_referer uri do
            res = request(Net::HTTP::Get, loc, :no_follow => true).http
          end
          uri = loc
        end
      end
      
      res = Page.new self, uri, res
      
      if block_given?
        with_referer uri do
          yield res
        end
      end
      
      res
    end
    
    def encode_pair(key, value)
      "#{CGI::escape key.to_s}=#{CGI::escape value.to_s}"
    end
    
    def with_referer(ref, &block)
      old_ref = @referer
      @referer = ref
      yield if block_given?
      @referer = old_ref
    end
    
  end
  
end
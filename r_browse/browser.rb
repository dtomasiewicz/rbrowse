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
      @cookies.for_uri uri
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
    
    def resolve(uri)
      self.class.resolve uri, @referer
    end
    
    # referer should always be a normalized uri
    def self.resolve(uri, referer = nil)
      comps = URI.split uri.to_s
      
      if !comps[0]
        if referer
          comps[0] = referer.scheme
          comps[1] ||= referer.userinfo
          comps[2] ||= referer.host
          comps[3] ||= referer.port if referer.port != referer.default_port
        else
          raise ArgumentError.new "Hostname required" unless comps[2]
          comps[0] = 'http'
        end
      end
      
      uri = comps[0] == 'https' ? URI::HTTPS.new(*comps) : URI::HTTP.new(*comps)
      uri.normalize!
      
      # handle relative URIs (TODO: this is not RFC 1808 compliant)
      if !uri.path.start_with?('/')
        if referer
          uri.path = referer.path[0..referer.path.rindex('/')]+uri.path
        else
          raise ArgumentError.new "Cannot resolve relative URI without referer."
        end
      end
      
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
      req['User-Agent'] = @user_agent
      if cookie = @cookies.request_header(uri)
        req['Cookie'] = cookie
      end
      
      if ref = @referer
        # remove fragment (RFC 2616 14.36) and userinfo (convention)
        if ref.fragment || ref.user || ref.password
          ref = @referer.dup
          ref.fragment = ref.user = ref.password = nil
        end
        req['Referer'] = ref.to_s
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
          with_referer uri do
            loc = resolve res['Location']
            res = request(Net::HTTP::Get, loc, :no_follow => true).http
            uri = loc
          end
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
      prev_ref = @referer
      @referer = ref
      yield if block_given?
      @referer = prev_ref
    end
    
  end
  
end
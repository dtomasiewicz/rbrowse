module RBrowse

  class CookieJar
  
    def initialize()
      @jar = []
    end
    
    # adds a cookie, given a Set-Cookie header and the request URI
    def set_cookie(uri, sc)
      cookie = Cookie.new
      name, sc = sc.split '=', 2
      value, sc = sc.split ';', 2
      cookie.name, cookie.value = CGI::unescape(name), CGI::unescape(value)
      
      opts = {}
      sc && sc.split(';').each do |opt|
        opt, optval = opt.split '=', 2
        opts[opt.downcase] = (optval && CGI::unescape(optval)) || true
      end
      
      # restrict by domain-- not spec-compliant and possibly unsafe (allows 
      #   infinite levels of subdomains)
      if opts['domain'] && opts['domain'] != uri.host
        if opts['domain'].end_with?('.'+uri.host)
          cookie.domain = opts['domain']
        else
          return false
        end
      else
        cookie.domain = uri.host
      end
      
      if opts['path']
        cookie.path = opts['path']
      else
        # the resource path is the "directory" containing the request path
        ri = uri.path.rindex '/'
        cookie.path = ri ? uri.path[0..ri] : '/'
      end
      
      if opts['expires']
        begin
          cookie.expires = DateTime.parse opts['expires']
        rescue ArgumentError; end
      end
      
      cookie.secure = opts.has_key?('secure')
      
      @jar << cookie
      return true
    end
    
    def for_uri(uri)
      # delete expired cookies
      @jar.reject!{|c| c.expires && c.expires <= DateTime.now}
      
      # TODO: this is slow; come up with a better way to index cookies by domain/path
      matched = {}
      @jar.each do |c|
        if !c.secure || uri.scheme == 'https'
          # secure cookies will be ignored unless using https
          unless matched[c.name] && matched[c.name].secure && !c.secure
            # secure cookies won't be overridden by insecure cookies
            if uri.host == c.domain || c.domain.end_with?('.'+uri.host)
              # domain-matched, check path matching
              matched[c.name] = c if uri.path.start_with?(c.path)
            end
          end
        end
      end
      matched
    end
    
    def request_header(request_uri)
      matched = for_uri request_uri
      if matched.length > 0
        return matched.values.map do |c|
          "#{CGI::escape(c.name)}=#{CGI::escape(c.value)}"
        end.join ';'
      else
        return nil
      end
    end
    
  end

end
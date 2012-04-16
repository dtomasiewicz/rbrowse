module RBrowse

  class URL

    attr_accessor :scheme, :userinfo, :host, :port, :registry, :path,
                  :opaque, :query, :fragment
    
    def initialize(url)
      url = URI::split(url) if url.kind_of?(String)
      @scheme, @userinfo, @host, @port, @registry, @path,
        @opaque, @query, @fragment = url
    end
    
    def to_s
      s = ""
      s += scheme+"://" if scheme
      if scheme || host
        s += userinfo+"@" if userinfo
        s += host
        s += ":"+port if port
      end
      s += path if path
      s += "?"+query if query
      s += "#"+fragment if fragment
      #todo: not sure what to do with registry, opaque...
      s
    end
    
    def absolute(base)
      copy = dup
      copy.absolute!(base)
    end
    
    def absolute!(base)
      @scheme, @userinfo, @host, @port = base.scheme, base.userinfo,
        base.host, base.port
    end
    
  end

end
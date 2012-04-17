module RBrowse

  class Page

    attr_reader :browser, :url, :http
    
    def initialize(browser, url, http)
      @browser = browser
      @url = url
      @http = http
    end
    
    def dom
      @dom ||= Nokogiri::HTML(@http.body)
    end
    
    def form(selector = nil)
      case selector
      when nil
        node = dom.at_css 'form'
      when Integer
        node = dom.css('form')[selector]
      when Hash
        s = ''
        selector.each_pair do |k,v|
          s += "[@#{k}=\"#{v}\"]"
        end
        node = dom.at_css s
      else
        node = dom.at_css(selector)
      end
      
      Form.new self, node if node && node.name == 'form'
    end
    
    def to_s
      @http.body
    end
  
  end
  
end
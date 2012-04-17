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
    
    def form(*selectors)
      if selectors.length == 0
        node = dom.at_css 'form'
      elsif selectors.length == 1 && selectors[0].kind_of?(Integer)
        node = dom.css('form')[selectors[0]]
      elsif selectors.length == 1 && selectors[0].kind_of?(Hash)
        s = ''
        selectors[0].each_pair do |k,v|
          s += "[@#{k}=\"#{v}\"]"
        end
        node = dom.at_css s
      else
        node = dom.at_css *selectors
      end
      
      node && node.name == 'form' ? Form.new(self, node) : nil
    end
    
    def success?
      @http.kind_of?(Net::HTTPSuccess)
    end
    
    def to_s
      @http.body
    end
  
  end
  
end
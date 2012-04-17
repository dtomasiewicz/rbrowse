module RBrowse

  class Form
  
    attr_accessor :method, :action
    
    def initialize(page, form_node)
      @page = page
      @method = (form_node['method'] || 'GET').upcase
      @action = form_node['action'] || page.uri
      @fields = {}
      
      form_node.css('input,select,textarea,button').each do |node|
        self[node['name']] = node if node['name']
      end
    end
    
    def field_value(name, include_activated = false)
      return nil if !@fields[name]
      
      @fields[name].each do |f|
        return f if !f.kind_of?(Nokogiri::XML::Node)
        
        case f.name.downcase
        when 'input'
          case (f['type'] || 'text').downcase
          when 'radio', 'checkbox'
            if f.matches? '[@checked="checked"]'
              return f['value'] || '1'
            end
          when 'submit', 'reset', 'image', 'button'
            return include_activated ? f['value'] : nil
          else
            # text, hidden, etc.
            return f['value'] || ''
          end
        when 'select'
          selected = f.at_css 'option[@selected="selected"]'
          return selected ? selected['value'] : nil
        when 'textarea'
          return f.inner_text # TODO: should this be decoded?
        when 'button'
          return include_activated ? f['value'] : nil
        end
      end
      
      return nil
    end
    
    def [](name)
      field_value name, true
    end
    
    def []=(name, value)
      @fields[name] = [] if !@fields[name]
      @fields[name].unshift value
    end
    
    def data(activator = nil)
      data = {}
      @fields.keys.each do |name|
        value = field_value name, activator == name
        data[name] = value if value
      end
      data
    end
    
    def submit(activator = nil, params = {}, &block)
      data = data(activator)
      if @method == 'GET'
        return @page.browser.get(@action, params.merge(:data => data), &block)
      else
        return @page.browser.post(@action, data, params, &block)
      end
    end
    
  end
  
end

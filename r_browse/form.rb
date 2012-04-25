module RBrowse

  class Form
  
    attr_accessor :method, :action
    
    def initialize(page, form_node)
      @page = page
      @method = (form_node['method'] || 'GET').upcase
      @action = form_node['action'] || page.uri
      
      # fields are stored as an array to preserve form ordering
      @fields = []
      
      form_node.css('input,select,textarea,button').each do |node|
        next unless node['name'] && (value = self.class.node_value node)
        
        case node.name
        when 'select', 'textarea'
          rel = true
        when 'input'
          case (node['type'] || 'text').downcase
          when 'submit', 'button', 'reset', 'image'
            rel = false
          when 'checkbox', 'radio'
            rel = node.matches?('[@checked="checked"]')
          else
            rel = true
          end
        else
          rel = false
        end
        
        @fields << Field.new(node['name'], value, rel)
      end
    end
    
    def extend(field, value)
      @fields << Field.new(field, value.to_s, true) unless value == nil
    end
    
    def set(field, value)
      @fields.delete_if {|f| f.name == field}
      extend field, value
    end
    alias_method :[]=, :set
    
    # if only_relevant is true, submission inputs and unchecked checkboxes/radio
    # buttons will be ignored
    def get_all(field, only_relevant = false)
      @fields.select do |f|
        f.name == field && (!only_relevant || f.relevant)
      end.map &:value
    end
    
    # will return a string, or nil iff node is a SELECT with no OPTION selected
    def self.node_value(node)
      case node.name
      when 'input'
        case (node['type'] || 'text').downcase
        when 'checkbox', 'radio'
          node['value'] || 'on'
        else
          node['value']
        end
      when 'button'
        node['value']
      when 'textarea'
        node.inner_text
      when 'select'
        sel = node.at_css 'option[@selected="selected"]'
        sel ? (sel['value'] || '') : nil
      else
        nil
      end
    end
    
    def get(field, only_relevant = false)
      get_all(field, only_relevant).last
    end
    alias_method :[], :get
    
    def submit(activator = nil, params = {}, &block)
      data = @fields.select{|f| f.relevant || f.name == activator}.map do |f|
        "#{CGI::escape f.name}=#{CGI::escape f.value}"
      end.join '&'
      
      if @method == 'GET'
        return @page.browser.get(@action, params.merge(:data => data), &block)
      else
        return @page.browser.post(@action, data, params, &block)
      end
    end
    
  end
  
  class Field
    attr_reader :name, :value, :relevant
    def initialize(name, value, relevant)
      @name = name
      @value = value
      @relevant = relevant
    end
  end
  
end

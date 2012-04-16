module RBrowse

  class Page

    attr_reader :http
    
    def initialize(http_response)
      @http = http_response
    end
    
    def dom
      @dom ||= Nokogiri::HTML(@http.body)
    end
    
    def form_at(selector)
      node = dom.at_css selector
      node ? RBrowse.collect_form_data(node) : nil
    end
    
    def to_s
      @http.body
    end
  
  end

  # note: values from BUTTON and input[type=button|submit|image|reset] are 
  #   traditionally only sent when clicked to provoke form submission, any 
  #   many websites rely on browsers behaving this way. because of this,
  #   collect_form_data does ignores any such values. if you want the website
  #   to think you selected a particular submission component, you'll have to
  #   add in that element's value manually.
  def self.collect_form_data(form_node)
    data = {}
    form_node.css('input,select,textarea').each do |el|
      if el['name']
        case el.name.downcase
        when 'input'
          case el['type'].downcase
          when 'radio', 'checkbox'
            if el.matches?('[@checked="checked"]')
              data[el['name']] = el['value'] || 1
            end
          when 'submit', 'reset', 'image', 'button'
            # ignore
          else # assume a text box at this point
            data[el['name']] = el['value']
          end
        when 'select'
          selected = el.at_css 'option[@selected="selected"]'
          data[el['name']] = selected['value'] if selected
        when 'textarea'
          data[el['name']] = el.inner_text # TODO: check if this should be decoded
        end
      end
    end
    data
  end
  
end
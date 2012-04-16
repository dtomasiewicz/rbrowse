#!/usr/bin/env ruby
# Example script to perform a DuckDuckGo search

require_relative 'rbrowser'

b = Browser.new :chrome
b.get 'http://duckduckgo.com' do |res|
  if data = res.form_data('#search_form_homepage')
    puts b.get_with_data 'http://duckduckgo.com', data.merge('q' => 'my query')
  end
end

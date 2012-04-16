#!/usr/bin/env ruby
# Example script to perform a DuckDuckGo search

require_relative 'rbrowser'

b = Browser.new :chrome
b.get 'http://duckduckgo.com' do
  puts b.get_with_data '/', :q => 'my query'
end

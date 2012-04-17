# A scriptable web browser for use with crawlers/scrapers/automators.
#
# @author Daniel Tomasiewicz
#

require 'net/http'
require 'cgi'
require 'uri'
require 'openssl'
require 'date'
require 'nokogiri'

module RBrowse

  def self.new(*args)
    Browser.new *args
  end
  
end

require 'r_browse/browser'
require 'r_browse/url'
require 'r_browse/cookie_jar'
require 'r_browse/cookie'
require 'r_browse/page'
require 'r_browse/form'

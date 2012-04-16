#!/usr/bin/env ruby
# Example script to login to a website

require_relative 'rbrowser'

URLS = {
  # fill in these values correctly with full URLs
  login_form: 'url_to_login_form',
  login_proc: 'login_form_action'
}

# will need tweaking depending on how the login form is structured
FORM_SELECTOR = '#login_form'
USERNAME = 'my_username'
PASSWORD = 'my_password'

b = Browser.new :chrome
b.get URLS[:login_form] do |res|
  if data = res.form_data(FORM_SELECTOR)
    b.post URLS[:login_proc], data.merge('username' => USERNAME, 'password' => PASSWORD)
    # if all went well, subsequent requests will be made as though you are logged in
  end
end

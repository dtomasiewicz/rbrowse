# Hi there.

If you've somehow stumbled across this repo and it's piqued your interest, you 
should go check out [`Mechanize`](https://github.com/tenderlove/mechanize). It's 
stable, tested, compliant with most (all?) relevant RFCs, and has a superset of 
RBrowse's features.

This library was originally refactored out of a scraper I was wrote before I
was aware of Mechanize's existence. At the time of this writing, I am still
actively developing RBrowse because it's interesting to me, but I can say with 
near-certainty that it will never have sufficient test coverage, standards 
compliance, or documentation for a public release.

Without further ado, here's some very brief documentation...


## Diving In

```ruby
require 'r_browse'
browser = RBrowse.new
puts browser.get 'http://duckduckgo.com'
```


## Cookies

RBrowse will automatically store and send cookies provided by web servers. The
manner in which cookies are handled is not guaranteed to be 100% compliant with
the HTTP specification, and so the domain/path restriction may not be entirely 
secure. For this reason, you alone are responsible for ensuring that any websites 
queried by RBrowse are not sending malicious responses.


## Referers

When a request sent to a `Browser` instance is accompanied by a block, the block
will be executed after a response is received (and after redirects unless
`:no_follow` is specified). Any subsequent requests made from within this block
will have a _Referer_ header attached with the value of the original request's URI.
This allows easy simulation of link clicks and form submissions.

Additionally, when performing requests within a block, you may supply only the
request _path_. When doing so, the domain of the referring request will be assumed.

```ruby
browser = RBrowse.new
browser.get 'http://duckduckgo.com' do
  # send another request to duckduckgo.com
  puts browser.get '/settings.html'
end
```

From the perspective of the duckduckgo.com web server, the above is equivalent 
to a user browsing to the homepage and clicking on the Settings link.


## Parsing

RBrowse exposes a Nokogiri Document object to simplify parsing of responses.

```ruby
RBrowse.new.get 'http//duckduckgo.com' do |page|
  # find all links on the returned page
  links = page.dom.css 'a[@href]'
end
```

See the [Nokogiri documentation](http://nokogiri.org/) for more information.


## Forms

### Selection

The first step to emulating a form submission is to find the FORM node on the
page. This can be accomplished with `Page.form`:

```ruby
RBrowse.new.get 'http//duckduckgo.com' do |page|
  form = page.form 'name' => 'x'
end
```

The arguments passed to `Page.form` may be either:

 - an `Integer` N in which case the Nth form on the page is used (zero-based).
 - a `Hash` of attributes and values that will be converted to a form selector
   and passed to Nokogiri's [`Node.at_css`](http://nokogiri.org/Nokogiri/XML/Node.html#method-i-at_css)
   method. For example, `{'id' => 'bob'}` becomes the String selector `form[@id="bob"]`.
 - one or more CSS _rules_ that will return a FORM node when passed directly to 
   `Node.at_css`. See Nokogiri's [documentation](http://nokogiri.org/Nokogiri/XML/Node.html#method-i-css)
   for details about supported rule formats.


### Modification and Submission

Once you have obtained a `Form` object, it can be modified and submitted.

```ruby
RBrowse.new.get 'http//duckduckgo.com' do |page|
  if form = page.form('name' => 'x')
    form['q'] = 'my search query'
    results = form.submit
    puts results
  end
end
```

Modified and newly-created fields will be sent to the server as long as they are not
assigned a value of `nil`.

Unmodified fields will be sent with their default values in a manner similar 
to that of a regular web browser. That is to say:

 - button values will not be sent unless their name is passed as the first
   argument to `Form.submit`
 - checkboxes will not be sent at all unless they are checked
 - if multiple fields have the same `name`, only the last field with that name
   will be considered, unless the field is a checkbox or radiobutton, in which
   case the preceding field will be considered if the checkbox/radio button is
   not _checked_.


## HTTPS

HTTPS is handled transparently by RBrowse. If you need to configure specific SSL
behaviour to connect to a particular website (for example, if its certificate 
authority is not a trusted CA on your machine), you can do so through the underlying 
[`Net::HTTP`](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/net/http/rdoc/Net/HTTP.html)
connection object.

```ruby
b = RBrowse.new
# WARNING: the following will open you up to man-in-the-middle attacks
b.connection('https://google.ca').ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE
```


## File Uploads and Downloads

Binary data transfer is not currently supported by RBrowse, but is next on the 
TODO list. For now, downloads can be accomplished by working with the 
[`Net::HTTPResponse`](http://ruby-doc.org/stdlib-1.9.3/libdoc/net/http/rdoc/Net/HTTPResponse.html) 
object directly. This object is exposed by an `http` call to a `Page` instance:

```ruby
RBrowse.new.get 'http://somewebsite<.com/some_binary_file.jpg' do |page|
  open 'some_binary_file.jpg', 'wb' do |file|
    file.write page.http.body
  end
end
```


## Examples

### Login

```ruby
RBrowse.new.get 'https://example.com/login' do |page|
  if form = page.form('id' => 'login_form')
    form['user'] = 'bob'
    form['password'] = 12345
    
    if form.submit.success?
      # assuming a 200 OK response implies valid credentials
      puts "Login successful."
    else
      puts "Login failed!"
    end
  else
    raise "Failed to find login form."
  end
end
```

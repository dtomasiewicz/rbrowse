## Diving In

```ruby
b = RBrowse.new
puts b.get 'http://duckduckgo.com'
```


## Cookies

RBrowse will automatically store and send cookies provided by web servers. The
manner in which cookies are handled is not guaranteed to be 100% compliant with
the HTTP specification, and so the domain/path restriction may not be entirely 
secure. For this reason, you alone are responsible for ensuring that any websites 
queried by RBrowse are not sending malicious responses.


## Referers

When a request sent to a Browser instance is accompanied by a block, the block
will be executed after a response is received (and after redirects unless
`:no_follow` is specified). Any subsequent requests made from within this block
will have a Referer header attached with the value of the original request's URL.
This allows simulation of link clicks and form submissions.

Additionally, when performing requests within a block, you may supply only the
request _path_. When doing so, the domain of the referring request will be assumed.

```ruby
b = RBrowse.new
b.get 'http://duckduckgo.com' do |page|
  # sends a GET request for '/about' to duckduckgo.com
  puts b.get_with_data '/about', 'q' => 'search term'
end
```

From the perspective of the duckduckgo.com web server, the above is equivalent 
to a user browsing to the homepage, entering a query in the text box, and clicking 
the search button (or pressing enter).


## Parsing

RBrowse exposes a Nokogiri Document object to simplify parsing of responses.

```ruby
b = RBrowse.new
b.get 'http//duckduckgo.com' do |page|
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
b = RBrowse.new
b.get 'http//duckduckgo.com' do |page|
  form = page.form('name' => 'x')
end
```

The arguments passed to `Page.form` may be either:

 - An `Integer` _n_: in which case the _n_th form on the page is used (zero-
   based)
 - A Hash of attributes and values that will be converted to a form selector
   and passed to Nokogiri's [`Node.at_css`](http://nokogiri.org/Nokogiri/XML/Node.html#method-i-at_css)
   method (e.g. `{'id' => 'bob'}` becomes `"form[@id="bob"]"`
 - One or more CSS _rules_ that will return a FORM node when passed directly to 
   `Node.at_css`. See Nokogiri's [documentation](http://nokogiri.org/Nokogiri/XML/Node.html#method-i-css)
   for information on what constitutes a valid CSS rule.


### Modification and Submission

Once you have obtained a `Form`, it can be modified or submitted immediately.

```ruby
b = RBrowse.new
b.get 'http//duckduckgo.com' do |page|
  if form = page.form('name' => 'x')
    form['q'] = 'my search query'
    results = form.submit
    puts results
  end
end
```

Any fields whose values are not modified will be given default values in a manner
similar to that used by a regular web browser. That is to say:

 - button values will not be sent unless their name is passed as the first
   argument to `Form.submit`
 - checkboxes will not be sent at all unless they are checked
 - if multiple fields have the same `name`, only the last field with that name
   will be considered, unless:
   - the field is a checkbox, in which case the second-last field will be 
     considered if it is not checked
   - the field is a radio button, in which case the last (or, in most cases, only)
     _checked_ field will be considered

Any field that is modified _will_ be passed unless it is given a value of `nil`.

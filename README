Cookies
========

rbrowser will automatically store and send cookies provided by web servers. The
manner in which cookies are handled is not guaranteed to be 100% compliant with
the HTTP specification, and so the domain/path restriction may not be entirely 
secure. For this reason, you alone are responsible for ensuring that any websites 
queried by rbrowser are not sending malicious responses.

Request Blocks
========

When a request sent to a Browser instance is accompanied by a block, the block
will be executed after a response is received (and after redirects unless
:no_follow is specified).

    b = Browser.new
    b.get 'http://duckduckgo.com' do |res|
      puts res
    end

Note that the above is functionally equivalent to:

    b = Browser.new
    puts b.get 'http://duckduckgo.com'

So why use a block? Because any subsequent requests made from within the block 
will have a Referer header appended to them automatically. This allows you to
simulate clicking a link or submitting a form in a regular browser.

Additionally, when performing requests within a block, you may supply only the
request _path_. If you do so, the domain of the referring request will be assumed.
Example:

    b = Browser.new
    b.get 'http://duckduckgo.com' do |res|
      puts b.get_with_data '/', :q => 'search term'
    end

From the perspective of the duckduckgo.com web server, the above is equivalent 
to a user browsing to the homepage, entering a query in the text box, and clicking 
the search button (or pressing enter).

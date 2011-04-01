# static serving example

require 'http_router'

base = File.expand_path(File.dirname(__FILE__))

run HttpRouter.new {
  add('/favicon.ico').static("#{base}/favicon.ico")  # from a single file
  add('/images').static("#{base}/images")            # or from a directory
}

# $ curl -I http://localhost:3000/favicon.ico
# => HTTP/1.1 200 OK
# => Last-Modified: Sat, 26 Mar 2011 18:04:26 GMT
# => Content-Type: image/vnd.microsoft.icon
# => Content-Length: 1150
# => Connection: keep-alive
# => Server: thin 1.2.8 codename Black Keys
# 
# $ curl -I http://localhost:3000/images/cat1.jpg
# => HTTP/1.1 200 OK
# => Last-Modified: Sat, 26 Mar 2011 18:04:26 GMT
# => Content-Type: image/jpeg
# => Content-Length: 29817
# => Connection: keep-alive
# => Server: thin 1.2.8 codename Black Keys

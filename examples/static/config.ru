# static serving example

require 'http_router'

base = File.expand_path(File.dirname(__FILE__))

run HttpRouter.new {
  get('/favicon.ico').static("#{base}/favicon.ico")  # from a single file
  get('/images').static("#{base}/images")            # or from a directory
}

# crapbook-pro:~ joshua$ curl -I http://localhost:3000/favicon.ico
# HTTP/1.1 200 OK
# Last-Modified: Fri, 11 Jun 2010 21:02:22 GMT
# Content-Type: image/vnd.microsoft.icon
# Content-Length: 1150
# Connection: keep-alive
# Server: thin 1.2.7 codename No Hup
# 
# crapbook-pro:~ joshua$ curl -I http://localhost:3000/images/cat1.jpg
# HTTP/1.1 200 OK
# Last-Modified: Fri, 11 Jun 2010 21:54:16 GMT
# Content-Type: image/jpeg
# Content-Length: 29817
# Connection: keep-alive
# Server: thin 1.2.7 codename No Hup

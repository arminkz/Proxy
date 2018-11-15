#!/usr/bin/ruby

require "socket"
require "openssl"
require "thread"

listeningPort = 4443

server = TCPServer.new(listeningPort)
sslContext = OpenSSL::SSL::SSLContext.new
sslContext.cert = OpenSSL::X509::Certificate.new(File.open("certificate.pem"))
sslContext.key = OpenSSL::PKey::RSA.new(File.open("key.pem"))
sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)

puts "Listening on port #{listeningPort}"

loop do
  connection = sslServer.accept
  puts "New Client Connected"
  Thread.new {
    begin
      request_line = connection.gets
      verb    = request_line[/^\w+/]
      url     = request_line[/^\w+\s+(\S+)/, 1]
      version = request_line[/HTTP\/(1\.\d)\s*$/, 1]

      response = "Server got this request : \r\n" + request_line 

      header = "HTTP/1.1 200 OK\r\n" +
                "Content-Type: text/plain\r\n" +
                "Content-Length: #{response.bytesize}\r\n" +
                "Connection: close\r\n"

      connection.puts header + "\r\n" + response
    rescue
      $stderr.puts $!
    end
  }
end
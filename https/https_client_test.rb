#!/usr/bin/ruby

require "socket"
require "thread"
require "openssl"

host = ARGV[0]
port = Integer(ARGV[1])

socket = TCPSocket.new(host, port)
expectedCert = OpenSSL::X509::Certificate.new(File.open("certificate.pem"))
ssl = OpenSSL::SSL::SSLSocket.new(socket)
ssl.sync_close = true
ssl.connect
if ssl.peer_cert.to_s != expectedCert.to_s
  stderrr.puts "Unexpected certificate"
  exit(1)
end

Thread.new {
  begin
    while lineIn = ssl.gets
      lineIn = lineIn.chomp
      $stdout.puts lineIn
    end
  rescue
    $stderr.puts "Error in input loop: " + $!
  end
}

while (lineOut = $stdin.gets)
  lineOut = lineOut.chomp
  ssl.puts lineOut
end

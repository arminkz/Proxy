require 'socket'
require 'uri'
require 'openssl'
require "cgi"

class HTTPSProxy

  def start(port)
    begin

      puts "Starting HTTPS proxy server on port #{port} ..."

	  # Start our server to handle connections (will raise things on errors)
	  @socket = TCPServer.new(port)

	  # Handle every request in another thread
	  loop do
	    s = @socket.accept
	    #sock_domain, remote_port, remote_hostname, remote_ip = s.peeraddr
	    #puts "Client Connected : #{remote_hostname} ( #{remote_ip} : #{remote_port} )"
	    Thread.new(s, &method(:handle_request_tcp))
	  end

      # CTRL-C
    rescue Interrupt
      puts 'Got Interrupt..'
        # Ensure that we release the socket on errors
    ensure
      if @socket
        @socket.close
        puts 'Socked closed..'
      end
      puts 'Quitting.'
    end
  end

  def handle_request_tcp(client)
    request_line = client.readline

    verb    = request_line[/^\w+/]
    url     = request_line[/^\w+\s+(\S+)/, 1]
    version = request_line[/HTTP\/(1\.\d)\s*$/, 1]
    uri     = URI::parse url

    # Show what got requested
    puts((" %4s "%verb) + url)

    #Setup SSL Socket
    socket = TCPSocket.new('localhost', 4443) #change localhost to uri.host for actual https connection
    expectedCert = OpenSSL::X509::Certificate.new(File.open("certificate.pem"))
    ssl = OpenSSL::SSL::SSLSocket.new(socket)
    ssl.sync_close = true
    ssl.connect
    if ssl.peer_cert.to_s != expectedCert.to_s
      stderrr.puts "Unexpected certificate"
      exit(1)
    end

    all_queries = nil
    if(verb != "POST")
      puts "Converting #{verb} to POST"
      if(uri.query != nil)
        all_queries = CGI::parse(uri.query)
      end
      verb = "POST"
    end

    ssl.puts("#{verb} #{uri.path} HTTP/#{version}\r\n")

    #Read additional client request lines
    content_len = 0
    client_request_lines = ""
    loop do
      line = client.readline
      if line =~ /^Content-Length:\s+(\d+)\s*$/
        content_len = $1.to_i
      end
      # Strip proxy headers
      if line =~ /^proxy/i
        next
      elsif line.strip.empty?
        client_request_lines += "Connection: close\r\n\r\n"
        if content_len >= 0
          client_request_lines += client.read(content_len)
        end
        break
      else
        client_request_lines += line
      end
    end
    #tell server client's additional lines
    #puts "Sending via SSL"
    ssl.puts(client_request_lines)

    if(all_queries != nil)
      puts all_queries
      all_queries.each do |key, value|
        ssl.puts(key + "=" + value[0])
      end
    end

    while line = ssl.gets
  		client.write(line)
	  end

    # Close the sockets
    client.close
    ssl.close
  end
end


# Get parameters and start the proxy
if ARGV.empty?
  puts 'Usage: https_proxy.rb [-port portnumber]'
  exit 1
else
  port = 8000
  lastp = ""
  while !ARGV.empty?
    lastp = ARGV.shift
    case lastp
    when "-port"
      port = ARGV.shift.to_i
    end
  end

  HTTPSProxy.new.start(port)
end




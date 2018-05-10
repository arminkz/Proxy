require 'socket'
require 'uri'

class Proxy

  def start(port)
    begin

      puts "Starting HTTP Proxy Server..."
      # Start our server to handle connections (will raise things on errors)
      @socket = TCPServer.new(port)
      puts "OK"

      # Handle every request in another thread
      loop do
        s = @socket.accept
        #sock_domain, remote_port, remote_hostname, remote_ip = s.peeraddr
        #puts "Client Connected : #{remote_hostname} ( #{remote_ip} : #{remote_port} )"
        Thread.new(s, &method(:handle_request))
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

  def handle_request(client)

    request_line = client.readline

    verb    = request_line[/^\w+/]
    url     = request_line[/^\w+\s+(\S+)/, 1]
    version = request_line[/HTTP\/(1\.\d)\s*$/, 1]
    uri     = URI::parse url

    # Show what got requested
    puts((" %4s "%verb) + url)

    server = TCPSocket.new(uri.host, (uri.port.nil? ? 80 : uri.port))
    server.write("#{verb} #{uri.path}?#{uri.query} HTTP/#{version}\r\n")

    content_len = 0

    loop do
      line = client.readline

      if line =~ /^Content-Length:\s+(\d+)\s*$/
        content_len = $1.to_i
      end

      # Strip proxy headers
      if line =~ /^proxy/i
        next
      elsif line.strip.empty?
        server.write("Connection: close\r\n\r\n")

        if content_len >= 0
          server.write(client.read(content_len))
        end

        break
      else
        server.write(line)
      end
    end

    buff = ""
    loop do
      server.read(4048, buff)
      client.write(buff)
      break if buff.size < 4048
    end

    # Close the sockets
    client.close
    server.close
  end

end


# Get parameters and start the server
if ARGV.empty?
  port = 8000
elsif ARGV.size == 1
  port = ARGV[0].to_i
else
  puts 'Usage: proxy.rb [port]'
  exit 1
end

Proxy.new.start(port)
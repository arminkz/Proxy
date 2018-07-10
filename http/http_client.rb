require 'socket'
require 'uri'

class HTTPClient
	attr_reader :proxy_port, :proxy_ip

	def initialize(proxy_port , proxy_ip)
    	@proxy_port, @proxy_ip = proxy_port, proxy_ip
  	end

	def get(hostname)
		puts "Connecting to HTTP proxy ..."

		proxy_sock = TCPSocket.open proxy_ip, proxy_port
		proxy_sock.puts "GET #{hostname} HTTP/1.1\r\n"
		proxy_sock.puts "\r\n"


		header_finished = false
		html = ""
		# Read Response
		response_code = proxy_sock.gets.split(" ")[1]
		puts "Server responded with code #{response_code}"
		while line = proxy_sock.gets
			header_finished = true if line == "\r\n"
			html += line if header_finished
		end

		# Create Temporary Html file
		begin
			file = File.open("tmp.html","w")
			file.write(html)
		rescue IOError => e
  			#some error occur, dir not writable etc.
  			puts "Error Creating Temp File !"
		ensure
  			file.close unless file.nil?
		end

		system("open tmp.html")
	end

end

# Get parameters and start the server
if ARGV.empty?
	puts 'Usage: http_client.rb [-port portnumber] [-proxy ipaddress] hostname'
	exit 1
else
	port = 8000
	proxy = "localhost"
	lastp = ""
	while !ARGV.empty?
		lastp = ARGV.shift
		case lastp
		when "-port"
			port = ARGV.shift.to_i
		when "-proxy"
			proxy = ARGV.shift
		end
	end

	client = HTTPClient.new port,proxy
	client.get URI::parse lastp
end


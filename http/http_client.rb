require 'socket'
require 'uri'

class HTTPClient
	attr_reader :proxy_port, :proxy_ip

	def initialize(proxy_port: 8000 , proxy_ip: "localhost")
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

		#puts html

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
if !ARGV.empty?
	p ARGV
else
	puts 'Usage: http_client.rb hostname'
	exit 1
end

client = HTTPClient.new
client.get URI::parse ARGV[0]
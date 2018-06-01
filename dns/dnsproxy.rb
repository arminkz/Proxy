require 'socket'
require 'bindata'

class DnsHeader < BinData::Record
	endian :big
	uint16 :transaction_id
	bit1 :flag_QR
	bit4 :opcode
	bit1 :flag_AA
	bit1 :flag_TC
	bit1 :flag_RD
	bit1 :flag_RA
	bit3 :flag_Z
	bit4 :rcode
	uint16 :q_count
	uint16 :a_count
	uint16 :ns_count
	uint16 :ar_count
end

class NameElement < BinData::Record
	endian :big
	bit2 :flag
	bit6 :nelen
	string :name, read_length: :nelen
	#TODO : must support ptr types here
end

class NameSeq < BinData::Record
	array :names, type: :name_element, read_until: lambda { element.flag != 0x0 or element.name == '' }
end

class DnsRecord < BinData::Record
	endian :big
	name_seq :rnameseq
	uint16 :rtype
	uint16 :rclass
end

class Question < DnsRecord; end

class ResourceRecord < DnsRecord
	uint32 :ttl
	uint16 :rdlength
	string :rdata, read_length: :rdlength
end

class DnsPacket < BinData::Record
	dns_header :header
    array :questions,    type: :question,        initial_length: lambda { header.q_count }
    array :answers,      type: :resource_record, initial_length: lambda { header.a_count }
    array :authorities,  type: :resource_record, initial_length: lambda { header.ns_count }
    array :addl_records, type: :resource_record, initial_length: lambda { header.ar_count }
end

class DNSServer
  attr_reader :port, :ttl
  attr_accessor :records

  def initialize(port: 5300 , ttl: 60 , records: {})
    @port, @records, @ttl = port, records, ttl
  end

  def run
    puts "Starting DNS Proxy Server on port #{@port} ..."
    @socket = UDPSocket.new
    @socket.bind("localhost",port)

    #Try/Catch
    begin

      Socket.udp_server_loop(@port) do |data, src|
      	r = DnsPacket.new
        r.read(data)
        puts r

        #Build Up Response
        # r.flag_QR = 1
        # r.opcode = 0x00
        # r.flag_AA = 0
        # r.flag_RD = 0 #no recursion yet
        # r.flag_RA = 0 #no recursion yet
        # r.rcode = 0
        
        resp = r.to_binary_s
        src.reply resp
        
        #src.reply 
        #src.reply r.get_response(@records[r.domain])
      end

    rescue Interrupt
      puts "Got Interrupt !"
    ensure
      if @socket
        @socket.close
        puts "Socket Closed !"
      end
      puts "Quiting.."
    end

  end

end

DNSServer.new(ttl: 120).run
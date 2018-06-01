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

  def initialize(port: 5300 , ttl: 60)
    @port, @ttl = port, ttl

    #DNS Database
    @records = {
      "4kp.ir." => "185.55.277.57",
      "google.com." => "172.217.18.174"
    }
  end

  def get_query_url(rcvd)
    url = ""
    for n in rcvd.questions[0].rnameseq.names
      if (n.nelen > 0)
        url += n.name + '.'
      end
    end
    return url
  end

  def create_response(rcvd,ip)
    resp = DnsPacket.new
    resp.header = DnsHeader.new
    resp.header.transaction_id = rcvd.header.transaction_id
    resp.header.flag_QR = 1
    resp.header.opcode = 0
    resp.header.flag_AA = 0
    resp.header.flag_RD = 0
    resp.header.flag_RA = 0
    resp.header.rcode = 0
    resp.header.q_count = 1
    resp.header.a_count = 1
    resp.header.ns_count = 0
    resp.header.ar_count = 0
    resp.questions = rcvd.questions
    resp.answers = []
    #Append Answer RR
    rr = ResourceRecord.new
    rr.rnameseq = rcvd.questions[0].rnameseq
    rr.rtype = rcvd.questions[0].rtype
    rr.rclass = rcvd.questions[0].rclass
    rr.ttl = @ttl
    rr.rdlength = 4 #IPv4 is 4 bytes #TODO: for other types of query (ex. IPv6 AAA) this must change!
    rr.rdata = ip.split('.').collect(&:to_i).pack("C*")
    resp.answers.push(rr)
    return resp
  end

  def create_empty_response(rcvd)
    resp = DnsPacket.new
    resp.header = DnsHeader.new
    resp.header.transaction_id = rcvd.header.transaction_id
    resp.header.flag_QR = 1
    resp.header.opcode = 0
    resp.header.flag_AA = 0
    resp.header.flag_RD = 0
    resp.header.flag_RA = 0
    resp.header.rcode = 0
    resp.header.q_count = 1
    resp.header.a_count = 0
    resp.header.ns_count = 0
    resp.header.ar_count = 0
    resp.questions = rcvd.questions
    return resp
  end

  def run
    puts "Starting DNS Server on port #{@port} ..."
    @socket = UDPSocket.new
    @socket.bind("localhost",port)

    #Try/Catch
    begin

      Socket.udp_server_loop(@port) do |data, src|
      	r = DnsPacket.new
        r.read(data)
        #puts r

        url = get_query_url(r)
        puts url

        #Build Up Response
        if(@records.has_key?(url))
          resp = create_response(r,@records[url])
        else
          resp = create_empty_response(r)
        end

        src.reply resp.to_binary_s
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
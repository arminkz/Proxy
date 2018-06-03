require 'socket'
require 'bindata'
require 'yaml'

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

class PascalString < BinData::Record
  bit6 :pslen
  string :str, read_length: :pslen
end

class NameElement < BinData::Record
  endian :big
  bit2 :flag
  choice :name, selection: :flag do
    pascal_string 0x0
    bit14 0x3  #just eat ptr bytes for now ! (yummy num!num!)
  end
  #TODO : must support ptr types here
end

class NameSeq < BinData::Record
  array :names, type: :name_element, read_until: lambda { element.flag != 0x0 or element.name.str == '' }
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


class DNSProxy
  attr_reader :port, :ttl, :dns

  def initialize(port: 5300 , ttl: 60 , dns: "8.8.8.8")
    @port, @ttl , @dns = port, ttl, dns

    #DNS Database
    # @records = {
    #   "4kp.ir." => "185.55.277.57",
    #   "google.com." => "172.217.18.174"
    # }

  end

  def get_query_url(rcvd)
    url = ""
    for n in rcvd.questions[0].rnameseq.names
      if (n.name.pslen > 0)
        url += n.name.str + '.'
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

    #Load DNS DB
    con_yel = "\033[33m"
    con_end = "\033[0m"
    con_grn = "\033[32m"
    con_red = "\033[31m"

    puts "#{con_yel}Rebuilding DNS Cache ...#{con_end}"
    @records = YAML.load_file('records.yml')

    puts "#{con_grn}Starting DNS Proxy Server on port #{@port} ...#{con_end}"
    #@socket = UDPSocket.new
    #@socket.bind("localhost",port)

    #Try/Catch
    begin

      Socket.udp_server_loop(@port) do |data, src|
      	r = DnsPacket.new
        r.read(data)
        #puts r

        url = get_query_url(r)
        print "Got DNS Request : #{con_yel}#{url}#{con_end} " 

        #Build Up Response
        if(@records.has_key?(url))
          #i have it in cache
          resp = create_response(r,@records[url])
          src.reply resp.to_binary_s
          puts "Cache"
        else
          #i dont have it in cache ask dns
          dnssock = UDPSocket.new
          dnssock.send data, 0, @dns, 53
          resp = dnssock.recv 4096

          src.reply resp
          #store in cache for next use
          dnsresp = DnsPacket.new
          dnsresp.read(resp)
          puts "#{con_red} DUMP #{con_end}"
          puts dnsresp
          #resp = create_empty_response(r)
          puts "DNS"
        end

        
      end

    rescue Interrupt
      puts ""
      puts "#{con_red}Got Interrupt !#{con_end}"

      puts "#{con_yel}Saving Cache ...#{con_end}"
      File.write("records.yml",@records.to_yaml)

    ensure
      if @socket
        @socket.close
        puts "Socket Closed !"
      end
      puts "Quiting.."
    end

  end

end

DNSProxy.new(ttl: 120).run
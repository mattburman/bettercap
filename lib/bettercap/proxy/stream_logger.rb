# encoding: UTF-8
=begin

BETTERCAP

Author : Simone 'evilsocket' Margaritelli
Email  : evilsocket@gmail.com
Blog   : http://www.evilsocket.net/

This project is released under the GPL 3 license.

=end
require 'bettercap/logger'

module BetterCap
# Raw or http streams pretty logging.
class StreamLogger
  @@MAX_REQ_SIZE = 50

  @@CODE_COLORS  = {
    '2' => :green,
    '3' => :light_black,
    '4' => :yellow,
    '5' => :red
  }

  @@services = nil

  # Search for the +addr+ IP address inside the list of collected targets and return
  # its compact string representation ( @see BetterCap::Target#to_s_compact ).
  def self.addr2s( addr, alt = nil )
    ctx = Context.get

    return 'local' if addr == ctx.ifconfig[:ip_saddr]

    target = ctx.find_target addr, nil
    return target.to_s_compact unless target.nil?

    if addr == '0.0.0.0' and !alt.nil?
      return alt
    elsif addr == '255.255.255.255'
      return '*'
    end

    addr
  end

  # Given +proto+ and +port+ return the network service name if possible.
  def self.service( proto, port )
    if @@services.nil?
      Logger.info 'Preloading network services ...'

      @@services = { :tcp => {}, :udp => {} }
      filename = File.dirname(__FILE__) + '/../network/services'
      File.open( filename ).each do |line|
        if line =~ /([^\s]+)\s+(\d+)\/([a-z]+).*/i
          @@services[$3.to_sym][$2.to_i] = $1
        end
      end
    end

    if @@services.has_key?(proto) and @@services[proto].has_key?(port)
      @@services[proto][port]
    else
      port
    end
  end

  # Log a raw packet ( +pkt+ ) data +payload+ using the specified +label+.
  def self.log_raw( pkt, label, payload )
    nl    = label.include?("\n") ? "\n" : " "
    label = label.strip
    from  = self.addr2s( pkt.ip_saddr, pkt.eth2s(:src) )
    to    = self.addr2s( pkt.ip_daddr, pkt.eth2s(:dst) )

    if pkt.respond_to?('tcp_dst')
      to += ':' + self.service( :tcp, pkt.tcp_dst ).to_s
    elsif pkt.respond_to?('udp_dst')
      to += ':' + self.service( :udp, pkt.udp_dst ).to_s
    end

    Logger.raw( "[#{from} > #{to}] [#{label.green}]#{nl}#{payload.strip}" )
  end

  # Log a HTTP ( HTTPS if +is_https+ is true ) stream performed by the +client+
  # with the +request+ and +response+ most important informations.
  def self.log_http( request, response )
    is_https   = request.port == 443
    request_s  = "#{is_https ? 'https' : 'http'}://#{request.host}#{request.url}"
    response_s = "( #{response.content_type} )"
    request_s  = request_s.slice(0..@@MAX_REQ_SIZE) + '...' unless request_s.length <= @@MAX_REQ_SIZE
    code       = response.code[0]

    if @@CODE_COLORS.has_key? code
      response_s += " [#{response.code}]".send( @@CODE_COLORS[ code ] )
    else
      response_s += " [#{response.code}]"
    end

    Logger.raw "[#{self.addr2s(request.client)}] #{request.verb.light_blue} #{request_s} #{response_s}"
  end
end
end

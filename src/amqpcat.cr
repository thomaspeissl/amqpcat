require "amqp-client"
require "compress/deflate"
require "compress/gzip"
require "./version"

class AMQPCat
  def initialize(uri)
    u = URI.parse(uri)
    p = u.query_params
    p["name"] = "AMQPCat #{VERSION}"
    u.query = p.to_s
    @client = AMQP::Client.new(u)
  end

  def produce(exchange : String, routing_key : String, exchange_type : String, publish_confirm = false)
    STDIN.blocking = false
    loop do
      connection = @client.connect
      channel = connection.channel
      open_channel_declare_exchange(connection, exchange, exchange_type)
      props = AMQP::Client::Properties.new(delivery_mode: 2_u8)
      while line = STDIN.gets
        if publish_confirm
          channel.basic_publish_confirm line, exchange, routing_key, props: props
        else
          channel.basic_publish line, exchange, routing_key, props: props
        end
      end
      connection.close
      break
    rescue ex
      STDERR.puts ex.message
      sleep 0.1
    end
  end

  def consume(exchange_name : String?, routing_key : String?, queue_name : String?, format : String, consume_to_files : Bool)
    exchange_name ||= ""
    routing_key ||= ""
    queue_name ||= ""
    loop do
      connection = @client.connect
      channel = connection.channel
      q =
        begin
          channel.queue(queue_name)
        rescue
          channel = connection.channel
          channel.queue(queue_name, passive: true)
        end
      unless exchange_name.empty? && routing_key.empty?
        q.bind(exchange_name, routing_key)
      end
      q.subscribe(block: true, no_ack: true) do |msg|
        if consume_to_files
          filename = String.build do |str|
            time = Time.utc
            str << "consumed_"
            str << exchange_name
            str << "_"
            str << routing_key
            str << "_"
            str << queue_name
            str << "_"
            str << time.to_unix_ms
            str << ".json"
          end
          file = File.new(filename, "w")
          format_output(file, format, msg)
        else
          format_output(STDOUT, format, msg)
        end
      end
    rescue ex
      STDERR.puts ex.message
      sleep 0.1
    end
  end

  private def open_channel_declare_exchange(connection, exchange, exchange_type)
    return if exchange == ""
    channel = connection.channel
    channel.exchange_declare exchange, exchange_type, passive: true
    channel
  rescue
    channel = connection.channel
    channel.exchange_declare exchange, exchange_type, passive: false
    channel
  end

  private def decode_payload(msg, io)
    case msg.properties.content_encoding
    when "deflate"
      Compress::Deflate::Reader.open(msg.body_io) do |r|
        IO.copy(r, io)
      end
    when "gzip"
      Compress::Gzip::Reader.open(msg.body_io) do |r|
        IO.copy(r, io)
      end
    else
      IO.copy(msg.body_io, io)
    end
  end

  private def format_output(io, format_str, msg)
    io.sync = false
    match = false
    escape = false
    Char::Reader.new(format_str).each do |c|
      if c == '%'
        match = true
      elsif match
        case c
        when 's'
          decode_payload(msg, io)
        when 'e'
          io << msg.exchange
        when 'r'
          io << msg.routing_key
        when '%'
          io << '%'
        else
          raise "Invalid substitution argument '%#{c}'"
        end
        match = false
      elsif c == '\\'
        escape = true
      elsif escape
        case c
        when 'n'
          io << '\n'
        when 't'
          io << '\t'
        else
          raise "Invalid escape character '\#{c}'"
        end
        escape = false
      else
        io << c
      end
    end
    io.flush
  end
end

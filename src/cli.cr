require "option_parser"
require "./amqpcat"
require "./version"

uri = "amqp://localhost"
mode = nil
exchange = ""
exchange_type = "direct"
queue = nil
routing_key = nil
format = "%s\n"
consume_to_files = false
publish_confirm = false

FORMAT_STRING_HELP = <<-HELP
Format string (default "%s\\n")
\t\t\t\t     %e: Exchange name
\t\t\t\t     %r: Routing key
\t\t\t\t     %s: Body, as string
\t\t\t\t     \\n: Newline
\t\t\t\t     \\t: Tab
HELP

p = OptionParser.parse do |parser|
  parser.banner = "Usage: #{File.basename PROGRAM_NAME} [arguments]"
  parser.on("-P", "--producer", "Producer mode, reading from STDIN, each line is a new message") { mode = :producer }
  parser.on("-C", "--consumer", "Consume mode, message bodies are written to STDOUT") { mode = :consumer }
  parser.on("-u URI", "--uri=URI", "URI to AMQP server") { |v| uri = v }
  parser.on("-e EXCHANGE", "--exchange=EXCHANGE", "Exchange (default: '')") { |v| exchange = v }
  parser.on("-t EXCHANGETYPE", "--exchange-type=TYPE", "Exchange type (default: direct)") { |v| exchange_type = v }
  parser.on("-r ROUTINGKEY", "--routing-key=KEY", "Routing key when publishing") { |v| routing_key = v }
  parser.on("-q QUEUE", "--queue=QUEUE", "Queue to consume from") { |v| queue = v }
  parser.on("-c", "--publish-confirm", "Confirm publishes") { publish_confirm = true }
  parser.on("-l", "--consume-to-files", "Save consumed messages to timestamped logfiles") { consume_to_files = true }
  parser.on("-f FORMAT", "--format=FORMAT", FORMAT_STRING_HELP) { |v| format = v }
  parser.on("-v", "--version", "Display version") { puts AMQPCat::VERSION; exit 0 }
  parser.on("-h", "--help", "Show this help message") { puts parser; exit 0 }
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid argument."
    abort parser
  end
end

cat = AMQPCat.new(uri)
case mode
when :producer
  unless exchange || queue
    STDERR.puts "Error: Missing exchange or queue argument."
    abort p
  end
  cat.produce(exchange, routing_key || queue || "", exchange_type, publish_confirm)
when :consumer
  unless routing_key || queue
    STDERR.puts "Error: Missing routing key or queue argument."
    abort p
  end
  cat.consume(exchange, routing_key, queue, format, consume_to_files)
else
  STDERR.puts "Error: Missing argument, --producer or --consumer required."
  abort p
end

# amqpcat

netcat for AMQP. CLI tool to publish to and consume from AMQP servers.

## Installation

[Install Crystal](https://crystal-lang.org/install/).

Build from source:
```bash
git clone https://github.com/thomaspeissl/amqpcat.git
cd amqpcat
shards build --release --production
# append --static if you need static linking 
shards build --release --production --static
```
This will create a new folder called `bin` with the `amqpcat` executable.

## Usage

```
Usage: amqpcat [arguments]
    -P, --producer                   Producer mode, reading from STDIN, each line is a new message
    -C, --consumer                   Consume mode, message bodies are written to STDOUT
    -u URI, --uri=URI                URI to AMQP server
    -e EXCHANGE, --exchange=EXCHANGE Exchange
    -r ROUTINGKEY, --routing-key=KEY Routing key when publishing
    -q QUEUE, --queue=QUEUE          Queue to consume from
    -c, --publish-confirm            Confirm publishes
    -l, --consume-to-files           Save consumed messages to timestamped logfiles
    -f FORMAT, --format=FORMAT       Format string (default "%s\n")
				     %e: Exchange name
				     %r: Routing key
				     %s: Body, as string
				     \n: Newline
				     \t: Tab
    -v, --version                    Display version
    -h, --help                       Show this help message
```

## Examples

Send messages to a queue named `test`:

```sh
echo Hello World | amqpcat --producer --uri=$CLOUDAMQP_URL --queue test
```

Consume from the queue named `test`:

```sh
amqpcat --consumer --uri=$CLOUDAMQP_URL --queue test
```

With a temporary queue, consume messages sent to the exchange amq.topic with the routing key 'hello.world':

```sh
amqpcat --consumer --uri=$CLOUDAMQP_URL --exchange amq.topic --routing-key hello.world
```

Consume from the queue named `test`, format the output as CSV and pipe to file:
```sh
amqpcat --consumer --uri=$CLOUDAMQP_URL --queue test --format "%e,%r,"%s"\n | tee messages.csv
```

Publish messages from syslog to the exchange 'syslog' topic with the hostname as routing key
```sh
tail -f /var/log/syslog | amqpcat --producer --uri=$CLOUDAMQP_URL --exchange syslog --routing-key $HOSTNAME
```

Consume, parse and extract data from json messages:
```sh
amqpcat --consumer --queue json | jq .property
```

## Development

amqpcat is built with [Crystal](https://crystal-lang.org/)

Compile and run
```bash
shards run
```

## Credits

- [Carl Hörberg](https://github.com/carlhoerberg) - original creator https://github.com/cloudamqp/amqpcat.git
- [Thomas Peißl](https://github.com/thomaspeissl) - developer https://github.com/thomaspeissl/amqpcat.git

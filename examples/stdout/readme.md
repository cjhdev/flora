STDOUT Demo
===========

This demo sets up an instance of [Flora](https://github.com/cjhdev/flora) to run until an
interrupt signal is received. The application will print events to STDOUT
as they are received.

## Installation and Configuration

### Ruby

Ensure modern-ish Ruby and Bundle are installed. Use Bundle to install
Ruby dependencies:

~~~
bundle install
~~~

### Add Devices

An example `create_device` is in [demo.rb](demo.rb). Copy this pattern, changing
the fields to suit your device(s).

### Configure Application Ports

You may need to change the hostname and ports used by the demo. They
are accessible in the SETTINGS hash at the top of [demo.rb](demo.rb):

- gateway_port: default is 1700; gateway sends upstream to this port
- gateway_host: default binds to all interfaces on localhost

### Configuring LoRa Gateway

This part of the demo assumes you have a LoRa gateway which:

- implements the "Semtech UDP Packet Forwarder" format
- accepts [this](default_eu.json) SX1301 style configuration file 

The configuration provided will work with the "default_eu" channel plan, and should
only be used in that part of the world. Change the following fields:

- gateway_conf.serv_port_up: the Flora listen port (UDP)
- gateway_conf.serv_port_down: the gateway port used for holepunching (UDP)
- gateway_conf.server_address: point to the host running Flora
- gateway_conf.gateway_ID: the EUI of your gateway

## Run the Demo

Once installation and configuration is complete you can run the demo.

~~~
bundle exec ruby demo.rb
~~~

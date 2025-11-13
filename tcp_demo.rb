#!/usr/bin/env ruby
# tcp_demo.rb - Simple TCP Socket Demo
#
# Demonstrates basic TCP client-server communication.
# Both client and server run in the same process using threads.
#
# Usage:
#   ruby tcp_demo.rb                    # MRI
#   jruby -J-cp build tcp_demo.rb       # JRuby

require 'socket'

HOST = 'localhost'
PORT = 9999

puts "=" * 60
puts "TCP Socket Demo"
puts "=" * 60
puts "Ruby: #{RUBY_ENGINE rescue 'ruby'} #{RUBY_VERSION}"
puts ""

# ================================================================
# SERVER: Run in background thread
# ================================================================
puts "Starting TCP server on #{HOST}:#{PORT}..."

server_thread = Thread.new do
  begin
    # Create TCP server
    server = TCPServer.new(HOST, PORT)
    puts "Server listening on #{HOST}:#{PORT}"

    # Accept one client connection
    client = server.accept
    puts "Client connected from #{client.peeraddr[3]}:#{client.peeraddr[1]}"

    # Receive message from client
    msg = client.recv(1024)
    puts "Server received: #{msg}"

    # Send response back to client
    response = "Hello from TCP server! You said: #{msg}"
    client.send(response, 0)
    puts "Server sent response"

    # Clean up
    client.close
    server.close
    puts "Server closed"

  rescue => e
    puts "Server error: #{e.message}"
    puts e.backtrace.first(3)
  end
end

# Give server time to start
sleep 0.5

# ================================================================
# CLIENT: Connect to server
# ================================================================
puts "\nConnecting TCP client to #{HOST}:#{PORT}..."

begin
  # Create client socket and connect
  client = TCPSocket.new(HOST, PORT)
  puts "Client connected"

  # Get connection info
  local = client.addr
  remote = client.peeraddr
  puts "Local:  #{local[3]}:#{local[1]}"
  puts "Remote: #{remote[3]}:#{remote[1]}"

  # Send message to server
  message = "Hello TCP server!"
  client.send(message, 0)
  puts "Client sent: #{message}"

  # Receive response from server
  response = client.recv(1024)
  puts "Client received: #{response}"

  # Clean up
  client.close
  puts "Client closed"

rescue => e
  puts "Client error: #{e.message}"
  puts e.backtrace.first(3)
end

# ================================================================
# CLEANUP
# ================================================================

# Wait for server thread to finish
server_thread.join

puts ""
puts "=" * 60
puts "Demo complete!"
puts "=" * 60

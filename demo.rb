#!/usr/bin/env ruby
# demo.rb - Simple Unix Domain Socket Demo
#
# Demonstrates basic client-server communication using Unix sockets.
# Both client and server run in the same process using threads.
#
# This works on both MRI Ruby and JRuby (with compiled extensions).
#
# Usage:
#   ruby demo.rb                    # MRI
#   jruby -J-cp build demo.rb       # JRuby
#
# Expected output:
#   Starting server...
#   Server listening
#   Connecting client...
#   Client connected
#   Received: Hello server
#   Got response: Hello back
#   Done

require 'socket'

# Socket file path (temporary file)
SOCKET_PATH = "/tmp/demo.sock"

# Clean up any existing socket file
File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)

puts "Starting server..."

# ================================================================
# SERVER: Run in background thread
# ================================================================
server_thread = Thread.new do
  # Create server socket
  server = UNIXServer.new(SOCKET_PATH)
  puts "Server listening on #{SOCKET_PATH}"

  # Accept one client connection
  client = server.accept
  puts "Client connected"

  # Receive message from client
  msg = client.recv(1024)
  puts "Server received: #{msg}"

  # Send response back to client
  client.send("Hello back", 0)

  # Clean up
  client.close
  server.close
end

# Give server time to start
sleep 0.5

# ================================================================
# CLIENT: Connect to server
# ================================================================
puts "Connecting client..."

# Create client socket and connect
client = UNIXSocket.new(SOCKET_PATH)

# Send message to server
client.send("Hello server", 0)

# Receive response from server
response = client.recv(1024)
puts "Client received: #{response}"

# Clean up
client.close

# ================================================================
# CLEANUP
# ================================================================

# Wait for server thread to finish
server_thread.join

# Remove socket file
File.delete(SOCKET_PATH) if File.exist?(SOCKET_PATH)

puts "\nDemo complete!"
puts "Ruby: #{RUBY_ENGINE rescue 'ruby'} #{RUBY_VERSION}"


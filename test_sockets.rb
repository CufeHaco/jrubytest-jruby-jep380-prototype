#!/usr/bin/env ruby
# test_sockets.rb - Unix Domain Socket Test Suite
#
# Comprehensive tests for Unix socket functionality.
# Tests basic connections, large data transfers, and concurrent clients.
#
# Usage:
#   ruby test_sockets.rb                    # MRI
#   jruby -J-cp build test_sockets.rb       # JRuby
#
# Tests:
#   1. Basic connection - Simple send/receive
#   2. Large data - 10KB transfer in chunks
#   3. Concurrent clients - 5 simultaneous connections

require 'socket'

# ================================================================
# TEST 1: Basic Connection
# ================================================================
# Tests simple client-server communication
def test_basic
  path = "/tmp/test_basic.sock"
  File.delete(path) if File.exist?(path)

  # Start echo server
  server_thread = Thread.new do
    server = UNIXServer.new(path)
    client = server.accept
    msg = client.recv(100)
    client.send("ECHO: #{msg}", 0)
    client.close
    server.close
  end

  sleep 0.1

  # Connect client and test
  client = UNIXSocket.new(path)
  client.send("TEST", 0)
  response = client.recv(100)
  client.close

  # Cleanup
  server_thread.join
  File.delete(path)

  # Verify
  response == "ECHO: TEST"
end

# ================================================================
# TEST 2: Large Data Transfer
# ================================================================
# Tests transferring 10KB of data in 1KB chunks
def test_large_data
  path = "/tmp/test_large.sock"
  File.delete(path) if File.exist?(path)

  # Test data: 10,000 bytes
  data = "X" * 10000

  # Start receiving server
  server_thread = Thread.new do
    server = UNIXServer.new(path)
    client = server.accept
    received = ""

    # Receive data in chunks
    while chunk = client.recv(1024)
      received << chunk
      break if received.size >= data.size
    end

    client.close
    server.close
    received
  end

  sleep 0.1

  # Send data from client in chunks
  client = UNIXSocket.new(path)
  sent = 0
  while sent < data.size
    chunk = data[sent, 1024]
    client.send(chunk, 0)
    sent += chunk.size
  end
  client.close

  # Verify all data received
  received = server_thread.value
  File.delete(path)

  received.size == data.size
end

# ================================================================
# TEST 3: Concurrent Clients
# ================================================================
# Tests handling 5 simultaneous client connections
def test_concurrent
  path = "/tmp/test_concurrent.sock"
  File.delete(path) if File.exist?(path)

  num_clients = 5

  # Start server that accepts multiple clients
  server_thread = Thread.new do
    server = UNIXServer.new(path)
    num_clients.times do |i|
      client = server.accept
      msg = client.recv(100)
      client.send("ACK#{i}", 0)
      client.close
    end
    server.close
  end

  sleep 0.1

  # Create multiple client threads
  threads = num_clients.times.map do |i|
    Thread.new do
      client = UNIXSocket.new(path)
      client.send("MSG#{i}", 0)
      response = client.recv(100)
      client.close
      response
    end
  end

  # Wait for all clients to complete
  results = threads.map(&:value)
  server_thread.join
  File.delete(path)

  # Verify all clients got responses
  results.size == num_clients
end

# ================================================================
# TEST RUNNER
# ================================================================

if __FILE__ == $0
  puts "=" * 60
  puts "Unix Domain Socket Test Suite"
  puts "=" * 60
  puts "Ruby: #{RUBY_ENGINE rescue 'ruby'} #{RUBY_VERSION}"
  puts ""

  # Test definitions
  tests = {
    'Basic connection' => method(:test_basic),
    'Large data (10KB)' => method(:test_large_data),
    'Concurrent clients (5)' => method(:test_concurrent)
  }

  passed = 0
  failed = 0

  # Run each test
  tests.each do |name, test|
    print "  #{name}... "
    begin
      if test.call
        puts "✓ PASS"
        passed += 1
      else
        puts "✗ FAIL"
        failed += 1
      end
    rescue => e
      puts "✗ FAIL: #{e.message}"
      puts "    #{e.backtrace.first}" if ENV['DEBUG']
      failed += 1
    end
  end

  # Summary
  puts ""
  puts "=" * 60
  puts "Results: #{passed} passed, #{failed} failed"
  puts "=" * 60

  # Exit with appropriate code
  exit(failed > 0 ? 1 : 0)
end

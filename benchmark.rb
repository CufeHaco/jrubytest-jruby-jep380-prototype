#!/usr/bin/env ruby
# benchmark.rb - Unix Domain Socket Performance Benchmarks
#
# Measures throughput and latency for different message sizes.
# Tests small (100 bytes), medium (1KB), and large (10KB) messages.
#
# Usage:
#   ruby benchmark.rb                    # MRI
#   jruby -J-cp build benchmark.rb       # JRuby
#
# Metrics:
#   - Throughput: Messages per second
#   - Latency: Average round-trip time in milliseconds

require 'socket'

# ================================================================
# Benchmark Runner
# ================================================================
# Runs a ping-pong benchmark between client and server
#
# @param name [String] Benchmark description
# @param iterations [Integer] Number of messages to send
# @param message_size [Integer] Size of each message in bytes
def run_benchmark(name, iterations, message_size)
  path = "/tmp/bench_#{name.gsub(/\s+/, '_')}.sock"
  File.delete(path) if File.exist?(path)

  # Create test message
  message = "X" * message_size

  # Start echo server
  server_thread = Thread.new do
    server = UNIXServer.new(path)
    client = server.accept

    # Echo messages back
    iterations.times do
      msg = client.recv(message_size + 100)
      client.send(msg, 0)
    end

    client.close
    server.close
  end

  sleep 0.1

  # Client: send and receive messages, measure time
  start_time = Time.now
  client = UNIXSocket.new(path)

  iterations.times do
    client.send(message, 0)
    client.recv(message_size + 100)
  end

  elapsed = Time.now - start_time
  client.close

  # Wait for server
  server_thread.join
  File.delete(path)

  # Calculate metrics
  throughput = iterations / elapsed
  avg_latency = (elapsed / iterations) * 1000  # Convert to ms
  data_transferred = (iterations * message_size * 2) / 1024.0 / 1024.0  # MB

  # Display results
  puts "#{name}:"
  puts "  Iterations:  #{iterations}"
  puts "  Time:        #{elapsed.round(3)}s"
  puts "  Throughput:  #{throughput.round(1)} msg/sec"
  puts "  Avg Latency: #{avg_latency.round(3)}ms"
  puts "  Data:        #{data_transferred.round(2)}MB transferred"
  puts ""
end

# ================================================================
# Run Benchmarks
# ================================================================

if __FILE__ == $0
  puts "=" * 60
  puts "Unix Domain Socket Performance Benchmarks"
  puts "=" * 60
  puts "Ruby: #{RUBY_ENGINE rescue 'ruby'} #{RUBY_VERSION}"
  puts "Date: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  puts ""

  # Run benchmarks with different message sizes
  run_benchmark("Small messages (100 bytes)", 1000, 100)
  run_benchmark("Medium messages (1KB)", 500, 1024)
  run_benchmark("Large messages (10KB)", 100, 10240)

  puts "=" * 60
  puts "Benchmark complete!"
  puts "=" * 60
end


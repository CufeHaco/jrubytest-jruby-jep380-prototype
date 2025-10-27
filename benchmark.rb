# benchmark.rb
require 'socket'

def run_benchmark(name, iterations, message_size)
  path = "/tmp/bench_#{name}.sock"
  File.delete(path) if File.exist?(path)
  
  message = "X" * message_size
  
  server_thread = Thread.new do
    server = UNIXServer.new(path)
    client = server.accept
    iterations.times do
      msg = client.recv(message_size + 100)
      client.send(msg, 0)
    end
    client.close
    server.close
  end
  
  sleep 0.1
  
  start_time = Time.now
  client = UNIXSocket.new(path)
  iterations.times do
    client.send(message, 0)
    client.recv(message_size + 100)
  end
  elapsed = Time.now - start_time
  client.close
  
  server_thread.join
  File.delete(path)
  
  throughput = iterations / elapsed
  avg_latency = (elapsed / iterations) * 1000
  
  puts "#{name}:"
  puts "  Time: #{elapsed.round(3)}s"
  puts "  Throughput: #{throughput.round(1)} msg/sec"
  puts "  Avg latency: #{avg_latency.round(3)}ms"
  puts ""
end

puts "Unix Socket Benchmarks"
puts "======================"
puts ""

run_benchmark("Small (100 bytes)", 1000, 100)
run_benchmark("Medium (1KB)", 500, 1024)
run_benchmark("Large (10KB)", 100, 10240)


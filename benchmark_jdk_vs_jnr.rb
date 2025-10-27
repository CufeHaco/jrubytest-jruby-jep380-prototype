require 'java'
require 'socket'
require 'benchmark'

java_import 'org.jruby.ext.socket.UnixSocketChannelFactory'

class UnixSocketBenchmark
  def self.run
    puts "=" * 60
    puts "Unix Socket Performance Benchmark"
    puts "Implementation: #{UnixSocketChannelFactory.getImplementation}"
    puts "=" * 60
    puts
    
    benchmarks = {
      'Small messages (100 bytes)' => method(:bench_small_messages),
      'Medium messages (1 KB)' => method(:bench_medium_messages),
      'Large messages (1 MB)' => method(:bench_large_messages),
      'High frequency (1000 msgs)' => method(:bench_high_frequency)
    }
    
    benchmarks.each do |name, bench_method|
      puts "\n#{name}:"
      puts "-" * 60
      bench_method.call
    end
  end
  
  def self.bench_small_messages
    socket_path = "/tmp/bench_small_#{Process.pid}.sock"
    iterations = 1000
    message = "X" * 100
    
    run_benchmark(socket_path, iterations, message)
  end
  
  def self.bench_medium_messages
    socket_path = "/tmp/bench_medium_#{Process.pid}.sock"
    iterations = 500
    message = "X" * 1024
    
    run_benchmark(socket_path, iterations, message)
  end
  
  def self.bench_large_messages
    socket_path = "/tmp/bench_large_#{Process.pid}.sock"
    iterations = 50
    message = "X" * (1024 * 1024)
    
    run_benchmark(socket_path, iterations, message)
  end
  
  def self.bench_high_frequency
    socket_path = "/tmp/bench_freq_#{Process.pid}.sock"
    iterations = 10000
    message = "PING"
    
    run_benchmark(socket_path, iterations, message)
  end
  
  def self.run_benchmark(socket_path, iterations, message)
    File.delete(socket_path) if File.exist?(socket_path)
    
    server_ready = false
    
    server_thread = Thread.new do
      server = UNIXServer.new(socket_path)
      server_ready = true
      
      client = server.accept
      
      iterations.times do
        msg = client.recv(message.size + 100)
        client.send(msg, 0)
      end
      
      client.close
      server.close
    end
    
    sleep 0.01 until server_ready
    sleep 0.1
    
    time = Benchmark.realtime do
      client = UNIXSocket.new(socket_path)
      
      iterations.times do
        client.send(message, 0)
        client.recv(message.size + 100)
      end
      
      client.close
    end
    
    server_thread.join
    
    throughput = iterations / time
    puts "  Time: #{time.round(3)}s"
    puts "  Throughput: #{throughput.round(2)} msgs/sec"
    puts "  Avg latency: #{(time / iterations * 1000).round(3)}ms per round-trip"
    
  ensure
    File.delete(socket_path) if File.exist?(socket_path)
  end
end

UnixSocketBenchmark.run

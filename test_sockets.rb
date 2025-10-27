# test_sockets.rb
require 'socket'

def test_basic
  path = "/tmp/test_basic.sock"
  File.delete(path) if File.exist?(path)
  
  server_thread = Thread.new do
    server = UNIXServer.new(path)
    client = server.accept
    msg = client.recv(100)
    client.send("ECHO: #{msg}", 0)
    client.close
    server.close
  end
  
  sleep 0.1
  
  client = UNIXSocket.new(path)
  client.send("TEST", 0)
  response = client.recv(100)
  client.close
  
  server_thread.join
  File.delete(path)
  
  response == "ECHO: TEST"
end

def test_large_data
  path = "/tmp/test_large.sock"
  File.delete(path) if File.exist?(path)
  
  data = "X" * 10000
  
  server_thread = Thread.new do
    server = UNIXServer.new(path)
    client = server.accept
    received = ""
    while chunk = client.recv(1024)
      received << chunk
      break if received.size >= data.size
    end
    client.close
    server.close
    received
  end
  
  sleep 0.1
  
  client = UNIXSocket.new(path)
  sent = 0
  while sent < data.size
    chunk = data[sent, 1024]
    client.send(chunk, 0)
    sent += chunk.size
  end
  client.close
  
  received = server_thread.value
  File.delete(path)
  
  received.size == data.size
end

def test_concurrent
  path = "/tmp/test_concurrent.sock"
  File.delete(path) if File.exist?(path)
  
  num_clients = 5
  
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
  
  threads = num_clients.times.map do |i|
    Thread.new do
      client = UNIXSocket.new(path)
      client.send("MSG#{i}", 0)
      response = client.recv(100)
      client.close
      response
    end
  end
  
  results = threads.map(&:value)
  server_thread.join
  File.delete(path)
  
  results.size == num_clients
end

# Run tests
tests = {
  'Basic connection' => method(:test_basic),
  'Large data (10KB)' => method(:test_large_data),
  'Concurrent clients' => method(:test_concurrent)
}

passed = 0
failed = 0

tests.each do |name, test|
  print "#{name}... "
  begin
    if test.call
      puts "PASS"
      passed += 1
    else
      puts "FAIL"
      failed += 1
    end
  rescue => e
    puts "FAIL: #{e.message}"
    failed += 1
  end
end

puts ""
puts "Results: #{passed} passed, #{failed} failed"
exit(failed > 0 ? 1 : 0)

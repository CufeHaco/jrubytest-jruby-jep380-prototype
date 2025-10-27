# demo.rb
require 'socket'

path = "/tmp/demo.sock"
File.delete(path) if File.exist?(path)

puts "Starting server..."
server_thread = Thread.new do
  server = UNIXServer.new(path)
  puts "Server listening"
  client = server.accept
  puts "Client connected"
  msg = client.recv(1024)
  puts "Received: #{msg}"
  client.send("Hello back", 0)
  client.close
  server.close
end

sleep 0.5

puts "Connecting client..."
client = UNIXSocket.new(path)
client.send("Hello server", 0)
response = client.recv(1024)
puts "Got response: #{response}"
client.close

server_thread.join
File.delete(path)
puts "Done"


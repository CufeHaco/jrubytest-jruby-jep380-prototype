#!/usr/bin/env ruby
# chat_demo.rb - Peer-to-Peer Unix Socket Chat
#
# Real-time P2P chat application using Unix domain sockets.
# Each user runs their own instance with a dedicated socket.
# Messages are sent directly between users without a central server.
#
# Usage:
#   # Terminal 1 (user alice)
#   ruby chat_demo.rb
#
#   # Terminal 2 (user bob)
#   ruby chat_demo.rb
#
#   # Cross-user chat (e.g., your user and root)
#   CHAT_MULTIUSER=1 ruby chat_demo.rb
#
# Commands:
#   @username       # Send message to user
#   /list           # List online users
#   /quit           # Exit chat
#
# Features:
#   - Direct peer-to-peer messaging
#   - Multiline message composer
#   - Real-time message delivery
#   - Cross-user support (optional)
#   - Works on both MRI and JRuby

require 'socket'
require 'fileutils'

# Reusable multiline editor component
class MultilineEditor
  def compose(&block)
    lines = []
    puts "Type your message (type 'exit' or Ctrl+D to send):"
    loop do
      print '> '
      STDOUT.flush
      text = STDIN.gets
      break if text.nil? || text.chomp == 'exit'
      lines << text.chomp
    end
    content = lines.join("\n")
    block.call(content) if block_given?
    content
  end
end

# Background message handler (processes messages immediately in background)
class MessageHandler
  # Shared mutex for all STDIN operations
  @@stdin_mutex = Mutex.new

  def initialize(user, editor)
    @user = user
    @editor = editor
    @processing = true
  end

  def handle_message(sender, message, client)
    # Use mutex to prevent concurrent STDIN reads
    @@stdin_mutex.synchronize do
      # Display incoming message immediately (interrupts current prompt)
      puts "\n" + "=" * 50
      puts "[INCOMING MESSAGE FROM: #{sender}]"
      puts message
      puts "=" * 50
      puts ""

      print "Reply? (y=yes, n=no, Enter to skip): "
      STDOUT.flush

      # Read response without blocking main thread
      response = STDIN.gets
      if response.nil?
        send_reply(client, "(no reply)")
        puts "✓ Connection closed"
        return
      end

      response = response.chomp.downcase.strip

      if response == 'y' || response == 'yes'
        puts "\nComposing reply to #{sender}..."
        reply = @editor.compose

        if reply.strip.empty?
          send_reply(client, "(no reply)")
          puts "✓ Empty message, sent acknowledgment"
        else
          send_reply(client, reply)
          puts "✓ Reply sent to #{sender}"
        end
      else
        send_reply(client, "(no reply)")
        puts "✓ Message acknowledged (no reply sent)"
      end

      # Redraw the prompt
      print "\n#{@user}> "
      STDOUT.flush
    end
  rescue => e
    puts "\n[ERROR] handling message: #{e.message}"
    puts e.backtrace.first(3)
    client.close rescue nil
  end

  def send_reply(client, reply)
    # Send with newline delimiters to ensure proper separation
    client.send("#{@user}\n", 0)
    client.send("#{reply}\n", 0)
    client.close
  rescue => e
    puts "[ERROR] sending reply: #{e.message}"
    client.close rescue nil
  end

  def stop
    @processing = false
  end
end

# Socket transport backend
class SocketTransport
  def initialize(message_handler)
    @user = ENV['USER'] || 'unknown'
    @chat_dir = '/tmp/rubian_chat'
    FileUtils.mkdir_p(@chat_dir)
    @my_socket_path = File.join(@chat_dir, "#{@user}.sock")
    # Allow cross-user chat if CHAT_MULTIUSER is set (e.g., chat between user and root)
    @allow_multiuser = ENV['CHAT_MULTIUSER'] == '1'
    @message_handler = message_handler
    setup_listener
  end

  def setup_listener
    File.delete(@my_socket_path) if File.exist?(@my_socket_path)

    @server_thread = Thread.new do
      server = UNIXServer.new(@my_socket_path)
      # Set permissions based on multiuser mode
      perms = @allow_multiuser ? 0666 : 0600
      File.chmod(perms, @my_socket_path)

      loop do
        begin
          client = server.accept
          # Handle each message in its own thread for real-time processing
          Thread.new { handle_incoming(client) }
        rescue => e
          puts "\n[ERROR] #{e.message}" unless @stopped
        end
      end
    end
  end

  def handle_incoming(client)
    # Receive with newline delimiters and nil safety
    sender_data = client.recv(256)
    return unless sender_data && !sender_data.empty?
    sender = sender_data.split("\n").first&.strip || "unknown"

    message_data = client.recv(8192)
    return unless message_data && !message_data.empty?
    message = message_data.split("\n").first&.strip || ""

    # Process message immediately in background
    @message_handler.handle_message(sender, message, client)
  rescue => e
    puts "\n[ERROR] receiving message: #{e.message}"
    puts e.backtrace.first(3) if ENV['DEBUG']
    client.close rescue nil
  end

  def send_to(target, message)
    target_path = File.join(@chat_dir, "#{target}.sock")

    unless File.exist?(target_path)
      puts "User @#{target} is not online (socket not found)"
      return false
    end

    begin
      socket = UNIXSocket.new(target_path)
      # Send with newline delimiters
      socket.send("#{@user}\n", 0)
      socket.send("#{message}\n", 0)

      puts "\nMessage sent to @#{target}. Waiting for reply..."
      puts "(waiting up to 60 seconds...)"

      # Use IO.select for timeout instead of setsockopt (more portable)
      ready = IO.select([socket], nil, nil, 60)
      unless ready
        puts "Timed out waiting for reply (60 seconds)"
        socket.close
        return false
      end

      # Receive with newline handling and nil safety
      reply_user_data = socket.recv(256)
      if reply_user_data.nil? || reply_user_data.empty?
        puts "No reply received (connection closed)"
        socket.close
        return false
      end
      reply_user = reply_user_data.split("\n").first&.strip || "unknown"

      # Wait for message data with timeout
      ready = IO.select([socket], nil, nil, 5)
      unless ready
        puts "Reply incomplete (timed out waiting for message)"
        socket.close
        return false
      end

      reply_msg_data = socket.recv(8192)
      if reply_msg_data.nil? || reply_msg_data.empty?
        puts "Reply incomplete (connection closed)"
        socket.close
        return false
      end
      reply_msg = reply_msg_data.split("\n").first&.strip || "(no message)"

      puts "\n" + "=" * 50
      puts "[Reply from #{reply_user}]"
      puts reply_msg
      puts "=" * 50

      socket.close
      true
    rescue => e
      puts "Failed to send: #{e.message}"
      puts e.backtrace.first(3) if ENV['DEBUG']
      socket.close rescue nil
      false
    end
  end

  def list_online
    users = Dir.glob(File.join(@chat_dir, '*.sock')).map do |path|
      File.basename(path, '.sock')
    end
    users - [@user]
  end

  def stop
    @stopped = true
    @server_thread.kill if @server_thread
    File.delete(@my_socket_path) if File.exist?(@my_socket_path)
  end
end

# Main chat interface
class ChatDemo
  # Access the shared STDIN mutex
  def self.stdin_mutex
    MessageHandler.class_variable_get(:@@stdin_mutex)
  end

  def initialize
    @user = ENV['USER'] || 'unknown'
    @editor = MultilineEditor.new
    @message_handler = MessageHandler.new(@user, @editor)
    @transport = SocketTransport.new(@message_handler)
    @running = true

    trap('INT') { shutdown }
    trap('TERM') { shutdown }
  end

  def run
    puts "=" * 50
    puts "Rubian Chat Demo (Real-time)"
    puts "=" * 50
    puts "User: #{@user}"
    puts "Ruby: #{RUBY_ENGINE rescue 'ruby'} #{RUBY_VERSION}"
    multiuser = ENV['CHAT_MULTIUSER'] == '1' ? 'enabled' : 'disabled'
    puts "Cross-user mode: #{multiuser}"
    puts ""
    puts "Commands:"
    puts "  @username  - Send message to user"
    puts "  /list      - List online users"
    puts "  /quit      - Exit chat"
    puts ""
    puts "Tip: Set CHAT_MULTIUSER=1 to chat with different users (e.g., root)"
    puts "=" * 50
    puts ""

    prompt_shown = false

    while @running
      begin
        # Show prompt only once, not on every timeout
        unless prompt_shown
          print "\n#{@user}> "
          STDOUT.flush
          prompt_shown = true
        end

        # Use select with timeout so we don't block indefinitely
        # This allows background threads to display incoming messages
        ready = IO.select([STDIN], nil, nil, 0.5)
        next unless ready  # Timeout - loop again (allows background msgs to appear)

        input = STDIN.gets
        prompt_shown = false  # Will show prompt next iteration

        break if input.nil?  # EOF or Ctrl+D
        next if input.strip.empty?

        case input.strip
        when /^@(\w+)$/
          send_message($1)
        when '/list'
          list_users
        when '/quit', '/exit'
          shutdown
        else
          puts "Unknown command. Use @username to send, /list or /quit"
        end
      rescue Interrupt
        shutdown
      rescue => e
        puts "Error: #{e.message}"
      end
    end
  end

  def send_message(target)
    puts "\nComposing message for @#{target}..."
    message = @editor.compose
    
    if message.empty?
      puts "Message cancelled (empty)"
      return
    end
    
    @transport.send_to(target, message)
  end

  def list_users
    users = @transport.list_online
    if users.empty?
      puts "No other users online"
    else
      puts "Online users: #{users.join(', ')}"
    end
  end

  def shutdown
    puts "\nShutting down..."
    @running = false
    @message_handler.stop if @message_handler
    @transport.stop
    exit(0)
  end
end

# Run the demo
if __FILE__ == $0
  ChatDemo.new.run
end

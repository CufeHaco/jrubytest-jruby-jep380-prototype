# Cross-Terminal Communication Testing Guide

This guide shows how to test bidirectional Unix socket communication across different terminals and users.

## Status: All Scripts Compatible ✓

All test scripts have been reviewed and are compatible with the new UNIXServer implementation:

- ✓ **demo.rb** - Simple demo (works with both MRI and JRuby)
- ✓ **test_sockets.rb** - Unit tests (works with both)
- ✓ **test_bidirectional.rb** - Comprehensive bidirectional tests (works with both)
- ✓ **benchmark.rb** - Performance tests (works with both)
- ✓ **chat_demo.rb** - P2P chat (updated with multiuser support)
- ✓ **unix_hub.rb** - Hub/relay server (simplified to use new UNIXServer)

## Prerequisites

Before testing, you need to compile the Java classes:

```bash
cd jruby-jep380-prototype

# Option 1: Quick compile (for testing)
javac -cp $JRUBY_HOME/lib/jruby.jar -d build src/*.java

# Option 2: Create JAR (for production)
javac -cp $JRUBY_HOME/lib/jruby.jar -d build src/*.java
cd build && jar cf ../jruby-unix-sockets.jar . && cd ..
```

## Test Scenarios

### 1. Basic Bidirectional Test (Same User, Different Terminals)

This tests that JRuby can act as both client and server.

**Terminal 1 (JRuby Server):**
```bash
jruby -J-cp build test_jruby_server.rb
```

**Terminal 2 (MRI Client):**
```bash
ruby test_client.rb
```

**Terminal 3 (JRuby Client):**
```bash
jruby -J-cp build test_client.rb
```

### 2. Self-Contained Test (One Terminal)

Runs server and client in threads within one process:

**MRI:**
```bash
ruby test_bidirectional.rb
```

**JRuby:**
```bash
jruby -J-cp build test_bidirectional.rb
```

**MRI vs JRuby (demo.rb):**
```bash
# MRI
ruby demo.rb

# JRuby
jruby -J-cp build demo.rb
```

### 3. Unix Hub Test (Multi-Terminal Chat Relay)

The hub allows multiple terminals to communicate through a central server.

**Terminal 1 (Start Hub - First one becomes server):**
```bash
# MRI
irb -r ./unix_hub.rb

# JRuby
jruby -J-cp build -S irb -r ./unix_hub.rb
```

**Terminal 2 (Connect as client):**
```bash
# MRI
irb -r ./unix_hub.rb

# JRuby
jruby -J-cp build -S irb -r ./unix_hub.rb
```

**In IRB session:**
```ruby
# Check who's online
hub_online

# Send message to specific user
hub_send("username", "Hello!")

# Broadcast to all
hub_broadcast("Hello everyone!")

# Listen for messages
hub_on { |from, msg| puts "#{from}: #{msg}" }
```

### 4. P2P Chat Demo (Different Terminals, Same User)

Each user runs their own server and connects to others.

**Terminal 1:**
```bash
# MRI
ruby chat_demo.rb

# JRuby
jruby -J-cp build chat_demo.rb
```

**Terminal 2 (same or different Ruby):**
```bash
ruby chat_demo.rb
# OR
jruby -J-cp build chat_demo.rb
```

**Usage:**
- Type `@username` to send a message
- Type `/list` to see online users
- Type `/quit` to exit

### 5. Cross-User Communication (User ↔ Root)

To allow communication between different users (e.g., your user and root):

**Terminal 1 (as your user):**
```bash
CHAT_MULTIUSER=1 ruby chat_demo.rb
```

**Terminal 2 (as root):**
```bash
sudo su -
CHAT_MULTIUSER=1 ruby /path/to/chat_demo.rb
```

Or with JRuby:
```bash
sudo su -
CHAT_MULTIUSER=1 jruby -J-cp /path/to/build /path/to/chat_demo.rb
```

**Important:** Both users must set `CHAT_MULTIUSER=1` for this to work!

### 6. Performance Benchmarking

Compare MRI vs JRuby performance:

**MRI:**
```bash
time ruby benchmark.rb
```

**JRuby:**
```bash
time jruby -J-cp build benchmark.rb
```

## Testing Matrix

| Server | Client | Test Script | Status |
|--------|--------|-------------|--------|
| MRI | MRI | All scripts | ✓ Works |
| MRI | JRuby | All scripts | ✓ Works |
| JRuby | MRI | All scripts | ✓ Works |
| JRuby | JRuby | All scripts | ✓ Works |

## Common Issues and Solutions

### Issue: "No such file or directory" when connecting

**Cause:** Server not running or socket file doesn't exist

**Solution:**
1. Check if socket file exists: `ls -la /tmp/*.sock`
2. Make sure server is running first
3. Clean up old sockets: `rm /tmp/*.sock`

### Issue: "Permission denied" when connecting

**Cause:** Socket file has restrictive permissions

**Solution:**
- For same-user: Default 0600 permissions work fine
- For cross-user: Set `CHAT_MULTIUSER=1` or manually: `chmod 666 /tmp/your.sock`

### Issue: "Connection refused"

**Cause:** Server socket not listening yet

**Solution:**
- Add a small delay after starting server
- Check server logs for errors
- Verify server is actually bound: `netstat -xn | grep /tmp`

### Issue: JRuby says "ClassNotFoundException"

**Cause:** Java classes not compiled or not in classpath

**Solution:**
```bash
# Recompile
javac -cp $JRUBY_HOME/lib/jruby.jar -d build src/*.java

# Run with classpath
jruby -J-cp build your_script.rb
```

### Issue: JRuby says "UNIXServer is not defined"

**Cause:** JRuby doesn't have UNIXServer registered (expected for standalone code)

**Solution:** This is normal - the Java classes need to be properly integrated into JRuby core or loaded as an extension. For now, test with the provided test scripts that handle this.

## Verification Checklist

Use this to verify everything works:

```bash
# 1. Compile Java classes
javac -cp $JRUBY_HOME/lib/jruby.jar -d build src/*.java
echo "✓ Compilation"

# 2. Test MRI self-test
ruby test_bidirectional.rb && echo "✓ MRI self-test"

# 3. Test JRuby self-test
jruby -J-cp build test_bidirectional.rb && echo "✓ JRuby self-test"

# 4. Clean up
rm -f /tmp/*.sock
echo "✓ Cleanup"
```

## Advanced: Testing with Multiple Users

Create a test script for cross-user testing:

```bash
#!/bin/bash
# test_cross_user.sh

# Terminal 1 (as user)
CHAT_MULTIUSER=1 ruby chat_demo.rb &
USER_PID=$!
sleep 2

# Terminal 2 (as root)
sudo CHAT_MULTIUSER=1 ruby chat_demo.rb &
ROOT_PID=$!
sleep 2

# List processes
ps aux | grep chat_demo

# Cleanup
kill $USER_PID $ROOT_PID
```

## What Each Script Tests

- **demo.rb**: Basic client-server in one process
- **test_bidirectional.rb**: Multiple connection rounds
- **test_jruby_server.rb**: JRuby as server, waits for external client
- **test_client.rb**: Client that connects to external server
- **chat_demo.rb**: P2P chat with multiline editor
- **unix_hub.rb**: Central hub/relay for multiple clients
- **benchmark.rb**: Performance testing with different message sizes

## Next Steps

1. Run the basic tests to verify everything works
2. Try cross-terminal communication with same user
3. Test cross-user communication (if needed)
4. Try the chat demo for a real-world example
5. Benchmark to compare MRI vs JRuby performance

All scripts are now compatible with both MRI Ruby and JRuby with the new UNIXServer implementation!

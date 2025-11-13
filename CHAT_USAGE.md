# Chat Demo Usage Guide

## Quick Start

### Same User, Different Terminals

**Terminal 1:**
```bash
./start_chat.sh
```

**Terminal 2:**
```bash
USER=testuser ./start_chat.sh
```

Now you can chat between `katcv` and `testuser`.

### Cross-User Chat (User ↔ Root)

**Terminal 1 (as katcv):**
```bash
./start_chat.sh multiuser
```

**Terminal 2 (as root):**
```bash
sudo ./start_chat.sh multiuser
```

Now `katcv` and `root` can chat!

## What Fixed

### Issue 1: Permission Denied ✓ Fixed
**Problem:** Getting "Permission denied" when connecting to other user's socket

**Solution:** Both users MUST run with `multiuser` flag:
```bash
# Wrong - permission denied
ruby chat_demo.rb                    # Creates 0600 socket (owner only)
sudo ruby chat_demo.rb              # Creates 0600 socket (owner only)

# Correct - cross-user works
./start_chat.sh multiuser           # Creates 0666 socket (all users)
sudo ./start_chat.sh multiuser      # Creates 0666 socket (all users)
```

### Issue 2: Reply Display Bug ✓ Fixed
**Problem:** Replies showed as `[katcv(no reply)]` instead of separate username and message

**Solution:** Added newline delimiters (`\n`) between username and message:
```ruby
# Old (messages could get concatenated)
socket.send(@user, 0)
socket.send(message, 0)

# New (proper separation)
socket.send("#{@user}\n", 0)
socket.send("#{message}\n", 0)
```

### Issue 3: Reply Prompt Confusion ✓ Fixed
**Problem:** Typing 'y' sometimes didn't trigger reply composition

**Solution:** Improved prompt and input handling:
```
Old: "Reply? (y/n): "
New: "Reply? (y=yes, n=no, Enter to skip): "
```

Now accepts: `y`, `yes`, `Y`, `YES` (case-insensitive)

## Chat Commands

Once in the chat:

```
katcv> @root              # Send message to 'root'
katcv> /list              # List online users
katcv> /quit              # Exit chat
```

## Sending a Message

```
katcv> @root

Composing message for @root...
Type your message (type 'exit' or Ctrl+D to send):
> Hello from katcv!
> This is a multiline message
> exit

Message sent to @root. Waiting for reply...

==================================================
[Reply from root]
Hi back from root!
==================================================
```

## Receiving a Message

Messages appear **in real-time** while you're using the chat:

```
katcv>

==================================================
[INCOMING MESSAGE FROM: root]
Hello katcv!
==================================================

Reply? (y=yes, n=no, Enter to skip): y

Composing reply to root...
Type your message (type 'exit' or Ctrl+D to send):
> Hi root!
> exit
✓ Reply sent to root

katcv>
```

## Troubleshooting

### Still getting "Permission denied"?

**Check 1:** Both users using multiuser flag?
```bash
# Terminal 1
./start_chat.sh multiuser

# Terminal 2
sudo ./start_chat.sh multiuser
```

**Check 2:** Socket file permissions
```bash
ls -la /tmp/rubian_chat/
# Should show -rw-rw-rw- (666) for multiuser
# or -rw------- (600) for single user
```

**Check 3:** Clean up old sockets
```bash
rm -rf /tmp/rubian_chat/
# Then restart both chat instances
```

### Reply shows "(no reply)"?

This is normal when:
- You press Enter without typing 'y'
- You press 'n' to skip replying
- You compose an empty message

### Messages not appearing in real-time?

Make sure you're using the updated `chat_demo.rb` with the `MessageHandler` class. The old version queued messages.

## Testing Checklist

- [ ] Same user, different terminals works
- [ ] Cross-user with multiuser flag works
- [ ] Messages appear in real-time
- [ ] Replies display correctly (not concatenated)
- [ ] `/list` shows online users
- [ ] Can send multiline messages
- [ ] Ctrl+C cleanly exits

## Examples

### Example 1: User ↔ User (Same Machine)

**Terminal 1:**
```bash
ruby chat_demo.rb
# Creates socket: /tmp/rubian_chat/katcv.sock
```

**Terminal 2:**
```bash
USER=alice ruby chat_demo.rb
# Creates socket: /tmp/rubian_chat/alice.sock
```

Chat between `katcv` and `alice`.

### Example 2: User ↔ Root

**Terminal 1 (katcv):**
```bash
CHAT_MULTIUSER=1 ruby chat_demo.rb
```

**Terminal 2 (root):**
```bash
sudo su
cd /home/katcv/jrubytest/jruby-jep380-prototype
CHAT_MULTIUSER=1 ruby chat_demo.rb
```

Chat between `katcv` and `root`.

### Example 3: MRI ↔ JRuby

**Terminal 1 (MRI):**
```bash
ruby chat_demo.rb
```

**Terminal 2 (JRuby):**
```bash
USER=juser jruby chat_demo.rb
```

Chat between `katcv` (MRI) and `juser` (JRuby).

## Advanced: Multiple Users

You can have many users online at once:

**Terminal 1:**
```bash
CHAT_MULTIUSER=1 ruby chat_demo.rb
```

**Terminal 2:**
```bash
USER=alice CHAT_MULTIUSER=1 ruby chat_demo.rb
```

**Terminal 3:**
```bash
USER=bob CHAT_MULTIUSER=1 ruby chat_demo.rb
```

**Terminal 4:**
```bash
sudo CHAT_MULTIUSER=1 ruby chat_demo.rb
```

Now `/list` shows: `alice, bob, root` and you can message any of them!

---

**All issues fixed! Chat now supports:**
- ✓ Real-time message delivery
- ✓ Proper cross-user permissions
- ✓ Clean reply display
- ✓ Robust input handling
- ✓ Works with MRI Ruby and JRuby

#!/bin/bash
# Launch the HTTP chat server

cd "$(dirname "$0")"

# Kill any existing instance
PATTERN="[c]hat-server.py"
p=$(ps -eaf | grep "$PATTERN" | grep -v grep)
if [ -n "$p" ]; then
    pid=$(echo "$p" | awk '{print $2}')
    echo "Killing existing chat-server.py (PID $pid)"
    kill $pid
    sleep 1
fi

echo "Starting chat server..."
python3 chat-server.py &
echo "Chat server started (PID $!)"

#!/bin/bash
# Launch chat server, killing any existing instance first.
# Reads the project ID from chat-config.json to build a unique script name.
# Always downloads the latest server script from the repo.

ID=$(python3 -c "import json; print(json.load(open('chat-config.json'))['id'])")
SCRIPT="${ID}-chat-server"

# Kill any existing instance
PATTERN="[${SCRIPT:0:1}]${SCRIPT:1}"
p=$(ps -eaf | grep "$PATTERN")
if [ -n "$p" ]; then
    pid=$(echo "$p" | awk '{print $2}')
    echo "Killing existing $SCRIPT (PID $pid)"
    kill $pid
    sleep 1
fi

# Download latest from repo
echo "Downloading latest $SCRIPT.ecs from repo..."
curl -sO https://raw.githubusercontent.com/easycoder/chat/main/chat-server.ecs
mv chat-server.ecs "$SCRIPT.ecs"

echo "Starting $SCRIPT..."
easycoder "$SCRIPT.ecs" &
echo "$SCRIPT started (PID $!)"

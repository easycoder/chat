#!/bin/bash
# Deploy AllSpeak chat to Hetzner server
# Shared files come from the chat project; instance config is local.

SERVER="root@89.167.127.185"
REMOTE_DIR="/root/allspeak"
LOCAL_DIR="$(dirname "$0")"
CHAT_DIR="$(dirname "$0")/.."

echo "=== Deploying AllSpeak Chat to $SERVER ==="

# Ensure dependencies
ssh $SERVER "pip3 install bottle --break-system-packages 2>/dev/null || pip3 install bottle" 2>/dev/null

# Create remote directory
echo "Creating remote directory..."
ssh $SERVER "mkdir -p $REMOTE_DIR/chat-data/topics"

# Copy shared files from chat project
echo "Copying shared files..."
scp "$CHAT_DIR/chat-server.py" \
    "$CHAT_DIR/chat-main.as" \
    "$CHAT_DIR/chat.json" \
    "$CHAT_DIR/index.html" \
    "$SERVER:$REMOTE_DIR/"

# Copy instance-specific files
echo "Copying instance config..."
scp "$LOCAL_DIR/chat-config.json" \
    "$LOCAL_DIR/chat-users.json" \
    "$LOCAL_DIR/credentials.json" \
    "$SERVER:$REMOTE_DIR/"

# Install systemd service
echo "Installing systemd service..."
scp "$LOCAL_DIR/allspeak-chat.service" "$SERVER:/etc/systemd/system/"
ssh $SERVER "systemctl daemon-reload && systemctl enable allspeak-chat && systemctl restart allspeak-chat"

# Check status
echo ""
echo "=== Service status ==="
ssh $SERVER "systemctl status allspeak-chat --no-pager -l"

echo ""
echo "=== Done ==="
echo "Chat should be available at: http://89.167.127.185:8080/allspeak/"

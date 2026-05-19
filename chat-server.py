#!/usr/bin/env python3
"""Chat server using Bottle — HTTP replacement for MQTT-based chat-server.as"""

import json
import os
import sys
import time
import hashlib
import smtplib
from email.mime.text import MIMEText
from bottle import Bottle, request, response, static_file, run

# Load config
with open('chat-config.json') as f:
    config = json.load(f)

INSTANCE_ID = config['id']
TITLE = config.get('title', 'Chat')
PORT = config.get('port', 8080)
DATA_DIR = 'chat-data'

# Load credentials
if os.path.exists('credentials.json'):
    with open('credentials.json') as f:
        creds = json.load(f)
else:
    print('No credentials.json found')
    sys.exit(1)

MAIL_SERVER = creds.get('mail_server', '')
MAIL_LOGIN = creds.get('mail_login', '')
MAIL_PASSWORD = creds.get('mail_password', '')
MAIL_FROM = creds.get('mail_from', '')

# Load users
USERS_FILE = 'chat-users.json'
if os.path.exists(USERS_FILE):
    with open(USERS_FILE) as f:
        users = json.load(f)
else:
    users = {}

# Ensure data directories
os.makedirs(f'{DATA_DIR}/topics', exist_ok=True)

app = Bottle()
prefix = f'/{INSTANCE_ID}'


def save_users():
    with open(USERS_FILE, 'w') as f:
        json.dump(users, f)


def hash_password(pw):
    return hashlib.sha256(pw.encode()).hexdigest()


def get_json_body():
    """Parse JSON from request body, handling both application/json and text bodies."""
    try:
        return request.json
    except Exception:
        pass
    try:
        return json.loads(request.body.read().decode('utf-8'))
    except Exception:
        return {}


def json_response(data):
    response.content_type = 'application/json'
    return json.dumps(data)


# ---- API routes ----

@app.route(f'{prefix}/api/ping')
def ping():
    return json_response({'status': 'ok', 'message': 'pong'})


@app.route(f'{prefix}/api/register', method='POST')
def register():
    data = get_json_body()
    username = data.get('username', '')
    password = data.get('password', '')
    hashed = hash_password(password)
    if username in users:
        if users[username] == hashed:
            return json_response({'status': 'ok', 'username': username})
        else:
            return json_response({'status': 'error', 'message': 'Username already taken'})
    users[username] = hashed
    save_users()
    print(f'Registered: {username}')
    return json_response({'status': 'ok', 'username': username})


@app.route(f'{prefix}/api/login', method='POST')
def login():
    data = get_json_body()
    username = data.get('username', '')
    password = data.get('password', '')
    hashed = hash_password(password)
    if username not in users:
        return json_response({'status': 'error', 'message': 'Unknown username'})
    if users[username] != hashed:
        return json_response({'status': 'error', 'message': 'Incorrect password'})
    print(f'Login OK: {username}')
    return json_response({'status': 'ok', 'username': username})


@app.route(f'{prefix}/api/topics')
def get_topics():
    topics_file = f'{DATA_DIR}/topics.json'
    if os.path.exists(topics_file):
        with open(topics_file) as f:
            return json_response(json.load(f))
    return json_response([])


@app.route(f'{prefix}/api/topic', method='POST')
def new_topic():
    data = get_json_body()
    name = data.get('name', '')
    desc = data.get('description', '')
    creator = data.get('creator', '')
    topic_path = f'{DATA_DIR}/topics/{name}'
    if os.path.exists(topic_path):
        return json_response({'status': 'error', 'message': 'Topic already exists'})
    os.makedirs(f'{topic_path}/posts', exist_ok=True)
    meta = {'name': name, 'description': desc, 'creator': creator}
    with open(f'{topic_path}/topic.json', 'w') as f:
        json.dump(meta, f)
    # Update topic index
    topics_file = f'{DATA_DIR}/topics.json'
    if os.path.exists(topics_file):
        with open(topics_file) as f:
            topics = json.load(f)
    else:
        topics = []
    topics.append({'name': name, 'description': desc})
    with open(topics_file, 'w') as f:
        json.dump(topics, f)
    print(f'Created topic: {name}')
    return json_response({'status': 'ok', 'name': name})


@app.route(f'{prefix}/api/posts/<topic>')
def get_posts(topic):
    posts_file = f'{DATA_DIR}/topics/{topic}/posts.json'
    if os.path.exists(posts_file):
        with open(posts_file) as f:
            return json_response(json.load(f))
    return json_response([])


@app.route(f'{prefix}/api/post', method='POST')
def new_post():
    data = get_json_body()
    topic = data.get('topic', '')
    subject = data.get('subject', '')
    author = data.get('author', '')
    body = data.get('body', '')
    topic_path = f'{DATA_DIR}/topics/{topic}'
    if not os.path.exists(topic_path):
        return json_response({'status': 'error', 'message': 'Topic not found'})
    import base64
    subject_b64 = base64.b64encode(subject.encode()).decode()
    body_b64 = base64.b64encode(body.encode()).decode()
    post_id = str(int(time.time() * 1000))
    post_dir = f'{topic_path}/posts/{post_id}'
    os.makedirs(post_dir, exist_ok=True)
    post_meta = {
        'id': post_id,
        'subject': subject_b64,
        'author': author,
        'body': body_b64
    }
    with open(f'{post_dir}/post.json', 'w') as f:
        json.dump(post_meta, f)
    # Update posts index
    posts_file = f'{topic_path}/posts.json'
    if os.path.exists(posts_file):
        with open(posts_file) as f:
            posts = json.load(f)
    else:
        posts = []
    posts.append({'id': post_id, 'subject': subject_b64, 'author': author})
    with open(posts_file, 'w') as f:
        json.dump(posts, f)
    print(f'Created post {post_id} in {topic}')
    return json_response({'status': 'ok', 'id': post_id})


@app.route(f'{prefix}/api/view/<topic>/<post_id>')
def view_post(topic, post_id):
    post_file = f'{DATA_DIR}/topics/{topic}/posts/{post_id}/post.json'
    if not os.path.exists(post_file):
        return json_response({'status': 'error', 'message': 'Post not found'})
    with open(post_file) as f:
        post = json.load(f)
    replies_file = f'{DATA_DIR}/topics/{topic}/posts/{post_id}/replies.json'
    if os.path.exists(replies_file):
        with open(replies_file) as f:
            replies = json.load(f)
    else:
        replies = []
    return json_response({'post': post, 'replies': replies})


@app.route(f'{prefix}/api/edit-post', method='POST')
def edit_post():
    data = get_json_body()
    topic = data.get('topic', '')
    post_id = data.get('id', '')
    author = data.get('author', '')
    subject = data.get('subject', '')
    body = data.get('body', '')
    post_dir = f'{DATA_DIR}/topics/{topic}/posts/{post_id}'
    if not os.path.exists(post_dir):
        return json_response({'status': 'error', 'message': 'Post not found'})
    post_file = f'{post_dir}/post.json'
    with open(post_file) as f:
        post = json.load(f)
    if post.get('author') != author:
        return json_response({'status': 'error', 'message': 'You can only edit your own posts'})
    import base64
    subject_b64 = base64.b64encode(subject.encode()).decode()
    body_b64 = base64.b64encode(body.encode()).decode()
    post['subject'] = subject_b64
    post['body'] = body_b64
    with open(post_file, 'w') as f:
        json.dump(post, f)
    # Update posts index
    posts_file = f'{DATA_DIR}/topics/{topic}/posts.json'
    if os.path.exists(posts_file):
        with open(posts_file) as f:
            posts = json.load(f)
        for p in posts:
            if p.get('id') == post_id:
                p['subject'] = subject_b64
                break
        with open(posts_file, 'w') as f:
            json.dump(posts, f)
    print(f'Edited post {post_id} in {topic}')
    return json_response({'status': 'ok', 'id': post_id})


@app.route(f'{prefix}/api/delete-post', method='POST')
def delete_post():
    data = get_json_body()
    topic = data.get('topic', '')
    post_id = data.get('id', '')
    author = data.get('author', '')
    post_dir = f'{DATA_DIR}/topics/{topic}/posts/{post_id}'
    if not os.path.exists(post_dir):
        return json_response({'status': 'error', 'message': 'Post not found'})
    post_file = f'{post_dir}/post.json'
    with open(post_file) as f:
        post = json.load(f)
    if post.get('author') != author:
        return json_response({'status': 'error', 'message': 'You can only delete your own posts'})
    import shutil
    shutil.rmtree(post_dir)
    # Update posts index
    posts_file = f'{DATA_DIR}/topics/{topic}/posts.json'
    if os.path.exists(posts_file):
        with open(posts_file) as f:
            posts = json.load(f)
        posts = [p for p in posts if p.get('id') != post_id]
        with open(posts_file, 'w') as f:
            json.dump(posts, f)
    print(f'Deleted post {post_id} in {topic}')
    return json_response({'status': 'ok', 'id': post_id})


@app.route(f'{prefix}/api/reply', method='POST')
def new_reply():
    data = get_json_body()
    topic = data.get('topic', '')
    post_id = data.get('postId', '')
    depth = data.get('depth', 0)
    author = data.get('author', '')
    body = data.get('body', '')
    parent_path = f'{DATA_DIR}/topics/{topic}/posts/{post_id}'
    if not os.path.exists(parent_path):
        return json_response({'status': 'error', 'message': 'Parent post not found'})
    if depth >= 3:
        return json_response({'status': 'error', 'message': 'Maximum reply depth reached'})
    import base64
    body_b64 = base64.b64encode(body.encode()).decode()
    reply_id = str(int(time.time() * 1000))
    reply_dir = f'{parent_path}/replies/{reply_id}'
    os.makedirs(reply_dir, exist_ok=True)
    new_depth = depth + 1
    reply_meta = {
        'id': reply_id,
        'subject': 'Re',
        'author': author,
        'body': body_b64,
        'depth': new_depth
    }
    with open(f'{reply_dir}/post.json', 'w') as f:
        json.dump(reply_meta, f)
    # Update replies index
    replies_file = f'{parent_path}/replies.json'
    if os.path.exists(replies_file):
        with open(replies_file) as f:
            replies = json.load(f)
    else:
        replies = []
    preview = body_b64[:50]
    replies.append({
        'id': reply_id,
        'author': author,
        'preview': preview,
        'depth': new_depth
    })
    with open(replies_file, 'w') as f:
        json.dump(replies, f)
    print(f'Created reply {reply_id}')
    return json_response({'status': 'ok', 'id': reply_id})


@app.route(f'{prefix}/api/delete-reply', method='POST')
def delete_reply():
    data = get_json_body()
    topic = data.get('topic', '')
    post_id = data.get('postId', '')
    reply_id = data.get('replyId', '')
    author = data.get('author', '')
    reply_dir = f'{DATA_DIR}/topics/{topic}/posts/{post_id}/replies/{reply_id}'
    if not os.path.exists(reply_dir):
        return json_response({'status': 'error', 'message': 'Reply not found'})
    reply_file = f'{reply_dir}/post.json'
    with open(reply_file) as f:
        reply = json.load(f)
    # Allow reply author or post owner to delete
    if reply.get('author') != author:
        post_file = f'{DATA_DIR}/topics/{topic}/posts/{post_id}/post.json'
        with open(post_file) as f:
            post = json.load(f)
        if post.get('author') != author:
            return json_response({'status': 'error', 'message': 'You can only delete your own replies'})
    import shutil
    shutil.rmtree(reply_dir)
    # Update replies index
    replies_file = f'{DATA_DIR}/topics/{topic}/posts/{post_id}/replies.json'
    if os.path.exists(replies_file):
        with open(replies_file) as f:
            replies = json.load(f)
        replies = [r for r in replies if r.get('id') != reply_id]
        with open(replies_file, 'w') as f:
            json.dump(replies, f)
    print(f'Deleted reply {reply_id}')
    return json_response({'status': 'ok', 'id': reply_id})


@app.route(f'{prefix}/api/email', method='POST')
def send_email():
    data = get_json_body()
    to = data.get('to', '')
    subject = data.get('subject', '')
    body = data.get('body', '')
    try:
        msg = MIMEText(body)
        msg['From'] = MAIL_FROM
        msg['To'] = to
        msg['Subject'] = subject
        with smtplib.SMTP(MAIL_SERVER) as server:
            server.starttls()
            server.login(MAIL_LOGIN, MAIL_PASSWORD)
            server.sendmail(MAIL_FROM, [to], msg.as_string())
        print(f'Sent email to {to}')
        return json_response({'status': 'ok', 'message': 'sent'})
    except Exception as e:
        print(f'Failed to send email to {to}: {e}')
        return json_response({'status': 'error', 'message': 'Failed to send email'})


# ---- Static files (must be after API routes) ----

@app.route(f'{prefix}/')
@app.route(f'{prefix}/index.html')
def serve_index():
    return static_file('index.html', root='.')


@app.route(f'{prefix}/<filepath:path>')
def serve_static(filepath):
    return static_file(filepath, root='.')


if __name__ == '__main__':
    print(f'Chat server starting on port {PORT}...')
    print(f'Instance: {INSTANCE_ID}')
    print(f'URL: http://localhost:{PORT}{prefix}/')
    run(app, host='0.0.0.0', port=PORT, quiet=False)

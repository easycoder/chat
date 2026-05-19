!   chat-main.as - Chat client (HTTP version)

    script Chat

!! Declarations: DOM element handles, then working variables.
!!
!! AllSpeak requires every name to be declared before use. The first group declares handles for the DOM elements the script attaches to after rendering; each name mirrors an @id in chat.json. The second group declares scratch variables for state and string-building shared across the event handlers below.
!!
!! ReplyDeleteIds is a pipe-delimited string of reply IDs, indexed by the order of the delete-reply buttons rendered into RepliesMarkup. DoDeleteReply walks that string to find the ID for the clicked button — needed because the delete buttons are an array-of-elements (ReplyDeleteBtn) whose entries don't carry the underlying reply ID directly.

    div Body
    variable Layout

    h2 Title
    div Status
    div LoginPanel
    input UsernameInput
    input PasswordInput
    button LoginButton
    button ShowRegisterLink
    div LoginMessage
    div RegisterPanel
    input RegUsernameInput
    input RegPasswordInput
    button RegisterButton
    button ShowLoginLink
    div RegisterMessage
    div ChatPanel
    div TopicBarTitle
    button NewTopicToggle
    div TopicListPanel
    div NewTopicPanel
    input NewTopicName
    input NewTopicDesc
    button CreateTopicButton
    button CancelTopicButton
    div NewTopicMessage
    div PostsPanel
    button NewPostToggle
    div PostListPanel
    div NewPostPanel
    input NewPostSubject
    textarea NewPostBody
    button SubmitPostButton
    button CancelPostButton
    div NewPostMessage
    button TopicItem
    button PostItem
    div PostViewPanel
    span BackToPostsLink
    span ReplyToggle
    span EditPostLink
    span DeletePostLink
    div PostViewSubject
    div PostViewAuthor
    div PostViewBody
    div EditPostPanel
    input EditPostSubject
    textarea EditPostBody
    button SaveEditButton
    button CancelEditButton
    div EditPostMessage
    div PostRepliesPanel
    div ReplyPanel
    textarea ReplyBodyInput
    button SubmitReplyButton
    button CancelReplyButton
    div ReplyMessage
    button ReplyDeleteBtn

    variable TitleText
    variable ApiBase
    variable Request
    variable Response
    variable ChatUsername
    variable ChatPassword
    variable Pos
    variable ReplyStatus
    variable ReplyBody
    variable TopicsJson
    variable TopicMarkup
    variable N
    variable Count
    variable TName
    variable TDesc
    variable TEntry
    variable CurrentTopic
    variable PostsJson
    variable PostMarkup
    variable PSubject
    variable PAuthor
    variable PEntry
    variable PBody
    variable CurrentPostId
    variable PostData
    variable PostObj
    variable RepliesJson
    variable RepliesMarkup
    variable REntry
    variable RAuthor
    variable RPreview
    variable CurrentDepth
    variable RId
    variable ReplyDeleteCount
    variable ReplyDeleteIds
    variable PTimestamp
    variable PDate
    variable PTime
    variable PDPart
!!!

!! Load instance config, build the API base, and restore any saved login from browser storage.
!!
!! chat-config.json supplies the per-instance page title. ApiBase is the relative string `api`; the live URL is `/<instance-id>/api/...` but the prefix is invisible from the client because index.html and chat-main.as are served from the same prefix by the server.
!!
!! The `null`/`undefined` checks normalise empty storage across browsers — a key that was never set can come back as the literal string `null` rather than empty, which would otherwise look like a non-empty username and trigger a doomed auto-login.

    rest get Response from `chat-config.json`
    or begin
        alert `Could not load chat-config.json`
        stop
    end
    put element `title` of Response into TitleText
    put `api` into ApiBase
    log `API base: ` cat ApiBase

    get ChatUsername from storage as `chat-user`
    if ChatUsername is `null` put empty into ChatUsername
    if ChatUsername is `undefined` put empty into ChatUsername
    get ChatPassword from storage as `chat-pass`
    if ChatPassword is `null` put empty into ChatPassword
    if ChatPassword is `undefined` put empty into ChatPassword
!!!

!! Fetch the Webson layout, render it into the body, then connect every declared handle to its @id in the DOM.
!!
!! `render` walks the JSON tree and creates real HTML. `attach` binds a declared AllSpeak name to the DOM element with the given @id, so subsequent `set the content of`, `set style`, and `on click` operations target that element.

    rest get Layout from `chat.json`
    or begin
        alert `Could not load chat.json`
        stop
    end

    create Body
    render Layout in Body

    attach Status to `status`
    attach Title to `title`
    attach LoginPanel to `login-panel`
    attach UsernameInput to `username-input`
    attach PasswordInput to `password-input`
    attach LoginButton to `login-button`
    attach ShowRegisterLink to `show-register-link`
    attach LoginMessage to `login-message`
    attach RegisterPanel to `register-panel`
    attach RegUsernameInput to `reg-username-input`
    attach RegPasswordInput to `reg-password-input`
    attach RegisterButton to `register-button`
    attach ShowLoginLink to `show-login-link`
    attach RegisterMessage to `register-message`
    attach ChatPanel to `chat-panel`
    attach TopicBarTitle to `topic-bar-title`
    attach NewTopicToggle to `new-topic-toggle`
    attach TopicListPanel to `topic-list-panel`
    attach NewTopicPanel to `new-topic-panel`
    attach NewTopicName to `new-topic-name`
    attach NewTopicDesc to `new-topic-desc`
    attach CreateTopicButton to `create-topic-button`
    attach CancelTopicButton to `cancel-topic-button`
    attach NewTopicMessage to `new-topic-message`
    attach PostsPanel to `posts-panel`
    attach NewPostToggle to `new-post-toggle`
    attach PostListPanel to `post-list-panel`
    attach NewPostPanel to `new-post-panel`
    attach NewPostSubject to `new-post-subject`
    attach NewPostBody to `new-post-body`
    attach SubmitPostButton to `submit-post-button`
    attach CancelPostButton to `cancel-post-button`
    attach NewPostMessage to `new-post-message`
    attach PostViewPanel to `post-view-panel`
    attach BackToPostsLink to `back-to-posts`
    attach ReplyToggle to `reply-toggle`
    attach EditPostLink to `edit-post-link`
    attach DeletePostLink to `delete-post-link`
    attach PostViewSubject to `post-view-subject`
    attach PostViewAuthor to `post-view-author`
    attach PostViewBody to `post-view-body`
    attach EditPostPanel to `edit-post-panel`
    attach EditPostSubject to `edit-post-subject`
    attach EditPostBody to `edit-post-body`
    attach SaveEditButton to `save-edit-button`
    attach CancelEditButton to `cancel-edit-button`
    attach EditPostMessage to `edit-post-message`
    attach PostRepliesPanel to `post-replies-panel`
    attach ReplyPanel to `reply-panel`
    attach ReplyBodyInput to `reply-body`
    attach SubmitReplyButton to `submit-reply-button`
    attach CancelReplyButton to `cancel-reply-button`
    attach ReplyMessage to `reply-message`

    set the content of Title to TitleText
!!!

!! Verify the server responds, then branch to auto-login or the login form.
!!
!! /ping returns {status: ok}. If the rest call fails or returns a non-ok status, show a red "not responding" message and stop — no point exposing login if the backend is unreachable. On success show green "Connected", then jump to AutoLogin (if storage had credentials) or ShowLogin.

    set the content of Status to `Checking server...`
    set style `color` of Status to `#880`
    rest get Response from ApiBase cat `/ping`
    or begin
        set the content of Status to `Chat server not responding.`
        set style `color` of Status to `#800`
        stop
    end
    put element `status` of Response into ReplyStatus
    if ReplyStatus is not `ok`
    begin
        set the content of Status to `Chat server not responding.`
        set style `color` of Status to `#800`
        stop
    end
    set the content of Status to `Connected to chat server.`
    set style `color` of Status to `#080`
    if ChatUsername is not empty go to AutoLogin
    go to ShowLogin
!!!

!! Try login with saved credentials and enter the chat on success.
!!
!! On any failure (server error, bad credentials, no reply) fall through silently to ShowLogin — the user didn't explicitly request a login this session, so no error message, just present the form. On success the credentials are re-stored (the username in particular, in case the server canonicalised it).

AutoLogin:
    set the content of Status to `Logging in as ` cat ChatUsername cat `...`
    put `{"username":"` cat ChatUsername cat `","password":"` cat ChatPassword cat `"}` into Request
    rest post Request to ApiBase cat `/login` giving Response
    or go to ShowLogin
    put element `status` of Response into ReplyStatus
    if ReplyStatus is `ok`
    begin
        put element `username` of Response into ChatUsername
        put ChatUsername into storage as `chat-user`
        put ChatPassword into storage as `chat-pass`
        go to EnterChat
    end
    go to ShowLogin
!!!

!! Show the login form and wire its handlers.
!!
!! Pre-fills the inputs from any restored credentials, disables the submit button until both fields are filled, and binds keystrokes to re-check the fields. `stop` parks the script — control resumes via the click/key handlers, not by falling through.

ShowLogin:
    set the text of UsernameInput to ChatUsername
    set the text of PasswordInput to ChatPassword
    set the content of LoginMessage to ``
    set style `display` of LoginPanel to `flex`
    set style `display` of RegisterPanel to `none`
    disable LoginButton
    gosub CheckLoginFields
    on click LoginButton go to DoLogin
    on click ShowRegisterLink go to ShowRegister
    on key gosub CheckLoginFields
    stop
!!!

!! Show the register form and wire its handlers.
!!
!! Symmetric counterpart to ShowLogin: disable submit until both fields are filled, bind keystrokes to re-validate, then stop and wait.

ShowRegister:
    set the content of RegisterMessage to ``
    set style `display` of LoginPanel to `none`
    set style `display` of RegisterPanel to `flex`
    disable RegisterButton
    gosub CheckRegisterFields
    on click RegisterButton go to DoRegister
    on click ShowLoginLink go to ShowLogin
    on key gosub CheckRegisterFields
    stop
!!!

!! Submit the login form, store credentials on success, clear them on failure.
!!
!! Success: stash username and password in browser storage so AutoLogin works next session, then jump to EnterChat. Failure is destructive: ChatUsername, ChatPassword, and both storage entries are wiped, so a wrong password doesn't linger and re-fire AutoLogin on reload. CheckLoginFields re-runs after a failed attempt so the button re-enables once the user edits a field.

DoLogin:
    put the text of UsernameInput into ChatUsername
    put the text of PasswordInput into ChatPassword
    disable LoginButton
    set the content of LoginMessage to `Logging in...`
    set style `color` of LoginMessage to `#888`
    put `{"username":"` cat ChatUsername cat `","password":"` cat ChatPassword cat `"}` into Request
    rest post Request to ApiBase cat `/login` giving Response
    or begin
        gosub CheckLoginFields
        set the content of LoginMessage to `No reply from server`
        set style `color` of LoginMessage to `#800`
        stop
    end
    put element `status` of Response into ReplyStatus
    if ReplyStatus is `ok`
    begin
        put element `username` of Response into ChatUsername
        put ChatUsername into storage as `chat-user`
        put ChatPassword into storage as `chat-pass`
        go to EnterChat
    end
    gosub CheckLoginFields
    put element `message` of Response into ReplyBody
    set the content of LoginMessage to ReplyBody
    set style `color` of LoginMessage to `#800`
    put empty into ChatUsername
    put empty into ChatPassword
    put empty into storage as `chat-user`
    put empty into storage as `chat-pass`
    stop
!!!

!! Submit the register form; on success treat the new user as logged in.
!!
!! The server's /register accepts a brand-new username, or treats a resubmission of an existing username + matching password as a successful login (idempotent registration). On failure, clear the in-memory credentials but leave any existing browser storage alone — registration shouldn't displace a saved session that already works.

DoRegister:
    put the text of RegUsernameInput into ChatUsername
    put the text of RegPasswordInput into ChatPassword
    disable RegisterButton
    set the content of RegisterMessage to `Registering...`
    set style `color` of RegisterMessage to `#888`
    put `{"username":"` cat ChatUsername cat `","password":"` cat ChatPassword cat `"}` into Request
    rest post Request to ApiBase cat `/register` giving Response
    or begin
        gosub CheckRegisterFields
        set the content of RegisterMessage to `No reply from server`
        set style `color` of RegisterMessage to `#800`
        stop
    end
    put element `status` of Response into ReplyStatus
    if ReplyStatus is `ok`
    begin
        put element `username` of Response into ChatUsername
        put ChatUsername into storage as `chat-user`
        put ChatPassword into storage as `chat-pass`
        go to EnterChat
    end
    gosub CheckRegisterFields
    put element `message` of Response into ReplyBody
    set the content of RegisterMessage to ReplyBody
    set style `color` of RegisterMessage to `#800`
    put empty into ChatUsername
    put empty into ChatPassword
    stop
!!!

!! Land on the chat screen after login and wire every navigation handler.
!!
!! Every on-click binding for the main chat is established here once. The user never leaves this screen during a session — the navigation gosubs just show and hide panels within it. LoadTopics fires immediately so the topic list is populated before the user sees the screen. `stop` parks the script; from here on, control flows through the handlers.

EnterChat:
    set the content of Status to `Logged in as ` cat ChatUsername
    set style `display` of LoginPanel to `none`
    set style `display` of RegisterPanel to `none`
    set style `display` of ChatPanel to `flex`
    on click NewTopicToggle gosub HandleTopicToggle
    gosub LoadTopics
    on click CreateTopicButton gosub CreateTopic
    on click CancelTopicButton gosub HideNewTopic
    on click NewPostToggle gosub ToggleNewPost
    on click SubmitPostButton gosub SubmitPost
    on click CancelPostButton gosub HideNewPost
    on click BackToPostsLink gosub BackToPosts
    on click EditPostLink gosub EditPost
    on click SaveEditButton gosub SaveEdit
    on click CancelEditButton gosub CancelEdit
    on click DeletePostLink gosub DeletePost
    on click ReplyToggle gosub ToggleReply
    on click SubmitReplyButton gosub SubmitReply
    on click CancelReplyButton gosub HideReply
    stop
!!!

!! Fetch the topic list from the server and hand it to RenderTopics.
!!
!! Called at chat entry and after any topic-list change (create, back-to-topics). Shows a transient "Loading..." while the request is in flight; on failure leaves a "No reply from server" message in place.

LoadTopics:
    set the content of TopicListPanel to `Loading topics...`
    rest get TopicsJson from ApiBase cat `/topics`
    or begin
        set the content of TopicListPanel to `No reply from server`
        return
    end
    gosub RenderTopics
    return
!!!

!! Render the fetched topic list into TopicListPanel as a column of clickable buttons.
!!
!! Builds the HTML markup string in a loop, then injects it. After insertion, walks the same range again to attach each `TopicItem-N` element into the TopicItem array-of-elements, so a single `on click TopicItem` handler covers them all and discovers which one fired via `the index of TopicItem`. An empty topic list short-circuits to an instructional message.

RenderTopics:
    put the json count of TopicsJson into Count
    if Count is 0
    begin
        set the content of TopicListPanel to `No topics yet. Click 'New Topic' to create one.`
        return
    end
    put `` into TopicMarkup
    put 0 into N
    while N is less than Count
    begin
        put element N of TopicsJson into TEntry
        put element `name` of TEntry into TName
        put element `description` of TEntry into TDesc
        if TDesc is empty put `(no description)` into TDesc
        put TopicMarkup cat `<button id="TopicItem-` cat N
            cat `" style="display:block;width:100%;text-align:left;padding:0.4em;margin-bottom:0.3em;cursor:pointer">`
            cat `<strong>` cat TName cat `</strong> &mdash; ` cat TDesc
            cat `</button>` into TopicMarkup
        add 1 to N
    end
    set the content of TopicListPanel to TopicMarkup
    set the elements of TopicItem to Count
    put 0 into N
    while N is less than Count
    begin
        index TopicItem to N
        attach TopicItem to `TopicItem-` cat N
        add 1 to N
    end
    on click TopicItem go to TopicClick
    return
!!!

!! Handle a click on a topic button and switch to its posts view.
!!
!! `the index of TopicItem` reports which button in the array fired. Look that index up in TopicsJson to recover the topic name, then dispatch to ShowPosts. `stop` ends this event thread; ShowPosts will park its own.

TopicClick:
    put the index of TopicItem into N
    put element N of TopicsJson into TEntry
    put element `name` of TEntry into CurrentTopic
    gosub ShowPosts
    stop
!!!

!! Topic-bar button handler: doubles as "New Topic" and "Topics" depending on context.
!!
!! When viewing posts within a topic (CurrentTopic set), the button is labelled "Topics" and goes back to the topic list. When on the topic list, it opens the new-topic form. The label-flipping happens in ShowPosts and BackToTopics; this gosub just dispatches on the current state.

HandleTopicToggle:
    if CurrentTopic is not empty gosub BackToTopics
    else set style `display` of NewTopicPanel to `flex`
    return
!!!

!! Close the new-topic panel and clear any previous error message.

HideNewTopic:
    set style `display` of NewTopicPanel to `none`
    set the content of NewTopicMessage to ``
    return
!!!

!! Submit the new-topic form, reload the topic list on success.
!!
!! Validates locally that name and description are both non-empty (the server would reject empty too, but a client check spares a round-trip). On success, clear the form inputs, close the panel, and re-fetch the topic list so the new entry appears.

CreateTopic:
    put the text of NewTopicName into TName
    if TName is empty
    begin
        set the content of NewTopicMessage to `Please enter a topic name`
        set style `color` of NewTopicMessage to `#800`
        return
    end
    put the text of NewTopicDesc into TDesc
    if TDesc is empty
    begin
        set the content of NewTopicMessage to `Please enter a description`
        set style `color` of NewTopicMessage to `#800`
        return
    end
    set the content of NewTopicMessage to `Creating topic...`
    set style `color` of NewTopicMessage to `#888`
    put `{"name":"` cat TName cat `","description":"` cat TDesc cat `","creator":"` cat ChatUsername cat `"}` into Request
    rest post Request to ApiBase cat `/topic` giving Response
    or begin
        set the content of NewTopicMessage to `No reply from server`
        set style `color` of NewTopicMessage to `#800`
        return
    end
    put element `status` of Response into ReplyStatus
    if ReplyStatus is `ok`
    begin
        gosub HideNewTopic
        set the content of NewTopicName to ``
        set the content of NewTopicDesc to ``
        gosub LoadTopics
    end
    else
    begin
        put element `message` of Response into ReplyBody
        set the content of NewTopicMessage to ReplyBody
        set style `color` of NewTopicMessage to `#800`
    end
    return
!!!

!! Switch to the posts pane for CurrentTopic and fetch its posts.
!!
!! Sets the topic-bar title to the current topic, flips the toggle button label to "Topics", hides the topic list and new-topic panel, exposes the posts panel and its "New Post" toggle, then issues the /posts/<topic> request and renders the result.

ShowPosts:
    set the content of TopicBarTitle to `Topic: ` cat CurrentTopic
    set the content of NewTopicToggle to `Topics`
    set style `display` of NewPostToggle to `inline-block`
    set style `display` of TopicListPanel to `none`
    set style `display` of NewTopicPanel to `none`
    set style `display` of PostsPanel to `flex`
    set the content of PostListPanel to `Loading posts...`
    rest get PostsJson from ApiBase cat `/posts/` cat CurrentTopic
    or begin
        set the content of PostListPanel to `No reply from server`
        return
    end
    gosub RenderPosts
    return
!!!

!! Render the fetched posts list into PostListPanel, decoding the base64 subjects for display.
!!
!! Same pattern as RenderTopics: build markup in a loop, insert it, then walk the range again to attach each `PostItem-N` element into the PostItem array. Subjects and bodies are stored base64-encoded server-side so newlines and quotes survive the JSON round-trip without escape gymnastics; this loop decodes the subject for display. An empty post list shows a "no posts" placeholder.

RenderPosts:
    put the json count of PostsJson into Count
    if Count is 0
    begin
        set the content of PostListPanel to `No posts yet. Click 'New Post' to start a discussion.`
        return
    end
    put `` into PostMarkup
    put 0 into N
    while N is less than Count
    begin
        put element N of PostsJson into PEntry
        put element `subject` of PEntry into PSubject
        set encoding to `base64`
        decode PSubject
        put element `author` of PEntry into PAuthor
        put PostMarkup cat `<button id="PostItem-` cat N
            cat `" style="display:block;width:100%;text-align:left;padding:0.4em;margin-bottom:0.3em;cursor:pointer">`
            cat `<strong>` cat PSubject cat `</strong> &mdash; ` cat PAuthor
            cat `</button>` into PostMarkup
        add 1 to N
    end
    set the content of PostListPanel to PostMarkup
    set the elements of PostItem to Count
    put 0 into N
    while N is less than Count
    begin
        index PostItem to N
        attach PostItem to `PostItem-` cat N
        add 1 to N
    end
    on click PostItem go to PostClick
    return
!!!

!! Handle a click on a post button and open its detail view.
!!
!! CurrentDepth is reset to 0 — this is the root post, so any reply made from here will be depth 1.

PostClick:
    put the index of PostItem into N
    put element N of PostsJson into PEntry
    put element `id` of PEntry into CurrentPostId
    put 0 into CurrentDepth
    gosub ViewPost
    stop
!!!

!! Show the detail view for CurrentPostId: subject, author, formatted timestamp, body, and replies.
!!
!! Resets all per-view UI state (hides edit panel, blanks contents to "Loading...", hides edit/delete links by default) before the fetch, so a slow or failed request doesn't leave stale content visible. Edit and Delete links only re-appear if PAuthor matches the logged-in user.
!!
!! Subject and body are base64-decoded after fetch (see RenderPosts for why). The post id doubles as a millisecond timestamp; FormatTimestamp turns it into PDate (YYYY/MM/DD) and PTime (HH:MM:SS). Replies are returned as part of the same /view response and handed to RenderReplies.

ViewPost:
    set style `display` of PostListPanel to `none`
    set style `display` of NewPostPanel to `none`
    set style `display` of EditPostPanel to `none`
    set style `display` of PostsPanel to `flex`
    set style `display` of PostViewPanel to `flex`
    set style `display` of PostViewSubject to `block`
    set style `display` of PostViewBody to `block`
    set style `display` of PostRepliesPanel to `block`
    set the content of PostViewSubject to `Loading...`
    set the content of PostViewAuthor to ``
    set the content of PostViewBody to ``
    set style `display` of EditPostLink to `none`
    set style `display` of DeletePostLink to `none`
    set the content of PostRepliesPanel to ``
    rest get PostData from ApiBase cat `/view/` cat CurrentTopic cat `/` cat CurrentPostId
    or begin
        set the content of PostViewSubject to `No reply from server`
        return
    end
    put element `post` of PostData into PostObj
    put element `subject` of PostObj into PSubject
    put element `author` of PostObj into PAuthor
    put element `body` of PostObj into PBody
    put element `id` of PostObj into PTimestamp
    set encoding to `base64`
    decode PSubject
    decode PBody
    gosub FormatTimestamp
    set the content of PostViewSubject to PSubject
    set the content of PostViewAuthor to `by ` cat PAuthor cat ` at ` cat PTime cat ` on ` cat PDate
    set the content of PostViewBody to PBody
    if PAuthor is ChatUsername
    begin
        set style `display` of EditPostLink to `inline`
        set style `display` of DeletePostLink to `inline`
    end
    put element `replies` of PostData into RepliesJson
    gosub RenderReplies
    return
!!!

!! Render the post's replies, with per-reply Delete buttons for the right users.
!!
!! Each reply is rendered as an indented block: author label plus a body preview. A Delete button appears when the logged-in user is either the reply's author OR the parent post's owner — so post owners can clear other people's replies on their own posts.
!!
!! The reply IDs are accumulated into ReplyDeleteIds (pipe-delimited, in render order) so DoDeleteReply can recover the right ID from `the index of ReplyDeleteBtn`. After insertion, the matching `ReplyDel-N` DOM elements are attached into the ReplyDeleteBtn array so a single `on click` covers them all.

RenderReplies:
    put the json count of RepliesJson into Count
    if Count is 0
    begin
        set the content of PostRepliesPanel to ``
        return
    end
    put `<div style="font-weight:bold;padding:0.3em 0">Replies:</div>` into RepliesMarkup
    put 0 into ReplyDeleteCount
    put `` into ReplyDeleteIds
    put 0 into N
    while N is less than Count
    begin
        put element N of RepliesJson into REntry
        put element `author` of REntry into RAuthor
        put element `preview` of REntry into RPreview
        set encoding to `base64`
        decode RPreview
        put element `id` of REntry into RId
        put RepliesMarkup
            cat `<div style="padding:0.3em 0 0.3em 1em;border-left:2px solid #ccc;margin-bottom:0.3em">`
            cat `<strong>` cat RAuthor cat `:</strong> ` cat RPreview into RepliesMarkup
        if RAuthor is ChatUsername or PAuthor is ChatUsername
        begin
            put RepliesMarkup
                cat ` <button id="ReplyDel-` cat ReplyDeleteCount
                cat `" data-replyid="` cat RId
                cat `" style="font-size:0.8em;color:#800;cursor:pointer;background:none;border:none;text-decoration:underline">Delete</button>` into RepliesMarkup
            if ReplyDeleteIds is not `` put ReplyDeleteIds cat `|` into ReplyDeleteIds
            put ReplyDeleteIds cat RId into ReplyDeleteIds
            add 1 to ReplyDeleteCount
        end
        put RepliesMarkup cat `</div>` into RepliesMarkup
        add 1 to N
    end
    set the content of PostRepliesPanel to RepliesMarkup
    if ReplyDeleteCount is greater than 0
    begin
        set the elements of ReplyDeleteBtn to ReplyDeleteCount
        put 0 into N
        while N is less than ReplyDeleteCount
        begin
            index ReplyDeleteBtn to N
            attach ReplyDeleteBtn to `ReplyDel-` cat N
            add 1 to N
        end
        on click ReplyDeleteBtn gosub DoDeleteReply
    end
    return
!!!

!! Return from the posts pane to the topic list and reload it.
!!
!! Clears CurrentTopic so HandleTopicToggle's branch logic flips back to "open New Topic", relabels the toggle to "New Topic", hides the post-related panels, and re-fetches the topic list to pick up any changes elsewhere.

BackToTopics:
    put empty into CurrentTopic
    set the content of TopicBarTitle to `Topics`
    set the content of NewTopicToggle to `New Topic`
    set style `display` of NewPostToggle to `none`
    set style `display` of PostsPanel to `none`
    set style `display` of PostViewPanel to `none`
    set style `display` of TopicListPanel to `block`
    gosub HideNewPost
    gosub LoadTopics
    return
!!!

!! Show the new-post form.

ToggleNewPost:
    set style `display` of NewPostPanel to `flex`
    return
!!!

!! Hide the new-post form and clear any error message.

HideNewPost:
    set style `display` of NewPostPanel to `none`
    set the content of NewPostMessage to ``
    return
!!!

!! Submit the new-post form; reload the post list on success.
!!
!! Validates locally that subject and body are non-empty. The client sends the subject and body as plain text — the server is responsible for base64-encoding them for storage. On success clear the form, hide the panel, and call ShowPosts to re-fetch.

SubmitPost:
    put the text of NewPostSubject into PSubject
    if PSubject is empty
    begin
        set the content of NewPostMessage to `Please enter a subject`
        set style `color` of NewPostMessage to `#800`
        return
    end
    if the text of NewPostBody is empty
    begin
        set the content of NewPostMessage to `Please write something`
        set style `color` of NewPostMessage to `#800`
        return
    end
    set the content of NewPostMessage to `Posting...`
    set style `color` of NewPostMessage to `#888`
    put `{"topic":"` cat CurrentTopic
        cat `","subject":"` cat PSubject
        cat `","author":"` cat ChatUsername
        cat `","body":"` cat the text of NewPostBody
        cat `"}` into Request
    rest post Request to ApiBase cat `/post` giving Response
    or begin
        set the content of NewPostMessage to `No reply from server`
        set style `color` of NewPostMessage to `#800`
        return
    end
    put element `status` of Response into ReplyStatus
    if ReplyStatus is `ok`
    begin
        gosub HideNewPost
        set the content of NewPostSubject to ``
        set the content of NewPostBody to ``
        gosub ShowPosts
    end
    else
    begin
        put element `message` of Response into ReplyBody
        set the content of NewPostMessage to ReplyBody
        set style `color` of NewPostMessage to `#800`
    end
    return
!!!

!! Return from the post-detail view to the post list, also hiding any open reply form.

BackToPosts:
    set style `display` of PostViewPanel to `none`
    set style `display` of PostListPanel to `block`
    gosub HideReply
    return
!!!

!! Switch the post view into edit mode, pre-filling the form with the current subject and body.
!!
!! Hides the static subject/body/replies and shows the editable form. PSubject and PBody were left populated by the most recent ViewPost call, so the form starts with the current values without an extra fetch.

EditPost:
    set the text of EditPostSubject to PSubject
    set the text of EditPostBody to PBody
    set the content of EditPostMessage to ``
    set style `display` of PostViewSubject to `none`
    set style `display` of PostViewBody to `none`
    set style `display` of PostRepliesPanel to `none`
    set style `display` of EditPostPanel to `flex`
    return
!!!

!! Cancel edit mode and restore the static post view.
!!
!! Does not call ViewPost — the in-memory PSubject/PBody were not modified, so the static panes still show the right values and a re-fetch would be wasted.

CancelEdit:
    set style `display` of EditPostPanel to `none`
    set style `display` of PostViewSubject to `block`
    set style `display` of PostViewBody to `block`
    set style `display` of PostRepliesPanel to `block`
    return
!!!

!! Confirm and delete the current post.
!!
!! `confirm` is a synchronous browser prompt; the user must accept before the request fires. On success, hide the now-defunct post-view and re-fetch the posts list via ShowPosts. The server re-checks the author matches the logged-in user; if it rejects (e.g. auth changed) the alert path surfaces the message.

DeletePost:
    if confirm `Are you sure you want to delete this post?`
    begin
        put `{"topic":"` cat CurrentTopic
            cat `","id":"` cat CurrentPostId
            cat `","author":"` cat ChatUsername
            cat `"}` into Request
        rest post Request to ApiBase cat `/delete-post` giving Response
        or begin
            alert `No reply from server`
            return
        end
        put element `status` of Response into ReplyStatus
        if ReplyStatus is `ok`
        begin
            set style `display` of PostViewPanel to `none`
            set style `display` of PostListPanel to `block`
            gosub ShowPosts
        end
        else
        begin
            put element `message` of Response into ReplyBody
            alert ReplyBody
        end
    end
    return
!!!

!! Submit an edit to the current post.
!!
!! Validates non-empty subject and body locally before sending. On success, hide the edit panel and re-run ViewPost to refresh from the server (this also re-decodes the base64-stored values and re-renders the replies). On rejection, leave the form open with the server's message in place.

SaveEdit:
    put the text of EditPostSubject into PSubject
    if PSubject is empty
    begin
        set the content of EditPostMessage to `Subject cannot be empty`
        set style `color` of EditPostMessage to `#800`
        return
    end
    put the text of EditPostBody into PBody
    if PBody is empty
    begin
        set the content of EditPostMessage to `Body cannot be empty`
        set style `color` of EditPostMessage to `#800`
        return
    end
    set the content of EditPostMessage to `Saving...`
    set style `color` of EditPostMessage to `#888`
    put `{"topic":"` cat CurrentTopic
        cat `","id":"` cat CurrentPostId
        cat `","author":"` cat ChatUsername
        cat `","subject":"` cat PSubject
        cat `","body":"` cat PBody
        cat `"}` into Request
    rest post Request to ApiBase cat `/edit-post` giving Response
    or begin
        set the content of EditPostMessage to `No reply from server`
        set style `color` of EditPostMessage to `#800`
        return
    end
    put element `status` of Response into ReplyStatus
    if ReplyStatus is `ok`
    begin
        set style `display` of EditPostPanel to `none`
        gosub ViewPost
    end
    else
    begin
        put element `message` of Response into ReplyBody
        set the content of EditPostMessage to ReplyBody
        set style `color` of EditPostMessage to `#800`
    end
    return
!!!

!! Show the reply form for the current post.

ToggleReply:
    set style `display` of ReplyPanel to `flex`
    return
!!!

!! Hide the reply form and clear any error message.

HideReply:
    set style `display` of ReplyPanel to `none`
    set the content of ReplyMessage to ``
    return
!!!

!! Submit a reply to the current post; re-fetch the post on success.
!!
!! CurrentDepth was set by PostClick (0 for root) or by a previous reply view; it's passed through so the server can enforce the 3-deep limit and stamp the new reply's depth. The body is sent as plain text — the server base64-encodes it for storage. Success path clears and hides the reply form, then re-runs ViewPost so the new reply appears in the list.

SubmitReply:
    if the text of ReplyBodyInput is empty
    begin
        set the content of ReplyMessage to `Please write something`
        set style `color` of ReplyMessage to `#800`
        return
    end
    set the content of ReplyMessage to `Posting reply...`
    set style `color` of ReplyMessage to `#888`
    put `{"topic":"` cat CurrentTopic
        cat `","postId":"` cat CurrentPostId
        cat `","depth":` cat CurrentDepth
        cat `,"author":"` cat ChatUsername
        cat `","body":"` cat the text of ReplyBodyInput
        cat `"}` into Request
    rest post Request to ApiBase cat `/reply` giving Response
    or begin
        set the content of ReplyMessage to `No reply from server`
        set style `color` of ReplyMessage to `#800`
        return
    end
    put element `status` of Response into ReplyStatus
    if ReplyStatus is `ok`
    begin
        gosub HideReply
        set the content of ReplyBodyInput to ``
        gosub ViewPost
    end
    else
    begin
        put element `message` of Response into ReplyBody
        set the content of ReplyMessage to ReplyBody
        set style `color` of ReplyMessage to `#800`
    end
    return
!!!

!! Confirm and delete the reply at the position of the clicked Delete button.
!!
!! `the index of ReplyDeleteBtn` gives the position within the delete-button array, but the rendered DOM doesn't carry the reply ID alongside that index. ReplyDeleteIds is a pipe-delimited string of reply IDs assembled in render order in RenderReplies; the loop steps past N pipe-separated entries to land on the right ID, then the trailing-tail trim removes any reply IDs that come after. Server-side, the delete is authorised if the caller is the reply's author OR the parent post's owner.

DoDeleteReply:
    if confirm `Are you sure you want to delete this reply?`
    begin
        put the index of ReplyDeleteBtn into N
        put ReplyDeleteIds into RId
        while N is greater than 0
        begin
            put position of `|` in RId into Pos
            add 1 to Pos
            put from Pos of RId into RId
            take 1 from N
        end
        put position of `|` in RId into Pos
        if Pos is not -1 put left Pos of RId into RId
        put `{"topic":"` cat CurrentTopic
            cat `","postId":"` cat CurrentPostId
            cat `","replyId":"` cat RId
            cat `","author":"` cat ChatUsername
            cat `"}` into Request
        rest post Request to ApiBase cat `/delete-reply` giving Response
        or begin
            alert `No reply from server`
            return
        end
        put element `status` of Response into ReplyStatus
        if ReplyStatus is `ok` gosub ViewPost
        else
        begin
            put element `message` of Response into ReplyBody
            alert ReplyBody
        end
    end
    return
!!!

!! Format PTimestamp (milliseconds since epoch) into PDate as YYYY/MM/DD and PTime as HH:MM:SS.
!!
!! Divides by 1000 first because AllSpeak's date-part operators (`year of`, `month number of`, etc.) expect seconds. `month number` is zero-based, so add 1. Zero-padding two-digit fields is done by appending a literal `0` to the running string before appending the number — there is no inline formatter in AllSpeak. PTime is initialised differently (hour can start fresh) than PDate (which is already partially built when minute and second are appended).

FormatTimestamp:
    divide PTimestamp by 1000
    put year of PTimestamp into PDate
    put PDate cat `/` into PDate
    put month number of PTimestamp into PDPart
    add 1 to PDPart
    if PDPart is less than 10 put PDate cat `0` into PDate
    put PDate cat PDPart cat `/` into PDate
    put day number of PTimestamp into PDPart
    if PDPart is less than 10 put PDate cat `0` into PDate
    put PDate cat PDPart into PDate
    put hour of PTimestamp into PDPart
    if PDPart is less than 10 put `0` into PTime
    else put `` into PTime
    put PTime cat PDPart cat `:` into PTime
    put minute of PTimestamp into PDPart
    if PDPart is less than 10 put PTime cat `0` into PTime
    put PTime cat PDPart cat `:` into PTime
    put second of PTimestamp into PDPart
    if PDPart is less than 10 put PTime cat `0` into PTime
    put PTime cat PDPart into PTime
    return
!!!

!! Enable the login button only when both username and password fields are non-empty.
!!
!! Bound to `on key` in ShowLogin so it fires after every keystroke; also called explicitly after showing the form and after a failed attempt to recompute the initial state.

CheckLoginFields:
    if UsernameInput is not empty
    begin
        if PasswordInput is not empty
        begin
            enable LoginButton
            return
        end
    end
    disable LoginButton
    return
!!!

!! Enable the register button only when both username and password fields are non-empty.
!!
!! Symmetric counterpart to CheckLoginFields for the register form.

CheckRegisterFields:
    if RegUsernameInput is not empty
    begin
        if RegPasswordInput is not empty
        begin
            enable RegisterButton
            return
        end
    end
    disable RegisterButton
    return
!!!

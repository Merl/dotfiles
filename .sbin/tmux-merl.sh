#!/bin/sh
# tmux-merl.sh [session] - attach to a tmux session, creating it if needed.
#
#   session  name of the session (default: merl)
#
# Inside tmux the client is switched to the session instead of nesting.
# A new session starts with one window; split on demand.
#
# Host-specific setup: if ~/.overwrites/tmux.sh exists, it is sourced once,
# right after the session has been created and before attaching. It can use
# the variables $tmux (tmux command) and $SESSION (session name), e.g.
#     $tmux new-window -t $SESSION:1
#     $tmux send-keys  -t $SESSION:1.0 'weechat' enter

SESSION=${1:-merl}
tmux=tmux

if ! command -v "$tmux" >/dev/null 2>&1; then
    echo "tmux-merl.sh: tmux not found" >&2
    exit 1
fi

# "=name" matches the session name exactly (no prefix matching)
if ! $tmux has-session -t "=$SESSION" 2>/dev/null; then
    first=$($tmux new-session -d -s "$SESSION" -P -F '#{window_id}') || exit 1
    if [ -f "$HOME/.overwrites/tmux.sh" ]; then
        . "$HOME/.overwrites/tmux.sh"
        # start in the first window, whatever the host script selected
        $tmux select-window -t "$first"
    fi
fi

if [ -n "$TMUX" ]; then
    exec $tmux switch-client -t "=$SESSION"
else
    exec $tmux attach-session -t "=$SESSION"
fi

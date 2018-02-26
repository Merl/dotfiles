#!/bin/sh
SESSION=merl
tmux="./tmux.pl -2" # -f .sbin/tmux-merl.conf"
EDITOR=vim
export $EDITOR


# if the session is already running, just attach to it.
$tmux has-session -t $SESSION
if [ $? -eq 0 ]; then
	echo "Session $SESSION already exists. Attaching."
	sleep 1
	$tmux attach -t $SESSION
	exit 0;
fi

# create a new session, named $SESSION, and detach from it
$tmux new-session -d -s $SESSION
#$tmux new-window    -t $SESSION:0 
$tmux split-window  -h -t $SESSION:0
$tmux split-window  -h -t $SESSION:0
$tmux split-window  -h -t $SESSION:0
$tmux select-layout -t $SESSION:0 '99cc,271x83,0,0[271x61,0,0{75x61,0,0,3,195x61,76,0,5},271x21,0,62{100x21,0,62,4,170x21,101,62,6}]'
#$tmux new-window    -t $SESSION:1 
#$tmux new-window    -t $SESSION:2  
#$tmux new-window    -t $SESSION:3  
#$tmux split-window  -h -t $SESSION:3
#$tmux new-window    -t $SESSION:4
$tmux select-window -t $SESSION:0
$tmux select-pane -t 1
$tmux attach -t $SESSION

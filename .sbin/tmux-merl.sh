#!/bin/sh
SESSION=merl
#tmux="tmux -2 -f tmux-merl.conf"
tmux="/usr/bin/tmux -2"


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
$tmux new-window    -t $SESSION:0 
$tmux split-window  -h -t $SESSION:0
$tmux split-window  -h -t $SESSION:0
$tmux split-window  -h -t $SESSION:0
$tmux select-layout -t $SESSION:0 63dc,180x55,0,0{65x55,0,0[65x12,0,0,65x42,0,13],114x55,66,0[114x37,66,0,114x17,66,38]}
#$tmux new-window    -t $SESSION:1 
#$tmux new-window    -t $SESSION:2  
#$tmux new-window    -t $SESSION:3  
#$tmux split-window  -h -t $SESSION:3
#$tmux new-window    -t $SESSION:4
#$tmux select-window -t $SESSION:0
#$tmux send-keys -t $SESSION:0.0 'echo hallo' enter
$tmux attach -t $SESSION

SESSION=runmeter

tmux new-session -d -s $SESSION -n Controller

tmux split-window -v -t $SESSION:0
tmux split-window -v -t $SESSION:0
tmux select-pane -t $SESSION:0.0
tmux split-window -h -t $SESSION:0
tmux split-window -h -t $SESSION:0
tmux select-pane -t $SESSION:0.3
tmux split-window -h -t $SESSION:0

# Set default panel
tmux select-pane -t $SESSION:0.3
tmux send-keys -t $SESSION:0.3 "cd ~/term-run-meter" Enter

tmux attach-session -t $SESSION

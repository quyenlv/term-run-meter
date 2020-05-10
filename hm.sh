#!/bin/bash

DST_FILE=distance
DST_TARGET_FILE=distance-target
CNT_FILE=counter
CNT_TARGET_FILE=counter-target
RESULT_FILE=result
TMUX_SESSION=HM
WORK_DIR=/home/nana/work/hm

# In decimeter
distance_target=210975
distance_per_lap=648
#distance_per_lap=80000

target_laps=0

distance=0
counter=0

pace_pane=0
laps_pane=1
distance_pane=2
cmd_pane=3
stopwatch_pane=4
progress_pane=5

is_started=0

# Push button setup
mouse="$(xinput --list | awk -F 'id=|\\[' '/Dell USB Mouse/ {print $2}')"
mouse="${mouse//[[:space:]]}"

bell_last_lap=soundsuccess-1.wav
bell=sound/success-2.wav
bell_victory=sound/winner-1.wav

last_pressed_time=0
last_record_time=0
curr_record_time=0

###########################
#####   FUNCTIONS     #####
###########################

setup_tmux_layout()
{
    cur_cmd_pane_width=$(tmux display -p -t $TMUX_SESSION:0.3 '#{pane_width}')
    if [[ "$cur_cmd_pane_width" == 59 ]]; then
        return
    fi

    tmux resize-pane -t $TMUX_SESSION:0.0 -x 59
    tmux resize-pane -t $TMUX_SESSION:0.0 -y 20
    tmux resize-pane -t $TMUX_SESSION:0.3 -x 59
    tmux resize-pane -t $TMUX_SESSION:0.3 -y 16
    tmux resize-pane -t $TMUX_SESSION:0.1 -x 54

    tmux send-keys -t $pace_pane "cd $WORK_DIR; ./sampler -c pace.yml" Enter
    tmux send-keys -t $laps_pane "cd $WORK_DIR; ./sampler -c counter.yml" Enter
    tmux send-keys -t $distance_pane "cd $WORK_DIR; ./sampler -c distance.yml" Enter
    tmux send-keys -t $progress_pane "cd $WORK_DIR; ./sampler -c progress.yml" Enter
    tmux send-keys -t $stopwatch_pane "peaclock" Enter

    # Lock the screen to avoid unwanted keys input
    tmux switch-client -rt $TMUX_SESSION
}

increase_counter()
{
    # Update the lap so far
    ((counter=counter+1))
    echo $counter > $CNT_FILE

    # Update distance so far
    printf %.4f $(perl -E "say $distance_per_lap*$counter/10000") > $DST_FILE

    curr_record_time=$(date +%s)
    elapsed_lap_time=$(($curr_record_time-$last_record_time))
    last_record_time=$curr_record_time
}

start_game()
{
    is_started=1
    last_record_time=$(date +%s)

    printf "\nStart at %s %s\n" $(date +"%T" -d @$last_record_time) \
                                $last_record_time | tee -a $RESULT_FILE

    # Start the stop watch
    tmux send-keys -t $stopwatch_pane Space

    # Notify to the runner
    play -q -V0 $bell
}

finish_a_lap()
{
    increase_counter

    # Record the lap
    printf "Lap %d at %s %s %s\n" $counter $(date +"%T" -d @$curr_record_time) \
                    $curr_record_time $elapsed_lap_time | tee -a $RESULT_FILE

    # Notify to the runner
    if [[ "$counter" -eq $(($target_laps-1)) ]]; then
        # Notify to the last lap
        play -q -V0 $bell_last_lap
    else
        play -q -V0 $bell
    fi
}

complete_the_race()
{
    increase_counter

    # Record the last lap
    printf "Lap %d at %s %s %s\n" $counter $(date +"%T" -d @$curr_record_time) \
                    $curr_record_time $elapsed_lap_time | tee -a $RESULT_FILE

    echo "Finish. Congratulation!!!" | tee -a $RESULT_FILE

    # Stop the stop watch
    tmux send-keys -t $stopwatch_pane Space

    play -q -V0 $bell_victory
}

###########################
#####      SETUP      #####
###########################
printf %.4f $(perl -E "say $distance_target/10000") > $DST_TARGET_FILE

# Calculate the ceil totals laps
target_laps=$(perl -w -e "use POSIX; \
    print ceil($distance_target/$distance_per_lap), qq{\n}") 

echo $target_laps > $CNT_TARGET_FILE
echo $counter > $CNT_FILE
echo $distance > $DST_FILE

# Clear the stop watch
tmux send-keys -t $stopwatch_pane BSpace

setup_tmux_layout

> $RESULT_FILE

echo "Press to start the race. Good luck!"

###########################
#####       MAIN      #####
###########################

while :; do
    state="$(xinput --query-state "$mouse")"

    if [[ "$state" == *"button[1]=down"* ]]; then
        if [[ "$last_pressed_time" == 0 ]]; then
            last_pressed_time=`date +%s`
        fi

        curr_pressed_time=`date +%s`
        hold_time=$(($curr_pressed_time-$last_pressed_time))

        if [[ "$hold_time" -ge 2 ]]; then
            complete_the_race
            break
        fi

    elif [[ "$state" == *"button[1]=up"* ]]; then
        if [[ "$last_pressed_time" != 0 ]]; then
            last_pressed_time=0
            #echo "Hold time $hold_time"

            if [[ "$counter" == 0 && "$is_started" == 0 ]]; then
                start_game
                continue
            fi

            finish_a_lap
        fi
    fi

    sleep .1s
done

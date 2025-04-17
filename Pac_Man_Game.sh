#!/bin/bash

# Game Configuration
ROWS=30
COLS=40
SCORE=0
LIVES=5
HIGHSCORE=0
POWER_MODE=0
LEVEL=1
PLAYER_COLOR="\e[1;33m"  # Yellow
GHOST_COLOR_NORMAL="\e[1;31m"  # Red
GHOST_COLOR_VULN="\e[1;36m"   # Cyan

# Load high score
[ -f ~/.pacman_highscore ] && HIGHSCORE=$(cat ~/.pacman_highscore)

# Initialize positions
player_row=$((ROWS / 2))
player_col=5
declare -A obstacles walls dots power_pellets ghosts

# Initialize walls (Border)
init_walls() {
    for ((i=0; i<ROWS; i++)); do
        walls[$i,0]=1
        walls[$i,$((COLS-1))]=1
    done
    for ((j=0; j<COLS; j++)); do
        walls[0,$j]=1
        walls[$((ROWS-1)),$j]=1
    done
}

# Initialize collectibles
init_collectibles() {
    for ((i=1; i<ROWS-1; i++)); do
        for ((j=1; j<COLS-1; j++)); do
            dots[$i,$j]=1
        done
    done
    
    for ((i=0; i<4; i++)); do
        row=$((RANDOM % (ROWS-4) + 2))
        col=$((RANDOM % (COLS-4) + 2))
        power_pellets[$row,$col]=1
        unset dots[$row,$col]
    done
}

# Spawn obstacles
spawn_obstacles() {
    local count=15
    for ((i=0; i<count; i++)); do
        row=$((RANDOM % (ROWS-2) + 1))
        col=$((RANDOM % (COLS-2) + 1))
        obstacles[$row,$col]="#"
        unset dots[$row,$col]
    done
}

# Spawn ghosts
spawn_ghosts() {
    local ghost_count=3  # Number of ghosts
    ghosts=()
    for ((i=0; i<ghost_count; i++)); do
        row=$((RANDOM % (ROWS-2) + 1))
        col=$((RANDOM % (COLS-2) + 1))
        ghosts["$row,$col"]=1
    done
}

display_header() {
    echo -ne "\e[1;37mLevel: $LEVEL | Lives: $LIVES | Score: $SCORE | High Score: $HIGHSCORE\e[0m\n"
}

display_grid() {
    clear
    display_header
    for ((i=0; i<ROWS; i++)); do
        for ((j=0; j<COLS; j++)); do
            if [[ $i -eq $player_row && $j -eq $player_col ]]; then
                echo -ne "${PLAYER_COLOR}🟡\e[0m"
            elif [[ ${ghosts[$i,$j]} ]]; then
                if ((POWER_MODE > 0)); then
                    echo -ne "${GHOST_COLOR_VULN}👻\e[0m"
                else
                    echo -ne "${GHOST_COLOR_NORMAL}👻\e[0m"
                fi
            elif [[ ${walls[$i,$j]} == 1 ]]; then
                echo -ne "\e[1;34m█\e[0m"
            elif [[ ${power_pellets[$i,$j]} == 1 ]]; then
                echo -ne "\e[1;38;5;208m⯑\e[0m"
            elif [[ ${dots[$i,$j]} == 1 ]]; then
                echo -ne "\e[1;37m•\e[0m"
            else
                echo -ne " "
            fi
        done
        echo ""
    done
}

move_player() {
    local key=$1
    local new_row=$player_row
    local new_col=$player_col

    case $key in
        w) ((new_row--)) ;;
        s) ((new_row++)) ;;
        a) ((new_col--)) ;;
        d) ((new_col++)) ;;
        *) return ;;
    esac

    if [[ -z ${walls[$new_row,$new_col]} ]]; then
        player_row=$new_row
        player_col=$new_col
        
        if [ ${dots[$player_row,$player_col]} ]; then
            ((SCORE += 10))
            unset dots[$player_row,$player_col]
        fi
        
        if [ ${power_pellets[$player_row,$player_col]} ]; then
            ((SCORE += 50))
            POWER_MODE=15
            unset power_pellets[$player_row,$player_col]
        fi
    fi
}

# Move ghosts randomly
move_ghosts() {
    declare -A new_ghosts
    for key in "${!ghosts[@]}"; do
        IFS=',' read -r row col <<< "$key"

        local move=$((RANDOM % 4))
        local new_row=$row
        local new_col=$col

        case $move in
            0) ((new_row--)) ;;  # Up
            1) ((new_row++)) ;;  # Down
            2) ((new_col--)) ;;  # Left
            3) ((new_col++)) ;;  # Right
        esac

        if [[ -z ${walls[$new_row,$new_col]} ]]; then
            new_ghosts[$new_row,$new_col]=1
        else
            new_ghosts[$row,$col]=1  # Stay in place if blocked
        fi
    done
    ghosts=()  # Clear old positions
    for key in "${!new_ghosts[@]}"; do
        ghosts[$key]=1
    done
}

check_collisions() {
    if [[ ${ghosts[$player_row,$player_col]} ]]; then
        if ((POWER_MODE > 0)); then
            ((SCORE += 200))
            spawn_ghosts  # Respawn the ghosts
        else
            ((LIVES--))
            if ((LIVES > 0)); then
                player_row=$((ROWS/2))
                player_col=5
                sleep 1
            else
                echo -e "\e[1;31mGame Over! You ran out of lives! Final Score: $SCORE\e[0m"
                sleep 3
                [ $SCORE -gt $HIGHSCORE ] && echo $SCORE > ~/.pacman_highscore
                exit 0
            fi
        fi
    fi
}

game_loop() {
    stty -echo -icanon time 0 min 0
    trap 'stty sane; exit 0' SIGINT

    local ghost_move_delay=5
    local ghost_counter=0
    local time_left=30
    local start_time=$(date +%s)  # Get the current timestamp

    while true; do
        # Update time_left every second
        local current_time=$(date +%s)
        if (( current_time - start_time >= 1 )); then
            ((time_left--))
            start_time=$current_time  # Reset timer

            if (( time_left <= 0 )); then
                echo -e "\e[1;31mTime's up! Game Over! Final Score: $SCORE\e[0m"
                sleep 2
                [ $SCORE -gt $HIGHSCORE ] && echo $SCORE > ~/.pacman_highscore
                exit 0
            fi
        fi

        display_grid
        echo -e "\e[1;36mTime left: $time_left sec\e[0m"  

        read -sn1 -t0.1 keypress  

        case $keypress in
            q) break ;;
            w|s|a|d) move_player "$keypress" ;;
        esac

        ((ghost_counter++))
        if ((ghost_counter >= ghost_move_delay)); then
            move_ghosts
            ghost_counter=0
        fi

        ((POWER_MODE > 0)) && ((POWER_MODE--))
        check_collisions

        if [[ $((${#dots[@]} + ${#power_pellets[@]})) -eq 0 ]]; then
            ((LEVEL++))
            ((SCORE += 1000))
            echo -e "\e[1;32mLEVEL COMPLETE! Starting level $LEVEL\e[0m"
            sleep 2

            init_collectibles
            spawn_obstacles
            spawn_ghosts
            player_row=$((ROWS / 2))
            player_col=5
        fi
    done

    stty sane
}

init_walls
init_collectibles
spawn_obstacles
spawn_ghosts
game_loop

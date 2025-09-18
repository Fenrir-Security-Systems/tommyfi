#!/bin/bash

# --- Configuration ---
DATA_DIR="/home/tommy/tommyfi_data"
SONGS_DB="$DATA_DIR/songs.csv"
USERS_DB="$DATA_DIR/users.csv"
HISTORY_FILE=""
USERNAME=""
USER_ROLE="user" # Default role

# --- Database and State ---
declare -A playlist

# --- Core Functions ---

# Load songs from the CSV database into memory
load_songs() {
    playlist=()
    while IFS=';' read -r id title url; do
        if [[ -n "$title" && -n "$url" ]]; then
            playlist["$title"]="$url"
        fi
    done < "$SONGS_DB"
}

# --- Function to handle user login and history ---
handle_user() {
    read -p "Enter your name (tag): " USERNAME
    HISTORY_FILE="$DATA_DIR/$USERNAME.history"

    # Check user role
    local role_from_db=$(grep "^$USERNAME;" "$USERS_DB" | cut -d';' -f2)
    if [[ -n "$role_from_db" ]]; then
        USER_ROLE="$role_from_db"
    else
        USER_ROLE="user"
    fi
    echo "Welcome, $USERNAME! Your role is: $USER_ROLE"
    sleep 1

    mkdir -p "$DATA_DIR"

    if [ -f "$HISTORY_FILE" ]; then
        echo "Welcome back, $USERNAME! Here is your listening history:"
        i=1
        declare -A history_map
        while IFS= read -r song; do
            printf '%2d) %s\n' "$i" "$song"
            history_map["$i"]="$song"
            ((i++))
        done < "$HISTORY_FILE"

        read -p "Enter the number of a song to play, or press Enter to search: " pick
        
        if [[ -n "$pick" && -n "${history_map[$pick]}" ]]; then
            selected="${history_map[$pick]}"
            play_song "$selected"
        fi
    else
        echo "Welcome, $USERNAME! Let's create your listening history."
        touch "$HISTORY_FILE"
    fi
}

# --- Function to update user history ---
update_history() {
    local song_name=$1
    grep -v "^$song_name$" "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    (echo "$song_name"; cat "$HISTORY_FILE") > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    sed -i '21,$d' "$HISTORY_FILE"
}

# --- Function to play a song and update history ---
play_song() {
    local selected_song=$1
    printf "playing: %s\n" "$selected_song"
    cmatrix & CM_PID=$!
    mpv --no-video "${playlist[$selected_song]}"
    kill $CM_PID
    update_history "$selected_song"
}

# --- Admin Functions ---
add_song() {
    if [[ "$USER_ROLE" != "admin" ]]; then
        echo "Permission Denied. Only admins can add songs."
        sleep 1
        return
    fi
    read -p "Enter song title: " title
    read -p "Enter song URL: " url
    if [[ -z "$title" || -z "$url" ]]; then
        echo "Title and URL cannot be empty."
        sleep 1
        return
    fi
    local last_id=$(tail -n 1 "$SONGS_DB" | cut -d';' -f1)
    local new_id=$((last_id + 1))
    echo "$new_id;$title;$url" >> "$SONGS_DB"
    echo "Song '$title' added."
    load_songs # Reload songs
    sleep 1
}

delete_song() {
    if [[ "$USER_ROLE" != "admin" ]]; then
        echo "Permission Denied. Only admins can delete songs."
        sleep 1
        return
    fi
    read -p "Enter the exact title of the song to delete: " title_to_delete
    if [[ -z "$title_to_delete" ]]; then
        echo "Title cannot be empty."
        sleep 1
        return
    fi

    # Use grep to remove the line with the matching title
    grep -v ";$title_to_delete;" "$SONGS_DB" > "$SONGS_DB.tmp"
    if [ -s "$SONGS_DB.tmp" ]; then
        mv "$SONGS_DB.tmp" "$SONGS_DB"
        echo "Song '$title_to_delete' deleted."
        load_songs # Reload songs
    else
        echo "Song not found or error deleting."
    fi
    sleep 1
}

# --- Main Logic ---

# Load songs from DB at the start
load_songs

handle_user

echo "Welcome to tommyfi"

search_song() {
      read -p "enter the song warrior (or !add, !delete): " song

      # Admin commands
      if [[ "$song" == "!add" ]]; then
          add_song
          search_song
          return
      elif [[ "$song" == "!delete" ]]; then
          delete_song
          search_song
          return
      fi
      
      query=$(tr -d ' ' <<<"$song" | tr '[:upper:]' '[:lower:]' )

      matches=$(for b in "${!playlist[@]}"; do 
         norm=$(tr -d ' ' <<<"$b" | tr '[:upper:]' '[:lower:]'  )
         if [[ "$norm" == *"$query"* ]] then
             printf "%s\n" "$b"
         elif [[ "$song" == "log" ]]; then
             handle_user
         fi 
      done )

      if [[ -z "$matches" ]]; then
         printf "no songs related for '%s',try again.\n " "$song"
         search_song
     elif [[ "$song" == "log" ]]; then
             handle_user
      
      else
         printf "related songs:\n"
         i=1
         declare -A choicemap
         while IFS= read -r track; do
            printf '%2d) %s\n' "$i" "$track"
            choicemap["$i"]="$track"
            ((i++))
         done <<< "$matches"
   
         read -p " Enter the number of song you want to play: " pick
         selected="${choicemap[$pick]}"
         
         if [[ -n "$selected" ]]; then
            play_song "$selected"
         else
            python rickrollplayer.py
            echo "welcome warrior! ! !"
         fi
      fi
      search_song
}

search_song
#!/bin/bash

# --- Configuration ---
DATA_DIR="/home/tommy/tommyfi_data"
SONGS_DB="$DATA_DIR/songs.csv"
USERS_DB="$DATA_DIR/users.csv"
HISTORY_FILE=""
USERNAME=""
USER_ROLE="user" # Default role

# --- Database and State ---
declare -A playlist

# --- Core Functions ---

# Load songs from the CSV database into memory
load_songs() {
    playlist=()
    while IFS=';' read -r id title url; do
        if [[ -n "$title" && -n "$url" ]]; then
            playlist["$title"]="$url"
        fi
    done < "$SONGS_DB"
}

# --- Function to handle user login and history ---
handle_user() {
    read -p "Enter your name (tag): " USERNAME
    HISTORY_FILE="$DATA_DIR/$USERNAME.history"

    # Check user role
    local role_from_db=$(grep "^$USERNAME;" "$USERS_DB" | cut -d';' -f2)
    if [[ -n "$role_from_db" ]]; then
        USER_ROLE="$role_from_db"
    else
        USER_ROLE="user"
    fi
    echo "Welcome, $USERNAME! Your role is: $USER_ROLE"
    sleep 1

    mkdir -p "$DATA_DIR"

    if [ -f "$HISTORY_FILE" ]; then
        echo "Welcome back, $USERNAME! Here is your listening history:"
        i=1
        declare -A history_map
        while IFS= read -r song; do
            printf '%2d) %s\n' "$i" "$song"
            history_map["$i"]="$song"
            ((i++))
        done < "$HISTORY_FILE"

        read -p "Enter the number of a song to play, or press Enter to search: " pick
        
        if [[ -n "$pick" && -n "${history_map[$pick]}" ]]; then
            selected="${history_map[$pick]}"
            play_song "$selected"
        fi
    else
        echo "Welcome, $USERNAME! Let's create your listening history."
        touch "$HISTORY_FILE"
    fi
}

# --- Function to update user history ---
update_history() {
    local song_name=$1
    grep -v "^$song_name$" "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    (echo "$song_name"; cat "$HISTORY_FILE") > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    sed -i '21,$d' "$HISTORY_FILE"
}

# --- Function to play a song and update history ---
play_song() {
    local selected_song=$1
    printf "playing: %s\n" "$selected_song"
    cmatrix & CM_PID=$!
    mpv --no-video "${playlist[$selected_song]}"
    kill $CM_PID
    update_history "$selected_song"
}

# --- Admin Functions ---
add_song() {
    if [[ "$USER_ROLE" != "admin" ]]; then
        echo "Permission Denied. Only admins can add songs."
        sleep 1
        return
    fi
    read -p "Enter song title: " title
    read -p "Enter song URL: " url
    if [[ -z "$title" || -z "$url" ]]; then
        echo "Title and URL cannot be empty."
        sleep 1
        return
    fi
    local last_id=$(tail -n 1 "$SONGS_DB" | cut -d';' -f1)
    local new_id=$((last_id + 1))
    echo "$new_id;$title;$url" >> "$SONGS_DB"
    echo "Song '$title' added."
    load_songs # Reload songs
    sleep 1
}

delete_song() {
    if [[ "$USER_ROLE" != "admin" ]]; then
        echo "Permission Denied. Only admins can delete songs."
        sleep 1
        return
    fi
    read -p "Enter the exact title of the song to delete: " title_to_delete
    if [[ -z "$title_to_delete" ]]; then
        echo "Title cannot be empty."
        sleep 1
        return
    fi

    # Use grep to remove the line with the matching title
    grep -v ";$title_to_delete;" "$SONGS_DB" > "$SONGS_DB.tmp"
    if [ -s "$SONGS_DB.tmp" ]; then
        mv "$SONGS_DB.tmp" "$SONGS_DB"
        echo "Song '$title_to_delete' deleted."
        load_songs # Reload songs
    else
        echo "Song not found or error deleting."
    fi
    sleep 1
}

# --- Main Logic ---

# Load songs from DB at the start
load_songs

handle_user

echo "Welcome to tommyfi"

search_song() {
      read -p "enter the song warrior (or !add, !delete): " song

      # Admin commands
      if [[ "$song" == "!add" ]]; then
          add_song
          search_song
          return
      elif [[ "$song" == "!delete" ]]; then
          delete_song
          search_song
          return
      fi
      
      query=$(tr -d ' ' <<<"$song" | tr '[:upper:]' '[:lower:]' )

      matches=$(for b in "${!playlist[@]}"; do 
         norm=$(tr -d ' ' <<<"$b" | tr '[:upper:]' '[:lower:]'  )
         if [[ "$norm" == *"$query"* ]] then
             printf "%s\n" "$b"
         elif [[ "$song" == "log" ]]; then
             handle_user
         fi 
      done )

      if [[ -z "$matches" ]]; then
         printf "no songs related for '%s',try again.\n " "$song"
         search_song
     elif [[ "$song" == "log" ]]; then
             handle_user
      
      else
         printf "related songs:\n"
         i=1
         declare -A choicemap
         while IFS= read -r track; do
            printf '%2d) %s\n' "$i" "$track"
            choicemap["$i"]="$track"
            ((i++))
         done <<< "$matches"
   
         read -p " Enter the number of song you want to play: " pick
         selected="${choicemap[$pick]}"
         
         if [[ -n "$selected" ]]; then
            play_song "$selected"
         else
            python rickrollplayer.py
            echo "welcome warrior! ! !"
         fi
      fi
      search_song
}

search_song

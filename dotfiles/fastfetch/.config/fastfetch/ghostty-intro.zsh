#!/bin/zsh

emulate -L zsh
setopt local_options no_aliases

config_dir=${0:A:h}
frames_file="$config_dir/ghostty-full-frames.gz.b64"
in_alt_screen=0

command -v fastfetch >/dev/null 2>&1 || exit 0

cleanup_animation() {
  if (( in_alt_screen )); then
    printf '\e[?2026l\e[0m\e[?25h\e[?1049l'
    in_alt_screen=0
  fi
}

# Play official frames 50-200 (151 frames) at 100x41.
# Smaller panes skip directly to Fastfetch.
if (( ${COLUMNS:-0} >= 100 && ${LINES:-0} >= 41 )) \
  && [[ -r $frames_file ]]; then
  frame_data=$(base64 -D < "$frames_file" | gzip -dc 2>/dev/null)

  if [[ -n $frame_data ]]; then
    typeset -a frames frame_lines
    frames=("${(@ps:\x01:)frame_data}")
    top=$(( (LINES - 41) / 2 ))
    left=$(( (COLUMNS - 100) / 2 + 1 ))

    trap cleanup_animation EXIT INT TERM HUP
    printf '\e[?1049h\e[?25l\e[2J'
    in_alt_screen=1

    for frame in "${frames[@]}"; do
      frame_lines=("${(@f)frame}")

      # Synchronized output prevents partially drawn frames from flashing.
      printf '\e[?2026h\e[H'
      (( top > 0 )) && printf '\e[%dB' "$top"

      for (( row = 1; row <= 41; ++row )); do
        printf '\e[%dG%s' "$left" "${frame_lines[$row]}"
        (( row < 41 )) && printf '\r\n'
      done

      printf '\e[?2026l'

      # Approximately 30 FPS. Any key skips to the static banner.
      key=''
      read -r -s -k 1 -t 0.030 key && break
    done

    cleanup_animation
    trap - EXIT INT TERM HUP
  fi
fi

# The animation never shares the Fastfetch layout; this is a fresh static draw.
printf '\e[2J\e[H'
fastfetch --config "$config_dir/config.jsonc"

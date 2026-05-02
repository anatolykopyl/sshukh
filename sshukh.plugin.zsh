# ------------------------------------------------------------------------------
# Description
# -----------
#
# User will be prompted if they want to update known_hosts if ssh errors out
# with "Host key verification failed."
#
# ------------------------------------------------------------------------------
# Authors
# -------
#
# * Anatoly <akopyl@radner.ru>
#
# ------------------------------------------------------------------------------

# OpenSSH prints "<keytype> host key for <host> has changed." — use that host
# for ssh-keygen -R (correct for SSH config Host aliases that resolve to IPs).
_sshukh_offending_host_from_output() {
  print -r -- "$1" | command grep -E -m1 ' host key for .+ has changed' | command sed -E 's/.* host key for ([^ ]+) has changed.*/\1/'
}

# Walk ssh argv like ssh(1): options first, then destination [command ...].
# Sets _sshukh_prefix (options only) and _sshukh_dest (user@host or alias).
_sshukh_split_ssh_args() {
  local i a
  local -a args
  args=("$@")
  _sshukh_prefix=()
  _sshukh_dest=""

  i=1
  while (( i <= $#args )); do
    a="${args[i]}"
    case $a in
      --)
        _sshukh_prefix+=("$a")
        (( i++ ))
        (( i <= $#args )) || return 1
        _sshukh_dest="${args[i]}"
        return 0
        ;;
      -[46AaCfGgKkMNnqsTtVvXxYy])
        _sshukh_prefix+=("$a")
        ;;
      -v*)
        _sshukh_prefix+=("$a")
        ;;
      -B|-b|-c|-E|-e|-F|-I|-i|-J|-L|-l|-m|-O|-P|-p|-Q|-R|-S|-W|-w)
        _sshukh_prefix+=("$a")
        (( i++ ))
        (( i <= $#args )) || return 1
        _sshukh_prefix+=("${args[i]}")
        ;;
      -D)
        _sshukh_prefix+=("$a")
        (( i++ ))
        (( i <= $#args )) || return 1
        _sshukh_prefix+=("${args[i]}")
        ;;
      -D*|-B*|-b*|-c*|-E*|-e*|-F*|-I*|-i*|-J*|-L*|-l*|-m*|-O*|-P*|-p*|-Q*|-R*|-S*|-W*|-w*)
        _sshukh_prefix+=("$a")
        ;;
      -o)
        _sshukh_prefix+=("$a")
        (( i++ ))
        (( i <= $#args )) || return 1
        _sshukh_prefix+=("${args[i]}")
        ;;
      -o*)
        _sshukh_prefix+=("$a")
        ;;
      -*)
        _sshukh_prefix+=("$a")
        ;;
      *)
        _sshukh_dest="$a"
        return 0
        ;;
    esac
    (( i++ ))
  done
  return 1
}

# Hostnames to try with ssh-keygen -R: offending line from ssh, then config
# alias / canonical names from ssh -G (covers known_hosts under IP vs name).
_sshukh_hosts_for_keygen() {
  local output h stripped dest canon hostpat gout
  output="$1"
  shift

  typeset -U hosts
  hosts=()

  h=$(_sshukh_offending_host_from_output "$output")
  [[ -n "$h" ]] && hosts+=("$h")

  if _sshukh_split_ssh_args "$@"; then
    dest="$_sshukh_dest"
    stripped="${dest#*@}"
    [[ "$stripped" == "$dest" ]] && stripped="$dest"
    [[ -n "$stripped" ]] && hosts+=("$stripped")

    gout=$(\ssh -G "${_sshukh_prefix[@]}" "$dest" 2>/dev/null) || gout=""
    if [[ -n "$gout" ]]; then
      canon=$(print -r -- "$gout" | command awk '/^hostname / { print $2; exit }')
      hostpat=$(print -r -- "$gout" | command awk '/^host / { print $2; exit }')
      [[ -n "$canon" ]] && hosts+=("$canon")
      [[ -n "$hostpat" ]] && hosts+=("$hostpat")
    fi
  fi

  print -rl -- "${hosts[@]}"
}

sshukh () {
  local output error host

  output=$(\ssh "$@" 2>&1 | tee /dev/tty)
  error=$(print -r -- "$output" | tail -n1)

  if [[ "$error" != *"Host key verification failed"* ]]; then
    return 0
  fi

  while true; do
    read yn"?Update known_hosts? [y/n] "
    case $yn in
      [Yy]* )
        while IFS= read -r host; do
          [[ -z "$host" ]] && continue
          \ssh-keygen -R "$host" 2>/dev/null
        done < <(_sshukh_hosts_for_keygen "$output" "$@")

        \ssh "$@"
        break
        ;;
      [Nn]* ) break;;
      * ) echo "Please answer y or n.";;
    esac
  done
}

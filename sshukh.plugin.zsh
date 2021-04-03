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

sshukh () {
  output=$(\ssh "$@")
  if [ $? -eq 255 ];
  then
    host=$(cut -d'@' -f2 <<< $1)
    while true; do
      read yn"?Update known_hosts? [y/n] "
      case $yn in
        [Yy]* ) ssh-keygen -R $host && \ssh "$@"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
      esac
    done
  fi
}

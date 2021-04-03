sshukh () {
  output=$(ssh "$@")
  if [ $? -eq 255 ];
  then
    host=$(cut -d'@' -f2 <<< $1)
    while true; do
      read -p "Update known_hosts? [y/n] " yn
      case $yn in
        [Yy]* ) ssh-keygen -R $host && ssh "$@"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
      esac
    done
  fi
}

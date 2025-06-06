# name the device

read -p "Set host, localhost, and device name? [Y/n]: " set_name_choice
set_name_choice=${set_name_choice:-Y}

if [[ "$set_name_choice" =~ ^[Yy]$ ]]; then
  model_name=$(system_profiler SPHardwareDataType | grep "Model Name" | awk -F ": " '{print $2}')
  short_model_name=$(echo $model_name | grep -o '[A-Z]' | tr '[:upper:]' '[:lower:]' | tr -d '\n')
  model_identifier=$(sysctl hw.model | awk -F ": " '{print $2}')
  identifier_numbers=$(echo $model_identifier | grep -o '[0-9]' | tr -d '\n')
  serial_number_last4=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F \" '/IOPlatformSerialNumber/{print substr($(NF-1), length($(NF-1)) - 3)}')
  DEVICE_NAME=$short_model_name$identifier_numbers-$serial_number_last4
  read -p "Enter name [$DEVICE_NAME]: " device_name_input
  DEVICE_NAME=${device_name_input:-$DEVICE_NAME}

  sudo scutil --set HostName $DEVICE_NAME
  sudo scutil --set LocalHostName $DEVICE_NAME
  sudo scutil --set ComputerName $DEVICE_NAME
  echo "Set host, localhost, and device names to $(scutil --get HostName)"
else
  echo "Skipped naming."
fi


# setup xcode tools (git)

# https://forums.developer.apple.com/forums/thread/698954?answerId=723615022#723615022
xcode-select -p &> /dev/null
echo "Installing Xcode Command Line Tools..." 
if [ $? -ne 0 ]; then
  echo "Command Line Tools for Xcode not found."
  xcode-select --install &> /dev/null
  echo "Waiting for Command Line Tools for Xcode to be installed…"
  until $(xcode-select --print-path &> /dev/null); do
    sleep 5;
  done
  echo "Command Line Tools for Xcode installed."
else
  echo "Command Line Tools for Xcode already installed."
fi


# bootstrap into cloning GitHub

read -p "Set up SSH keys for GitHub? [Y/n]: " bootstrap_github
bootstrap_github=${bootstrap_github:-Y}

if [[ "$bootstrap_github" =~ ^[Yy]$ ]]; then
  read -p "Enter your Github account email: " GITHUB_EMAIL

  mkdir -p "$HOME/.ssh"
  GITHUB_KEY_PATH="$HOME/.ssh/github:$GITHUB_EMAIL"
  ssh-keygen -t ed25519 -C $GITHUB_EMAIL -f "$GITHUB_KEY_PATH" -P ""

  eval "$(ssh-agent -s)"
  ssh-add --apple-use-keychain $GITHUB_KEY_PATH

  SSH_CONFIG_PATH="$HOME/.ssh/config"
  touch $SSH_CONFIG_PATH
  if grep -q "$GITHUB_KEY_PATH" "$SSH_CONFIG_PATH"; then
    echo "Path already added to ssh config. [$SSH_CONFIG_PATH]"
  else
    printf "Host github.com\n  HostName github.com\n  AddKeysToAgent yes\n  IdentityFile $GITHUB_KEY_PATH\n" >> "$SSH_CONFIG_PATH"
    echo "Added identity to ssh config. [$SSH_CONFIG_PATH]"
  fi

  git config --global user.signingkey "$GITHUB_KEY_PATH.pub"

  pbcopy < "$GITHUB_KEY_PATH.pub"
  echo "Copied new SSH public key to clipboard."
  echo "Add this as an 'authentication key' for SSH key access to Github."
  echo "Optionally, also add this same key as a 'signing key' for verified commits."
  read -rsn1 -p "Press any key to open Github..."; echo
  open "https://github.com/settings/ssh/new"
  read -rsn1 -p "Once added, press any key to continue..."; echo

  echo "Testing GitHub SSH authentication..."
  test_output=$(ssh -T git@github.com 2>&1)
  SSH_EXIT=$?
  if echo "$test_output" | grep -q "successfully authenticated"; then
    echo "Successfully authenticatied with GitHub."
  else
    echo "Failed to authenticate with GitHub, exiting."
    echo "$test_output"
    exit 1
  fi
else
    echo "Skipped GitHub bootstrapping."
fi

echo "Done bootstrap." 

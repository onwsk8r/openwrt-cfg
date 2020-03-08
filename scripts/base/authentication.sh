#!/usr/bin/env bash
# Set the root password and SSH keys
# https://openwrt.org/docs/guide-user/base-system/dropbear
# **** DROPBEAR DOES NOT SUPPORT ED25519 KEYS
# VARIABLES:
# ROOT_PW root password (required), also used for LuCi
# ROOT_KEYS SSH keys for root user, if desired. Disables root SSH login otherwise.
# WAN_SSH if -n, adds dropbear listener on WAN interface port 22222
# USERNAME specifies a non-root user to add (with sudo) if desired
# USERPW gives that user a password
# USERKEYS lets him log in via SSH. This or the above should probably be set.

## --- Set the root password
test -z "$ROOT_PW" && (
    echo "Root password must be set"
    exit 1
)

echo "Setting root password"
passwd <<EOF
$ROOT_PW
$ROOT_PW
EOF

## --- Disable password authentication and WAN listener
echo "Disabling SSH password auth and remote access"
TARGET='dropbear.@dropbear[0]'
uci batch <<EOF
    set $TARGET.PasswordAuth='off'
    set $TARGET.RootPasswordAuth='off'
    set $TARGET.Interface='lan'
EOF

## --- Add SSH keys for root, if any, otherwise disable root login
if [ -n "$ROOT_KEYS" ]; then
    echo "Setting root SSH keys"
    echo $ROOT_KEYS >> /etc/dropbear/authorized_keys
else
    echo "Disabling root SSH login"
    uci set $TARGET.RootLogin="off"
fi
uci commit $TARGET

## --- Enable remote SSH access, if desired
# TODO verify that this actually works
if [ -n "$WAN_SSH" ]; then
    echo "Adding Dropbear WAN listener"
    SRC="$TARGET" # Will copy from lan interface settings above

    # Check for existing wan listener, else add a new dropbear
    TARGET=$(uci show dropbear | awk -F. '/Interface='"'"wan"'"'/ { print $2 }')
    if [ -z "$TARGET" ]; then
        uci add dropbear dropbear
        TARGET="@dropbear[-1]"
    fi

    # Set new settings based on old settings, with a couple of changes...
    while read -r line; do
        echo "dropbear.${TARGET}.$line";
    done <  <(uci show $SRC | cut -s -d. -f3- | sed -e '/^$/d' -e '/^Port/s/[0-9]\{1,\}/22222/' -e '/^Interface/s/lan/wan/')
    uci commit $TARGET
else
    echo "Skipping Dropbear WAN listener..."
fi

if [ -z "$SSH_CONNECTION" ]; then
    /etc/init.d/dropbear restart
else
    echo "** DROPBEAR NOT RESTARTED BECAUSE YOU ARE CONNECTED VIA SSH"
fi

## --- Add a non-root user with sudo
if [ -n "$USERNAME" ]; then
    opkg install shadow-useradd shadow-groupadd sudo
    groupadd --system sudo
    grep '%sudo' /etc/sudoers | cut -c3- > /etc/sudoers.d/sudo
    mkdir -p /home
    useradd -d "/home/$USERNAME" -G sudo -s "/bin/bash" -mU  $USERNAME

    test -n "$USERPW" && passwd $USERNAME <<EOF
$USERPW
$USERPW
EOF

    if [ -n "$USERKEYS" ]; then
        SSH_DIR="/home/${USERNAME}/.ssh"
        mkdir -p $SSH_DIR
        chmod 700 $SSH_DIR

        echo -en "$USERKEYS" > ${SSH_DIR}/authorized_keys
        chmod 600 ${SSH_DIR}/authorized_keys

        chown -R ${USERNAME}:${USERNAME} $SSH_DIR
    fi
fi

#!/bin/bash

# Author:  Persi.Liao <xiangchu.liao AT gmail.com>
#
# Notes: Linux Took Kit
#
# Project home page:
#    https://github.com/persiliao/ltk

cd "$(dirname "$0")" || {
  fmt_error "You do not have permission to do this.";
  exit 1;
}

LTK_DIRECTORY="$(pwd)"

. "${LTK_DIRECTORY}/include/bootstrap.sh"

# Check if user is root
if ! is_root; then
  fmt_error "You must be ${FMT_GREEN}root${FMT_RESET} ${FMT_RED}to run this script.";
  exit 1;
fi

LTK_LOGIN_USER=$(id -u -n)

setup_optimize_sshd_config() {
  if command_exists sshd; then
    ! grep -q ^Port /etc/ssh/sshd_config && LTK_CURRENT_SSH_PORT=22 || LTK_CURRENT_SSH_PORT=$(grep ^Port /etc/ssh/sshd_config | awk '{print $2}' | head -1)
  else
    fmt_error "You have not installed sshd."
    return 1
  fi

  fmt_tips "Do you want to change your SSH port(Current port: ${LTK_CURRENT_SSH_PORT})? [Y/n] "
  read -r opt
  case $opt in
    y*|Y*|"") LTK_OPT_OPTIMIZE_SSHD_CONFIG=1;;
    n*|N*) fmt_notice "Optimize sshd config skipped."; return ;;
    *) fmt_notice "Invalid choice. Optimize sshd config skipped."; return ;;
  esac

  while :; do
    fmt_tips "Please input SSH port: "
    read -r LTK_NEW_SSH_PORT
    LTK_NEW_SSH_PORT=${LTK_NEW_SSH_PORT:-${LTK_CURRENT_SSH_PORT}}
    if [ "${LTK_NEW_SSH_PORT}" -eq 22 ] || [ "${LTK_NEW_SSH_PORT}" -gt 1024 ] && [ "${LTK_NEW_SSH_PORT}" -lt 65535 ]; then
      break
    else
      fmt_error "SSH port input error, Input range: 22,1025~65534"
    fi
  done

  if ! grep -q ^Port /etc/ssh/sshd_config; then
    sed -i "s@^#Port.*@Port ${LTK_NEW_SSH_PORT}@" /etc/ssh/sshd_config
  elif grep -q ^Port /etc/ssh/sshd_config; then
    sed -i "s@^Port.*@Port ${LTK_NEW_SSH_PORT}@" /etc/ssh/sshd_config
  fi

  if ! grep -q ^ClientAliveInterval /etc/ssh/sshd_config; then
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
  fi

  if ! grep -q ^ClientAliveCountMax /etc/ssh/sshd_config; then
    echo "ClientAliveCountMax 10" >> /etc/ssh/sshd_config
  fi

  fmt_information "New SSH port: ${FMT_RED}${LTK_NEW_SSH_PORT}${FMT_RESET}"
}

setup_set_ssh_pubkey_login() {
  echo
  if command_exists sshd; then
    printf '%sDo you want to set SSH public key login? [Y/n]%s ' \
            "${FMT_YELLOW}" "${FMT_RESET}"
    read -r opt
    case $opt in
      y*|Y*|"") LTK_OPT_SET_SSH_PUBKEY_LOGIN=1;;
      n*|N*) fmt_notice "SSH public key login skipped."; return ;;
      *) fmt_notice "Invalid choice. SSH public key login skipped."; return ;;
    esac
  else
    fmt_error "You have not installed sshd."
    return 1
  fi

  printf 'What Are You Doing?
  %so%s. Use your own SSH public Key
  %sn%s. Use generate new SSH key \n' \
  "${FMT_YELLOW}" "${FMT_RESET}" "${FMT_YELLOW}" "${FMT_RESET}"
  fmt_tips "Please input the correct option: "
  read -r opt
  case $opt in
    o*|O*) LTK_OPT_SSH_PUBLIC_KEY_USE='o' ;;
    n*|N*) LTK_OPT_SSH_PUBLIC_KEY_USE='n' ;;
    *) fmt_notice "Invalid choice. SSH public key login skipped."; return ;;
  esac

  if [ "${LTK_OPT_SSH_PUBLIC_KEY_USE}" = 'o' ]; then
    LTK_SSH_DEFAULT_PUBLIC_KEY="${LTK_DIRECTORY}/key/login.pub"
    while :; do echo
      read -p "${FMT_YELLOW}Please input the SSH public key path(Default ${LTK_SSH_DEFAULT_PUBLIC_KEY}): ${FMT_RESET}" -r LTK_SSH_PUBLIC_KEY_PATH
      if [ "${LTK_SSH_PUBLIC_KEY_PATH}" = "" ]; then
        LTK_SSH_PUBLIC_KEY_PATH="${LTK_SSH_DEFAULT_PUBLIC_KEY}"
      fi

      if [ ! -f "${LTK_SSH_PUBLIC_KEY_PATH}" ]; then
        fmt_error "SSH public key file ${LTK_SSH_PUBLIC_KEY_PATH} not exist."
      else
        break
      fi
    done
  elif [ "${LTK_OPT_SSH_PUBLIC_KEY_USE}" = 'n' ]; then
    get_user_home_dir "${LTK_LOGIN_USER}"
    generate_random_str
    LTK_SSH_PRIVATE_KEY_PATH="${LTK_USER_HOME}/${LTK_RANDOM_STR}"
    fmt_notice "Start generating the SSH login key..."

    if ! generate_ssh_key "${LTK_SSH_PRIVATE_KEY_PATH}"; then
      fmt_error "Generate SSH key failed."
      return 1
    else
      LTK_SSH_PUBLIC_KEY_PATH="${LTK_SSH_PRIVATE_KEY_PATH}.pub"
    fi
  fi

  if deploy_ssh_public_key "${LTK_LOGIN_USER}" "${LTK_SSH_PUBLIC_KEY_PATH}"; then
    fmt_information "Deploy SSH public key login successfully."
    fmt_notice "SSH Key information"
    fmt_information "SSH Public Key: ${LTK_SSH_PUBLIC_KEY_PATH}"
    if [ "${LTK_OPT_SSH_PUBLIC_KEY_USE}" = "n" ]; then
      fmt_information "SSH Private Key: ${LTK_SSH_PRIVATE_KEY_PATH}"
    fi
  fi

  echo
  fmt_tips 'Do you want to set SSH to allow only public key login? [Y/n] '
  read -r opt
  case $opt in
    y*|Y*|"") ;;
    n*|N*) fmt_notice "SSH allow only public key login skipped."; return ;;
    *) fmt_notice "Invalid choice. SSH allow only public key login skipped."; return ;;
  esac

  LTK_PERMIT_ROOT_LOGIN_VALUE="without-password"
  if ! grep -q ^PermitRootLogin /etc/ssh/sshd_config; then
    sed -i "s@^#PermitRootLogin.*@PermitRootLogin ${LTK_PERMIT_ROOT_LOGIN_VALUE}@" /etc/ssh/sshd_config
  elif grep -q ^PermitRootLogin /etc/ssh/sshd_config; then
    sed -i "s@^PermitRootLogin.*@PermitRootLogin ${LTK_PERMIT_ROOT_LOGIN_VALUE}@" /etc/ssh/sshd_config
  fi

  # shellcheck disable=SC2181
  if [ $? -eq 0 ]; then
    fmt_information "The setting is successfully, the current server SSH only allows public key login."
    if [ "${LTK_OPT_SSH_PUBLIC_KEY_USE}" = "n" ]; then
      fmt_information "Please keep the generated private key strictly. ${FMT_RED}Private key path: ${LTK_SSH_PRIVATE_KEY_PATH}"
    fi
  fi
}

setup_add_www_user_group() {
  # Add a default user group to run the web application
  if ! grep -q www /etc/group; then
    if groupadd -f www; then
      echo
      fmt_information "User group [www] created successfully."
    fi
  fi
}

setup_add_cicd_deploy_user() {
  # Add a user for remote continuous deployment
  echo
  fmt_tips "Do you want to add a remote deployment account? [Y/n] "
  read -r opt
  case $opt in
    y*|Y*|"") LTK_OPT_ADD_REMOTE_DEPLOYMENT_ACCOUNT=1;;
    n*|N*) fmt_notice "Add remote deployment account skipped."; return ;;
    *) fmt_notice "Invalid choice. Add remote deployment account skipped."; return ;;
  esac

  LTK_DEFAULT_DEPLOYER_USER="deployer"
  fmt_tips "Please input user name(Default: deployer): "
  read -r LTK_DEPLOYER_USER
  if [ -z "${LTK_DEPLOYER_USER}" ]; then
    LTK_DEPLOYER_USER=${LTK_DEFAULT_DEPLOYER_USER}
  fi

  printf 'Which method do you want to use to login?
    %sp%s. Use your password to login
    %sk%s. Use own SSH public Key to login \n' \
    "${FMT_YELLOW}" "${FMT_RESET}" "${FMT_YELLOW}" "${FMT_RESET}"
  fmt_tips "Please input the correct option: "
  read -r opt
  case $opt in
    p*|P*) LTK_DEPLOYER_LOGIN_METHOD="p" ;;
    k*|K*) LTK_DEPLOYER_LOGIN_METHOD="k" ;;
    *) fmt_notice "Invalid choice. ${LTK_DEPLOYER_USER} login skipped."; return ;;
  esac

  useradd -N -g www -c "CI/CD Deployer" ${LTK_DEPLOYER_USER}

  if [ "${LTK_DEPLOYER_LOGIN_METHOD}" = "p" ]; then
    generate_password 32
    LTK_DEPLOYER_PASSWORD="${LTK_NEW_PASSWORD}"
    if ! usermod -p "${LTK_DEPLOYER_PASSWORD}" "${LTK_DEPLOYER_USER}"; then
      fmt_error "Failed to set the user password."
      exit 1
    else
      fmt_information "Deployer user: ${LTK_DEPLOYER_USER}"
      fmt_information "Deployer password: ${LTK_DEPLOYER_PASSWORD}"
    fi
  elif [ "${LTK_DEPLOYER_LOGIN_METHOD}" = "k" ]; then
    generate_ssh_key
  fi
}

setup_systemctl_service_restart() {
  if [ ${LTK_OPT_OPTIMIZE_SSHD_CONFIG} -eq 1 ] || [ ${LTK_OPT_SET_SSH_PUBKEY_LOGIN} -eq 1 ] || [ ${LTK_OPT_ADD_REMOTE_DEPLOYMENT_ACCOUNT} -eq 1 ]; then
    systemd_service_restart "sshd.service"
  fi
}

main() {
  setup_optimize_sshd_config
  setup_set_ssh_pubkey_login
  setup_add_www_user_group
  setup_add_cicd_deploy_user
}

main "$@"

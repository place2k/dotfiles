edit() {
  show_help() {
    echo 'ARGUMENT                       FILE TO BE EDITED'
    echo '----------------------         --------------------------------------------------------------------------------------------------------'
    echo 'applets                        ~/.config/plasma-org.kde.plasma.desktop-appletsrc. Restarts plasmashell after editing.'
    echo 'cpio [reboot|poweroff]          /etc/mkinitcpio.conf. The initcpio is regenerated with all presets.'
    echo '                                If `reboot` or `poweroff` is specified afterwards, the corresponding action is performed post confirmation.'
    echo 'cpiopre [fall]                  /etc/mkinitcpio.d/linux.preset, or /etc/mkinitcpio.d/linux-lts.preset if `fall` (fallback)  is given.'
    echo '                                The initcpio is regenerated with the corresponding preset.'
    echo 'cpupower                        /etc/default/cpupower.'
    echo 'crypt                           /etc/crypttab.'
    echo 'env                             /etc/environment.'
    echo 'fstab                           /etc/fstab.'
    echo 'jdnotif                        ~/.config/journalctl-desktop-notification.'
    echo 'kcmdl [fall|both]               /etc/kernel/cmdline, or /etc/kernel/fallback-cmdline if 'fall' is given, or both files if 'both' is given.'
    echo 'kinit [reboot|poweroff]         /etc/kernel/cmdline, /etc/kernel/fallback-cmdline, and /etc/mkinitcpio.conf. Arguments are as for `cpio` above.'
    echo 'locale                          /etc/locale.conf. locale.sh is sourced afterwards.'
    echo 'locgen                          /etc/locale.gen. locale-gen is invoked afterwards.'
    echo 'login                           /etc/login.defs.'
    echo 'makepkg                         /etc/makepkg.conf'
    echo 'pacman                          /etc/pacman.conf.'
    echo 'pam                             /etc/security/pam_env.conf.'
    echo 'paru                            /etc/paru.conf.'
    echo 'prof                            /etc/profile. The shell is reloaded afterwards if it is a login shell.'
    echo 'sddm                            /etc/sddm.conf.d/kde_settings.conf'
    echo 'sudo                            /etc/sudoers through visudo.'
    echo "sysctl [new | -d | -D] <file>   A .conf file in /etc/sysctl.d, determined by <file> ($(dir /etc/sysctl.d | sed -re 's/.conf(  )?/|/g;s/\|$//'))."
    echo '                                If <file> is not specified, all files will be edited. If `new` is specified before it, a new file is created.'
    echo '                                With `-d`, the given file and its backup copy are deleted, or if none is given, all will be (with confirmation).'
    echo '                                With `-D`, the sysctls in the given file and its backup copy are reverted to their original default values.'
    echo 'vim                             ~/vimrc.'
    echo
    echo 'Arguments are case-insensitive. Every edited file is backed up after a successful (zero exit status) edit.'
    echo 'The special argument `-h` shows this help message.'
    echo 'If no argument is given, the edit function itself (at ~/.edit.zsh) is edited; a login shell will be reloaded afterwards.'
    echo 'The special argument `-g` can be used to edit ~/.edit.zsh with a GUI text editor.'
  }

  if [[ -z $1 || $1 == -g ]]; then
    local efname=.edit.zsh
    local efile=$HOME/$efname
    [[ $1 != -g ]] && local editcmd=$EDITOR || local editcmd=kwrite
    $editcmd $efile && hashcmp -n $_ $ZSHBK/$efname && cp $efile $ZSHBK && unfunction $0 && source $efile
    return
  elif [[ $1 == -h ]]; then
    show_help
    return
  fi

  do_logout() { qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout }

  confirm_exit() {
    local action=$1
    [[ $action == 'Log out' ]] && ! gui_running && return

    printf "$action now? (y/n) "
    read -qr
    echo

    if [[ $REPLY == y ]]; then
      local err_msg="$funcstack[2]: invalid action: $action"
      case $action in
        'Reboot') reboot;;
        'Power off') poweroff;;
        'Log out') do_logout;;
        *) echo $err_msg >&2 && return 1;;
      esac
    fi
  }

  confirm_poweroff() { confirm_exit 'Power off' }
  confirm_reboot()   { confirm_exit 'Reboot'    }
  confirm_logout()   { confirm_exit 'Log out'   }

  handle_applets() {
    parent=$HOME/.config/
    fpath=plasma-org.kde.plasma.desktop-appletsrc
    editcmd="$EDITOR"
    gui_running && editcmd="/usr/bin/kwrite BNUL"
    bkupcmd="/usr/bin/cp -ru \$_ $QB/configuration/plasma"
    postcmd='pkill plasmashell && kstart plasmashell BNUL &!'
  }

  mkic() { sudo mkinitcpio $@ >/dev/null &! }

  rebooting_or_powering_off() {
    if [[ -n $arg ]]; then
      if [[ $arg == reboot || $arg == poweroff ]]; then
        reboot_or_poweroff=true
        pwrcmd=$arg
        (( ++next ))
      else
        echo "$arg: invalid argument." >&2
        return 1
      fi
    fi
  }

  handle_cpio() {
    fpath=mkinitcpio.conf
    postcmd='mkic -P'
    rebooting_or_powering_off
  }

  handle_cpiopre() {
    parent=/etc/mkinitcpio.d/
    if [[ $arg == fall ]]; then
      fpath=$linux_other.preset
      postcmd='mkic -p $linux_other'
      (( ++next ))
    else
      fpath=$linux_main.preset
      postcmd='mkic -p $linux_main'
    fi
  }

  handle_jdnotif() {
    parent=$HOME/.config/
    fpath=journalctl-desktop-notification.conf
    editcmd=$EDITOR
    bkupcmd='cp $_ $QB/configuration/app-data'
  }

  handle_kcmdl() {
    parent=/etc/kernel/
    if [[ -z $arg ]]; then
      fpath=cmdline
      postcmd='mkic -p $linux_main'
    else
      if [[ $arg == fall ]]; then
        fpath=fallback-cmdline
        postcmd='mkic -p $linux_other'
      elif [[ $arg == both ]]; then
        fpath='{,fallback-}cmdline'
        bkupcmd="etcbkp $parent$fpath"
        postcmd='mkic -P'
      else
        echo "$arg: invalid argument." >&2
        return 1
      fi
      (( ++next ))
    fi
  }

  handle_kinit() {
    fpath='{mkinitcpio.conf,kernel/{,fallback-}cmdline}'
    bkupcmd="etcbkp $fpath"
    postcmd='mkic -P'
    rebooting_or_powering_off
  }

  handle_sysctl() {
    if [[ -z $arg ]]; then
      unset parent
      fpath='$(echo /etc/sysctl.d/*.conf)'
      bkupcmd='etcbkp sysctl.d'
      postcmd='sudo sysctl -p /etc/sysctl.d/*.conf'
    else
      file=$@[$((next += 2))]
      nofile=true
      [[ -n $file ]] && nofile=false && (( next += 3 ))

      if [[ $arg == -d ]]; then
        if $nofile; then
          unset parent bkupcmd
          read -qr '?Delete all sysctl files? (y/n) ' && echo
          if [[ $REPLY == y ]]; then
            fpath='/etc/sysctl.d/*'
            editcmd='sudo rm -fv'
            bkupcmd="$editcmd $PBETC/sysctl.d/*"
            postcmd='sysctl-defaults reset all'
          else
            editcmd='echo Canceled.'
          fi
        else
          fpath=sysctl.d/$file.conf
          editcmd='sudo rm -fv'
          bkupcmd="$editcmd $PBETC/sysctl.d/$file.conf"
          postcmd='sysctl-defaults reset $file'
        fi
      elif [[ $arg == -D ]]; then
        unset parent bkupcmd
        if $nofile; then
          read -qr '?Restore all sysctl files to their defaults? (y/n) ' && echo
          if [[ $REPLY == y ]]; then
            editcmd='sysctl-defaults restore all'
            bkupcmd='sysctl-defaults backup  all'
          else
            editcmd='echo Canceled.'
          fi
        else
          editcmd='sysctl-defaults restore $file'
          bkupcmd='sysctl-defaults backup  $file'
        fi
      else
        newfile=false
        [[ $arg == new ]] && newfile=true && arg=$file
        fpath=sysctl.d/$arg.conf
        postcmd='sudo sysctl -p $_'
      fi

      if [[ ! -e $parent$fpath ]] && ! $newfile; then
        show_help; echo
        echo "Invalid argument: \"$arg\"." >&2
        return 1
      fi
    fi
  }

  handle_vim() {
    parent=$HOME/
    fpath=.vimrc
    editcmd="$EDITOR"
    bkupcmd="cp -ru \$_ $QB/configuration/vim/.vimrc"
  }


  # variable declarations in processing order, that is to say, the order by which they are processed by this script and appear in the cmd string
  # default values initialize them

  local next=1 # index of the next argument in the $@ (command-line arguments) array
  local what arg
  local parent fpath
  local editcmd bkupcmd postcmd
  local reboot_or_poweroff pwrcmd logout cmd
  typeset -a cmd

  typeset -g linux_main=linux-zen linux_other=linux-lts

  while (( next <= $# )); do
    what=$@[$next]           # edit keyword
    arg=$@[$((next+1))]      # argument to keyword
    parent=/etc/             # parent directory of the file to edit; it has to end with '/', for relative-path handling purposes, such as with spt, etcbkp, chroot etc.
    fpath=''                 # file to edit, relative to $parent
    editcmd="svim"           # command to use for editing the fpath associated with the edit keyword
    bkupcmd='etcbkp $_'      # command to run after the editor finishes; intended to save the edited file somewhere
    postcmd=''               # command to run after the backup command; intended to act upon the file modification event in some way
    reboot_or_poweroff=false # whether the edit keyword may receive an argument to reboot or power off the machine after a successful edit is done
    pwrcmd=''                # either 'reboot' or 'poweroff' when not empty; used to call the corresponding confirm_* function
    logout=false             # whether to terminate the current session after a successful edit
    cmd=()                   # full string of the command to run for editing fpath, containing the editor, path, postcmd, and bkupcmd

    [[ ! -z $arg ]] && arg=${(L)arg}

    case ${(L)what} in
      applets) handle_applets;;
      cpio) handle_cpio;;
      cpiopre) handle_cpiopre;;
      cpupower) fpath=default/cpupower-service.conf; postcmd="sudo systemctl restart cpupower";;
      crypt) fpath=crypttab;;
      env) fpath=environment; postcmd='source $_'; logout=true;;
      fstab) fpath=fstab; postcmd='sudo systemctl daemon-reload &!';;
      jdnotif) handle_jdnotif;;
      kcmdl) handle_kcmdl || return 1;;
      kinit) handle_kinit || return 1;;
      locale) fpath=locale.conf; postcmd='source /etc/profile.d/locale.sh';;
      locgen) fpath=locale.gen; postcmd='sudo locale-gen';;
      login) fpath=login.defs;;
      makepkg) fpath=makepkg.conf;;
      pacman) fpath=pacman.conf;;
      pam) fpath=security/pam_env.conf; logout=true;;
      paru) fpath=paru.conf;;
      prof) fpath=profile; postcmd='[[ -o login ]] && rld';;
      sddm) fpath=sddm.conf.d/kde_settings.conf;;
      sudo) unset parent; editcmd='sudo visudo'; bkupcmd='etcbkp sudoers';;
      sysctl) handle_sysctl $@ || return 1;;
      vim) handle_vim;;
      *); show_help; printf "\nUnknown argument \"%s\".\n" "$what" >&2; return 1;;
    esac

    if [[ ! -z $bkupcmd ]]; then
      bkupcmd="&& $bkupcmd"
      [[ ! -z $postcmd ]] && postcmd="&& $postcmd"
    elif [[ ! -z $postcmd ]]; then
      postcmd="&& $postcmd"
    fi

    cmd="$editcmd $parent$fpath $bkupcmd $postcmd"

    if $reboot_or_poweroff; then
      cmd+=" && confirm_$pwrcmd"
    elif $logout; then
      cmd+=" && confirm_logout"
    fi

    eval "$cmd"

    (( ++next ))
  done
}
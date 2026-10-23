# Check whether the Plasma GUI is running, and save the result
gui_running && export GUI_RUNNING=true

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if $GUI_RUNNING && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
export ZSHRC=$HOME/.zshrc

# my zsh aliases management variables
export ZSHAL_NAME=.zsh_aliases.d
export ZSHAL=$HOME/$ZSHAL_NAME

# path to my zsh backup dir
export ZSHBK=$QB/zsh/paulo

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
$GUI_RUNNING && ZSH_THEME=powerlevel10k/powerlevel10k || ZSH_THEME=clean-custom

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
#CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Change autoupdate behavior
zstyle ':omz:update' mode auto # update automatically without asking

# Uncomment the following line to change how often to autoupdate (in days).
zstyle ':omz:update' frequency 7

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command autocorrection.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="%Y-%m-%d %H:%M"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

ZSH_COLORIZE_STYLE="colorful"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  aliases
  colorize
  colored-man-pages
  compleat
  copybuffer
  copyfile
  copypath
  cp
  dircycle
  fast-syntax-highlighting
  pj
  rand-quote
  systemd
  thefuck
  themes
  urltools
  wd
  you-should-use
  zsh-interactive-cd
  zsh-history-substring-search
  zsh-autosuggestions
)

. $ZSH/oh-my-zsh.sh
. /usr/share/doc/find-the-command/ftc.zsh noupdate quiet
. ~/.edit.zsh
[[ -o login ]] && . /etc/profile
[[ $TERM_PROGRAM == vscode ]] && . /usr/share/devin-desktop/resources/app/out/vs/workbench/contrib/terminal/common/scripts/shellIntegration-rc.zsh

# TODO: move these aliases to shalias' basic file after finishing refactoring shalias code
alias -g NUL='>/dev/null'
alias -g ENUL='2>/dev/null'
alias -g BNUL='&>/dev/null' # B for both

(( $+aliases[run-help] )) && unalias run-help
autoload -Uz run-help

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if $GUI_RUNNING; then
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
fi

cdpath=(~/Code ~/Code/Projects ~/Code/QuickCode ~/Code/Projects/C/InProgress)

# my env vars
cat $HOME/.config/environment.d/* | while read ENV; do
  export $ENV
done
export NPROC=$(nproc)
export UV_CACHE_DIR=/mnt/ssd/work/.uv_cache

which fclear &>/dev/null || source /etc/profile

# my custom aliases managed through the shalias script, wrapped and controlled by this function

export shalias_cmdfile=/tmp/.shalias.source
fclear $shalias_cmdfile

function shalias() {
  shalias.zsh $@
  . $shalias_cmdfile
  fclear $shalias_cmdfile
}

# parse aliases files by the proper order
shalias -p

# my setopts

# no_hup: https://stackoverflow.com/a/19303003
# nohistverify: https://stackoverflow.com/q/62185638
setopt extended_glob no_hup nohistverify #dotglob

IFS=$'\n'

# use Ctrl-W to delete whole word backwards until the last space
autoload -U backward-kill-word-match
zle -N backward-kill-word-space backward-kill-word-match
zstyle ':zle:backward-kill-word-space' word-style space
bindkey '^W' backward-kill-word-space

eval "$(uv generate-shell-completion zsh)"


# ====== HEKS-BASH configuration ======
[ -f /etc/bashrc ] && . /etc/bashrc

[[ $- == *i* ]] && source -- ~/.local/share/blesh/ble.sh --attach=none || true|| true

bind "set completion-ignore-case on"

bind "set completion-map-case on"

bind "set show-all-if-ambiguous on"

bind "set mark-symlinked-directories on"

shopt -s autocd 2> /dev/null

shopt -s dirspell 2> /dev/null

shopt -s cdspell 2> /dev/null

GREEN_TEXT="$(tput setaf 2)"

BLUE_TEXT="$(tput setaf 4)"

PURPLE_TEXT="$(tput setaf 5)"

RED_TEXT="$(tput setaf 1)"

RESET_TEXT="$(tput sgr0)"

BOLD_TEXT="$(tput bold)"

SHELL_GREETING_MSG="${PURPLE_TEXT}Hallo, mens. De computer heeft je gemist. (Zoem. Bleep. Beep.)${RESET_TEXT}"

CDPATH="."

HISTSIZE="500000"

HISTFILESIZE="100000"

HISTTIMEFORMAT="%F %T  | "

HISTCONTROL="ignoreboth:erasedups"

PROMPT_COMMAND="history -a"

PROMPT_DIRTRIM="2"

GUIX_PROFILE="$HOME/.guix-profile"

GUIX_LOCPATH="$GUIX_PROFILE/lib/locale"

GH_PACKAGES_USERNAME="jjbavdb"

GH_PACKAGES_TOKEN=""$(gh auth token)""

export PS1="${BOLD_TEXT}\u@\h${RESET_TEXT}: \w${GUIX_ENVIRONMENT:+ [env]}\n${BOLD_TEXT}λ${RESET_TEXT} "

export HISTIGNORE="&:[ ]*:exit:ls:bg:fg:history:clear"

glog () {
	sudo gzip -d "$1.gz" && cat "$1"
}


hgrep () {
	history | grep "$1"
}


include () {
	[[ -f "$1" ]] && source "$1"
}


work-github-actions-version-replacer () {
	find "$1" -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 | xargs -0 sed -i "s#\(uses: Vandebron/github-actions/.*@\).*#\1$2#"
}


shell-greeting () {
	echo "${SHELL_GREETING_MSG}"
echo ""
}


alias ..="cd ..;pwd"

alias ...="cd ../..;pwd"

alias ....="cd ../../..;pwd"

alias c="clear"

alias h="history"

alias tree="tree --dirsfirst -F"

alias mkdir="mkdir -p -v"

alias ll="ls -lAh --group-directories-first"

alias l="ls -lAh --group-directories-first"

alias e="emacsclient -t"

alias k="pkill"

alias fetch="fastfetch"

alias vanilla-emacs="emacs -Q"

alias restart-emacs="pkill emacs && emacs --daemon"

alias fr="cd ~/Hacking/heks-linux && maak reconfigure"

alias direnv-mode="direnv export bash"

alias scala-dev="nix develop ~/Hacking/heks-bash/resources/flakes/scala-dev/"

alias haskell-dev="nix develop ~/Hacking/heks-bash/resources/flakes/haskell-dev/"

alias docker="podman"

alias docker-compose="podman-compose"

alias podman-unix-socket="podman system service --time=0 unix:///tmp/podman.sock"

alias find-largest-files="du -h -x -s -- * | sort -r -h | head -20"

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

export PATH="$HOME/bin:$PATH"

export PATH="$HOME/.guix-profile/bin:$PATH"
shopt -s histappend

shopt -s cmdhist

set -o noclobber

set -o emacs

shopt -s checkwinsize

include /run/current-system/profile/share/bash-completion/bash_completion


maak_bin_install_dir=$(which maak)
maak_install_dir=$(realpath "${maak_bin_install_dir}")
maak_bin=$(dirname "${maak_install_dir}")
maak_store=$(dirname "${maak_bin}")
maak_completions="${maak_store}/share/scripts/maak-completion.bash"


[ -f "${maak_completions}" ] && . "${maak_completions}"

eval "$(fzf --bash)" || true

include /run/current-system/profile/etc/profile.d/nix.sh

shell-greeting

eval "$(direnv hook bash)"

[ -f "$GUIX_PROFILE/etc/profile" ] && . "$GUIX_PROFILE/etc/profile"
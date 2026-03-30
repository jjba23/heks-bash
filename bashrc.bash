
# ====== HEKS-BASH configuration ======
[ -f /etc/bashrc ] && . /etc/bashrc

[[ $- == *i* ]] && source -- ~/.local/share/blesh/ble.sh || true

bind "set completion-ignore-case on"

bind "set completion-map-case on"

bind "set show-all-if-ambiguous on"

bind "set mark-symlinked-directories on"

shopt -s autocd 2> /dev/null

shopt -s dirspell 2> /dev/null

shopt -s cdspell 2> /dev/null

include() {
    [[ -f "$1" ]] && source "$1"
}

include ~/.bash-heks-linux-bridge.bash

export GREEN_TEXT="$(tput setaf 2)"

export RED_TEXT="$(tput setaf 1)"

export RESET_TEXT="$(tput sgr0)"

export BOLD_TEXT="$(tput bold)"

export SHELL_GREETING_MSG="${HEKS_BASH_HIGHLIGHT_TEXT}Hallo, mens. De computer heeft je gemist. (Zoem. Bleep. Beep.)${RESET_TEXT}"

export CDPATH="."

export HISTSIZE="500000"

export HISTFILESIZE="100000"

export HISTTIMEFORMAT="%F %T  | "

export HISTCONTROL="ignoreboth:erasedups"

export HISTIGNORE="&:[ ]*:exit:ls:bg:fg:history:clear"

export PROMPT_COMMAND="history -a"

export PROMPT_DIRTRIM="2"

export PAGER="most"

export MANPAGER="most"

export GUIX_PROFILE="$HOME/.guix-profile"

export GUIX_LOCPATH="$GUIX_PROFILE/lib/locale"

export GH_PACKAGES_USERNAME="jjbavdb"

export GH_PACKAGES_TOKEN=""""

export DOCKER_HOST="unix:///tmp/podman.sock"

export PS1="${BOLD_TEXT}\u@\h${RESET_TEXT}: \w${GUIX_ENVIRONMENT:+ [env]}\n${BOLD_TEXT}λ${RESET_TEXT} "

glog () {
	sudo gzip -d "$1.gz" && cat "$1"
}


hgrep () {
	history | grep "$1"
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

alias cat="bat"

alias vanilla-emacs="emacs -Q"

alias restart-emacs="pkill emacs && emacs --daemon"

alias keys-show="wshowkeys -a top -a right -m 12 -t 1"

alias sr="cd ~/Hacking/heks-linux && maak reconfigure"

alias hr="cd ~/Hacking/heks-linux && maak home-reconfigure"

alias install-dnfs="cd ~/Hacking/heks-linux && maak install-dnfs"

alias install-flatpaks="cd ~/Hacking/heks-linux && maak install-flatpaks"

alias upd="cd ~/Hacking/heks-linux && maak update-flatpaks && maak update-dnfs"

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

export PATH="/usr/bin:$PATH"

export PATH="/usr/sbin:$PATH"
shopt -s histappend

shopt -s cmdhist

set -o noclobber

set -o emacs

shopt -s checkwinsize

include /run/current-system/profile/share/bash-completion/bash_completion

maak_bin_loc=$(command -v maak)

maak_bin_dir=${maak_bin_loc%/*}

maak_install_dir=${maak_bin_dir%/*}

maak_completions="${maak_install_dir}/share/scripts/maak-completion.bash"

include "${maak_completions}"

eval "$(fzf --bash)" || true

include /run/current-system/profile/etc/profile.d/nix.sh

ble-face -s command_builtin fg=purple

ble-face -s command_builtin_dot fg=purple,bold

ble-import -d ~/.local/share/blesh/contrib/integration/fzf-completion.bash

ble-import -d ~/.local/share/blesh/contrib/integration/fzf-key-bindings.bash

eval "$(direnv hook bash)"

[ -f "$GUIX_PROFILE/etc/profile" ] && . "$GUIX_PROFILE/etc/profile"

[[ -z "$GH_PACKAGES_TOKEN" ]] && export GH_PACKAGES_TOKEN="$(gh auth token)" || true

shell-greeting
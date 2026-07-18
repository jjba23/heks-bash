# ====== HEKS-BASH configuration ======
# auto-generated file!

[ -f /etc/bashrc ] && . /etc/bashrc
[[ $- == *i* ]] && source -- ~/.local/share/blesh/ble.sh || true
bind "set completion-ignore-case on"
bind "set completion-map-case on"
bind "set show-all-if-ambiguous on"
bind "set mark-symlinked-directories on"
shopt -s autocd 2> /dev/null
shopt -s dirspell 2> /dev/null
shopt -s cdspell 2> /dev/null
include() { [[ -f "$1" ]] && source "$1"; }
include ~/.bash-heks-linux-bridge.bash


export GREEN_TEXT="$(tput setaf 2)"

export RED_TEXT="$(tput setaf 1)"

export RESET_TEXT="$(tput sgr0)"

export BOLD_TEXT="$(tput bold)"

export CDPATH=".:$HOME/Hacking:$HOME/Work"

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

export GUIX_LOCPATH="$HOME/.guix-profile/lib/locale"

export GH_PACKAGES_USERNAME="jjbavdb"

export GH_PACKAGES_TOKEN=""

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
	local greetings=(
		"Acta non verba. (Daden, geen woorden.)"
		"Alea iacta est. (De teerling is geworpen.)"
		"Memento mori. (Gedenk te sterven.)"
		"Per aspera ad astra. (Via moeilijkheden naar de sterren.)"
		"Veni, vidi, vici. (Ik kwam, ik zag, ik overwon.)"
		"Cogito, ergo sum. (Ik denk, dus ik ben.)"
		"Errare humanum est. (Dwalen is menselijk.)"
		"Si vis pacem, para bellum. (Als je vrede wilt, bereid je dan voor op oorlog.)"
		"Nu breekt mijn klomp!"
		"Hoge bomen vangen veel wind."
		"Gezelligheid kent geen tijd."
		"Met de deur in huis vallen."
		"Beter één vogel in de hand dan tien in de lucht."
		"De soep wordt nooit zo heet gegeten als zij wordt opgediend."
		"Al draagt een aap een gouden ring, het is en blijft een lelijk ding."
		"Je kunt niet van een kale kip plukken."
		"Als de kat van huis is, dansen de muizen op tafel."
		"Welcome back, operator. Systems are nominal."
		"Shall we play a game?"
		"Initiating hackermode..."
		"Wake up, Neo... The Matrix has you."
		"I'm sorry, Dave. I'm afraid I can't do that."
		"Don't panic. And always know where your towel is."
		"All your base are belong to us."
		"Stay awhile and listen!"
		"A vast terminal emptiness awaits your input."
		"There are 10 types of people: those who understand binary, and those who don't."
		"Why do programmers wear glasses? Because they can't C#."
		"Hardware: The parts of a computer system that can be kicked."
		"There are two hard things in computer science: cache invalidation, naming things, and off-by-one errors."
		"To understand recursion, you must first understand recursion."
		"What is a programmer's favorite hangout place? Foo Bar."
		"Algorithm: A word used by programmers when they do not want to explain what they did."
		"Unix is user-friendly. It's just very selective about who its friends are."
		"In the beginning was the command line."
		"Everything is a file, until it's a process."
		"May the source be with you."
		"RTFM: Read The Fine Manual."
		"Pipe it, grep it, sed it, love it."
		"Form follows function, but errors follow shortcuts."
		"Emacs is a magnificent operating system, it just lacks a good text editor."
		"M-x butterfly"
		"Escape Meta Alt Control Shift. Your pinky finger is strong."
		"C-x C-s. Your progress is saved. Your soul is secure."
		"Welcome to the Church of Emacs. Emacs is my editor, and GNU is its operating system."
		"Living in the buffers since inception."
		"GNU's Not Unix! Welcome to the recursive revolution."
		"Free software is a matter of liberty, not price. Think free speech, not free beer."
		"You are entering a 100% libre user space."
		"Guile, Guix, and Glory. Welcome to the GNU system."
		"Join us now and share the software; You'll be free, hackers, you'll be free."
		"Happy Hacking!"
		"There is no system but GNU, and Linux is one of its kernels."
		"If we do not control our software, our software controls us."
		"Proprietary software is a social problem. Keep your system clean."
		"With digital technology, sharing is easy. Sharing is good."
		"The sky above the port was the color of television, tuned to a dead channel."
		"High tech, low life. Welcome back to the sprawl."
		"Data is the new neon. Go get it."
		"Jack in. Boot up. Clean the cache."
		"The matrix is nothing but a spark in the dark."
		"You have power over your mind - not outside events. Realize this, and you will find strength."
		"We suffer more often in imagination than in reality."
		"The best revenge is to be unlike him who performed the injury."
		"Control your inputs; master your outputs."
		"Amor Fati: Love your fate, for it is your life."
		"Hallo, mens. De computer heeft je gemist. (Zoem. Bleep. Beep.)"
	)
	local size=${#greetings[@]}
	local index=$((RANDOM % size))
	echo -e "${BOLD_TEXT}${GREEN_TEXT}${greetings[$index]}${RESET_TEXT}"
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

alias tui-emacs="alacritty -o 'keyboard.bindings=[]' -e emacsclient -t &"

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

export PATH="/usr/local/bin:$PATH"

shopt -s histappend
shopt -s cmdhist
set -o noclobber
set -o emacs
shopt -s checkwinsize
include /run/current-system/profile/share/bash-completion/bash_completion
if command -v maak &>/dev/null; then
  maak_bin_loc=$(command -v maak)
  maak_bin_dir=${maak_bin_loc%/*}
  maak_install_dir=${maak_bin_dir%/*}
  include "${maak_install_dir}/share/scripts/maak-completion.bash"
fi
command -v fzf &>/dev/null && eval "$(fzf --bash)"
[[ -f ~/.local/bin/mise ]] && eval "$(~/.local/bin/mise activate bash)"
include /run/current-system/profile/etc/profile.d/nix.sh
ble-face -s command_builtin fg=purple
ble-face -s command_builtin_dot fg=purple,bold
ble-import -d ~/.local/share/blesh/contrib/integration/fzf-completion.bash
ble-import -d ~/.local/share/blesh/contrib/integration/fzf-key-bindings.bash
command -v direnv &>/dev/null && eval "$(direnv hook bash)"
[ -f "$GUIX_PROFILE/etc/profile" ] && . "$GUIX_PROFILE/etc/profile"
command -v gh &>/dev/null && [[ -z "$GH_PACKAGES_TOKEN" ]] && export GH_PACKAGES_TOKEN="$(gh auth token)"
shell-greeting
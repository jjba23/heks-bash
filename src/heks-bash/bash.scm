;;; heks-bash

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; heks-bash is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; heks-bash is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with heks-bash.  If not, see <https://www.gnu.org/licenses/>.

(define-module (heks-bash bash)
  #:declarative? #t
  #:use-module (ice-9 match)
  #:use-module (ice-9 exceptions)
  #:export (install-bash bash-vars
                         bash-path-prepends
                         bash-aliases
                         bash-functions
                         bash-postlude
                         bash-prelude
                         serialize-bash-alias
                         serialize-bash-var
                         serialize-bash-path-prepend
                         serialize-bash-function
                         bash-config
                         heks-bash-clone-dir))

;; Parameters
(define heks-bash-clone-dir
  (make-parameter "~/Hacking/heks-bash"))
(define heks-linux-clone-dir
  (make-parameter "~/Hacking/heks-linux"))
(define heks-bash-ble-sh-dir
  (make-parameter "~/.local/share/blesh"))

;; Pool of dynamic greetings
(define greeting-phrases
  (make-parameter '((latin . "Acta non verba. (Daden, geen woorden.)")
                    (latin . "Alea iacta est. (De teerling is geworpen.)")
                    (latin . "Memento mori. (Gedenk te sterven.)")
                    (latin . "Per aspera ad astra. (Via moeilijkheden naar de sterren.)")
                    (latin . "Veni, vidi, vici. (Ik kwam, ik zag, ik overwon.)")
                    (latin . "Cogito, ergo sum. (Ik denk, dus ik ben.)")
                    (latin . "Errare humanum est. (Dwalen is menselijk.)")
                    (latin . "Si vis pacem, para bellum. (Als je vrede wilt, bereid je dan voor op oorlog.)")

                    (latin . "Carpe diem. (Pluk de dag.)")
                    (latin . "Festina lente. (Haast je langzaam.)")
                    (latin . "Scientia potentia est. (Kennis is macht.)")
                    (latin . "Dum spiro spero. (Zolang ik adem, hoop ik.)")
                    (latin . "Nosce te ipsum. (Ken jezelf.)")
                    (latin . "Ave, Caesar, morituri te salutant. (Gegroet, Caesar, zij die gaan sterven groeten u.)")

                    (emacs . "Vi Vi Vi is the number of the beast. Emacs is salvation.")
                    (emacs . "M-x doctor. Tell me about your childhood.")
                    (emacs . "Evaluating buffer... Enlightenment achieved.")
                    (emacs . "C-x C-c. Are you sure you want to exit your entire reality?")
                    (emacs . "Your .emacs file has more lines of code than most corporate startups.")
                    (emacs . "Emacs: The extensible, customizable, self-documenting, real-time display environment.")

                    (dutch . "Nu breekt mijn klomp!")
                    (dutch . "Hoge bomen vangen veel wind.")
                    (dutch . "Gezelligheid kent geen tijd.")
                    (dutch . "Met de deur in huis vallen.")
                    (dutch . "Beter één vogel in de hand dan tien in de lucht.")
                    (dutch . "De soep wordt nooit zo heet gegeten als zij wordt opgediend.")
                    (dutch . "Al draagt een aap een gouden ring, het is en blijft een lelijk ding.")
                    (dutch . "Je kunt niet van een kale kip plukken.")
                    (dutch . "Als de kat van huis is, dansen de muizen op tafel.")

                    (english . "Welcome back, operator. Systems are nominal.")
                    (english . "Shall we play a game?")
                    (english . "Initiating hackermode...")
                    (english . "Wake up, Neo... The Matrix has you.")
                    (english . "I'm sorry, Dave. I'm afraid I can't do that.")
                    (english . "Don't panic. And always know where your towel is.")
                    (english . "All your base are belong to us.")
                    (english . "Stay awhile and listen!")
                    (english . "A vast terminal emptiness awaits your input.")

                    (joke . "There are 10 types of people: those who understand binary, and those who don't.")
                    (joke . "Why do programmers wear glasses? Because they can't C#.")
                    (joke . "Hardware: The parts of a computer system that can be kicked.")
                    (joke . "There are two hard things in computer science: cache invalidation, naming things, and off-by-one errors.")
                    (joke . "To understand recursion, you must first understand recursion.")
                    (joke . "What is a programmer's favorite hangout place? Foo Bar.")
                    (joke . "Algorithm: A word used by programmers when they do not want to explain what they did.")
                    (joke . "Unix is user-friendly. It's just very selective about who its friends are.")

                    (unix-lore . "In the beginning was the command line.")
                    (unix-lore . "Everything is a file, until it's a process.")
                    (unix-lore . "May the source be with you.")
                    (unix-lore . "RTFM: Read The Fine Manual.")
                    (unix-lore . "Pipe it, grep it, sed it, love it.")
                    (unix-lore . "Form follows function, but errors follow shortcuts.")

                    (emacs . "Emacs is a magnificent operating system, it just lacks a good text editor.")
                    (emacs . "M-x butterfly")
                    (emacs . "Escape Meta Alt Control Shift. Your pinky finger is strong.")
                    (emacs . "C-x C-s. Your progress is saved. Your soul is secure.")
                    (emacs . "Welcome to the Church of Emacs. Emacs is my editor, and GNU is its operating system.")
                    (emacs . "Living in the buffers since inception.")

                    (gnu . "GNU's Not Unix! Welcome to the recursive revolution.")
                    (gnu . "Free software is a matter of liberty, not price. Think free speech, not free beer.")
                    (gnu . "You are entering a 100% libre user space.")
                    (gnu . "Guile, Guix, and Glory. Welcome to the GNU system.")
                    (gnu . "Join us now and share the software; You'll be free, hackers, you'll be free.")

                    (rms . "Happy Hacking!")
                    (rms . "There is no system but GNU, and Linux is one of its kernels.")
                    (rms . "If we do not control our software, our software controls us.")
                    (rms . "Proprietary software is a social problem. Keep your system clean.")
                    (rms . "With digital technology, sharing is easy. Sharing is good.")

                    (cyberpunk . "The sky above the port was the color of television, tuned to a dead channel.")
                    (cyberpunk . "High tech, low life. Welcome back to the sprawl.")
                    (cyberpunk . "Data is the new neon. Go get it.")
                    (cyberpunk . "Jack in. Boot up. Clean the cache.")
                    (cyberpunk . "The matrix is nothing but a spark in the dark.")

                    (stoic-wisdom . "You have power over your mind - not outside events. Realize this, and you will find strength.")
                    (stoic-wisdom . "We suffer more often in imagination than in reality.")
                    (stoic-wisdom . "The best revenge is to be unlike him who performed the injury.")
                    (stoic-wisdom . "Control your inputs; master your outputs.")
                    (stoic-wisdom . "Amor Fati: Love your fate, for it is your life.")

                    (original . "Hallo, mens. De computer heeft je gemist. (Zoem. Bleep. Beep.)"))))

(define (bash-prelude)
  (list "[ -f /etc/bashrc ] && . /etc/bashrc"
        (string-append "[[ $- == *i* ]] && "
                       (format #f "source -- ~a/ble.sh"
                               (heks-bash-ble-sh-dir)) " || true")
        "bind \"set completion-ignore-case on\""
        "bind \"set completion-map-case on\""
        "bind \"set show-all-if-ambiguous on\""
        "bind \"set mark-symlinked-directories on\""
        "shopt -s autocd 2> /dev/null"
        "shopt -s dirspell 2> /dev/null"
        "shopt -s cdspell 2> /dev/null"
        "include() { [[ -f \"$1\" ]] && source \"$1\"; }"
        "include ~/.bash-heks-linux-bridge.bash"))

(define bash-vars
  (make-parameter `((GREEN_TEXT . "$(tput setaf 2)")
                    (RED_TEXT . "$(tput setaf 1)")
                    (RESET_TEXT . "$(tput sgr0)")
                    (BOLD_TEXT . "$(tput bold)")
                    (CDPATH . ".:$HOME/Hacking:$HOME/Work")
                    (HISTSIZE . 500000)
                    (HISTFILESIZE . 100000)
                    (HISTTIMEFORMAT . "%F %T  | ")
                    (HISTCONTROL . "ignoreboth:erasedups")
                    (HISTIGNORE . "&:[ ]*:exit:ls:bg:fg:history:clear")
                    (PROMPT_COMMAND . "history -a")
                    (PROMPT_DIRTRIM . "2")
                    (PAGER . "most")
                    (MANPAGER . "most")
                    (GUIX_PROFILE . "$HOME/.guix-profile")
                    (GUIX_LOCPATH . "$HOME/.guix-profile/lib/locale")
                    ;; (GH_PACKAGES_USERNAME . "jjbavdb")
                    ;; (GH_PACKAGES_TOKEN . "")
                    (DOCKER_HOST . "unix:///tmp/podman.sock")
                    (PS1 unquote
                         (string-append "${BOLD_TEXT}\\u@\\h${RESET_TEXT}: "
                                        "\\w${GUIX_ENVIRONMENT:+ [env]}\\n"
                                        "${BOLD_TEXT}λ${RESET_TEXT} ")))))

(define bash-path-prepends
  (make-parameter '("${KREW_ROOT:-$HOME/.krew}/bin" "$HOME/.local/bin"
                    "$HOME/bin"
                    "$HOME/.guix-profile/bin"
                    "/usr/bin"
                    "/usr/sbin"
                    "/usr/local/bin")))

(define* (bash-aliases #:key (clone-dir (heks-bash-clone-dir)))
  `((".." . "cd ..;pwd") ("..." . "cd ../..;pwd")
    ("...." . "cd ../../..;pwd")
    ("c" . "clear")
    ("h" . "history")
    ("tree" . "tree --dirsfirst -F")
    ("mkdir" . "mkdir -p -v")
    ("ll" . "ls -lAh --group-directories-first")
    ("l" . "ls -lAh --group-directories-first")
    ("e" . "emacsclient -t")
    ("k" . "pkill")
    ("fetch" . "fastfetch")
    ("vanilla-emacs" . "emacs -Q")
    ("tui-emacs" . "alacritty -o 'keyboard.bindings=[]' -e emacsclient -t &")
    ("restart-emacs" . "pkill emacs && emacs --daemon")
    ("keys-show" . "wshowkeys -a top -a right -m 12 -t 1")
    ("sr" unquote
     (format #f "cd ~a && maak reconfigure"
             (heks-linux-clone-dir)))
    ("hr" unquote
     (format #f "cd ~a && maak home-reconfigure"
             (heks-linux-clone-dir)))
    ("install-dnfs" unquote
     (format #f "cd ~a && maak install-dnfs"
             (heks-linux-clone-dir)))
    ("install-flatpaks" unquote
     (format #f "cd ~a && maak install-flatpaks"
             (heks-linux-clone-dir)))
    ("upd" unquote
     (format #f "cd ~a && maak update-flatpaks && maak update-dnfs"
             (heks-linux-clone-dir)))
    ("direnv-mode" . "direnv export bash")
    ("scala-dev" unquote
     (format #f "nix develop ~a/resources/flakes/scala-dev/" clone-dir))
    ("haskell-dev" unquote
     (format #f "nix develop ~a/resources/flakes/haskell-dev/" clone-dir))
    ("docker" . "podman")
    ("docker-compose" . "podman-compose")
    ("podman-unix-socket" . "podman system service --time=0 unix:///tmp/podman.sock")
    ("find-largest-files" . "du -h -x -s -- * | sort -r -h | head -20")))

(define bash-functions
  (make-parameter `((glog . "sudo gzip -d \"$1.gz\" && cat \"$1\"")
                    (hgrep . "history | grep \"$1\"")
                    (work-github-actions-version-replacer unquote
                                                          (string-append
                                                           "find \"$1\" -type f \\( -name \"*.yml\" -o -name \"*.yaml\" \\) "
                                                           "-print0 | xargs -0 sed -i "
                                                           "\"s#\\(uses: Vandebron/github-actions/.*@\\).*#\\1$2#\""))
                    (shell-greeting unquote
                                    (let ((quoted-phrases (map (lambda (pair)
                                                                 (format #f
                                                                  "\"~a\""
                                                                  (cdr pair)))
                                                               (greeting-phrases))))
                                      (string-append "local greetings=(\n\t\t"
                                       (string-join quoted-phrases "\n\t\t")
                                       "\n\t)\n\t"
                                       "local size=${#greetings[@]}\n\t"
                                       "local index=$((RANDOM % size))\n\t"
                                       "echo -e \"${BOLD_TEXT}${GREEN_TEXT}${greetings[$index]}${RESET_TEXT}\"
	"
                                       "echo \"\""))))))

(define (bash-postlude)
  (list "shopt -s histappend"
   "shopt -s cmdhist"
   "set -o noclobber"
   "set -o emacs"
   "shopt -s checkwinsize"
   "include /run/current-system/profile/share/bash-completion/bash_completion"

   "if command -v maak &>/dev/null; then"
   "  maak_bin_loc=$(command -v maak)"
   "  maak_bin_dir=${maak_bin_loc%/*}"
   "  maak_install_dir=${maak_bin_dir%/*}"
   "  include \"${maak_install_dir}/share/scripts/maak-completion.bash\""
   "fi"

   "command -v fzf &>/dev/null && eval \"$(fzf --bash)\""
   "[[ -f ~/.local/bin/mise ]] && eval \"$(~/.local/bin/mise activate bash)\""

   "include /run/current-system/profile/etc/profile.d/nix.sh"
   "ble-face -s command_builtin fg=purple"
   "ble-face -s command_builtin_dot fg=purple,bold"
   (format #f "ble-import -d ~a/contrib/integration/fzf-completion.bash"
           (heks-bash-ble-sh-dir))
   (format #f "ble-import -d ~a/contrib/integration/fzf-key-bindings.bash"
           (heks-bash-ble-sh-dir))

   "command -v direnv &>/dev/null && eval \"$(direnv hook bash)\""
   "[ -f \"$GUIX_PROFILE/etc/profile\" ] && . \"$GUIX_PROFILE/etc/profile\""
   ;; "command -v gh &>/dev/null && [[ -z \"$GH_PACKAGES_TOKEN\" ]] && export GH_PACKAGES_TOKEN=\"$(gh auth token)\""
   "shell-greeting"))

;; Serialization Functions
(define (serialize-bash-alias a)
  (format #f "alias ~a=\"~a\"\n"
          (car a)
          (cdr a)))

(define (serialize-bash-var v)
  (format #f "export ~a=\"~a\"\n"
          (car v)
          (cdr v)))

(define (serialize-bash-path-prepend p)
  (format #f "export PATH=\"~a:$PATH\"\n" p))

(define (serialize-bash-function f)
  (format #f "~a () {\n\t~a\n}\n\n"
          (car f)
          (if (list? (cdr f))
              (string-join (cdr f) "\n\t")
              (cdr f))))

(define* (bash-config #:key (clone-dir (heks-bash-clone-dir)))
  (append '("# ====== HEKS-BASH configuration ======"
            "# auto-generated file!\n")
          (list (string-join (bash-prelude) "\n") "\n")
          (map serialize-bash-var
               (bash-vars))
          (map serialize-bash-function
               (bash-functions))
          (map serialize-bash-alias
               (bash-aliases #:clone-dir clone-dir))
          (map serialize-bash-path-prepend
               (bash-path-prepends))
          (list (string-join (bash-postlude) "\n"))))

(define (install-bash)
  (let* ((target-rc (format #f "~a/.bashrc"
                            (getenv "HOME")))
         (display-config-thunk (lambda ()
                                 (set-port-encoding! (current-output-port)
                                                     "UTF-8")
                                 (display (string-join (bash-config) "\n")))))

    (when (file-exists? target-rc)
      (let ((backup-rc (string-append target-rc ".bak")))
        (when (file-exists? backup-rc)
          (delete-file backup-rc))
        (copy-file target-rc backup-rc)))

    (with-output-to-file target-rc
      display-config-thunk)
    (with-output-to-file "bashrc.bash"
      display-config-thunk)
    (display "\nInstalled Bash configuration!")))

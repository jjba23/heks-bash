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
                         bash-path-appends
                         bash-aliases
                         bash-functions
                         bash-postlude
                         bash-prelude
                         serialize-bash-alias
                         serialize-bash-var
                         serialize-bash-path-append
                         serialize-bash-function
                         bash-config
                         heks-bash-clone-dir))

(define heks-bash-clone-dir
  (make-parameter "~/Hacking/heks-bash"))

(define heks-linux-clone-dir
  (make-parameter "~/Hacking/heks-linux"))

(define heks-bash-ble-sh-dir
  (make-parameter "~/.local/share/blesh"))

(define bash-prelude
  (list "[ -f /etc/bashrc ] && . /etc/bashrc"
        (string-append "[[ $- == *i* ]] && "
                       (format #f "source -- ~a/ble.sh"
                               (heks-bash-ble-sh-dir)) " || true")
        ;; Perform file completion in a case insensitive fashion
        "bind \"set completion-ignore-case on\""
        ;; Treat hyphens and underscores as equivalent
        "bind \"set completion-map-case on\""
        ;; Display matches for ambiguous patterns at first tab press
        "bind \"set show-all-if-ambiguous on\""
        ;; Immediately add a trailing slash when auto-completing symlinks to directories
        "bind \"set mark-symlinked-directories on\""
        ;; Prepend cd to directory names automatically
        "shopt -s autocd 2> /dev/null"
        ;; Correct spelling errors during tab-completion
        "shopt -s dirspell 2> /dev/null"
        ;; Correct spelling errors in arguments supplied to cd
        "shopt -s cdspell 2> /dev/null"
        "include() {
    [[ -f \"$1\" ]] && source \"$1\"
}"
        ;; Load heks-linux bash bridge
        "include ~/.bash-heks-linux-bridge.bash"))

(define bash-vars
  (make-parameter `((GREEN_TEXT . "$(tput setaf 2)")
                    (RED_TEXT . "$(tput setaf 1)")
                    (RESET_TEXT . "$(tput sgr0)")
                    (BOLD_TEXT . "$(tput bold)")
                    (SHELL_GREETING_MSG . "${HEKS_BASH_HIGHLIGHT_TEXT}Hallo, mens. De computer heeft je gemist. (Zoem. Bleep. Beep.)${RESET_TEXT}")
                    ;; Directory where cd looks for targets
                    (CDPATH . ".")
                    ;; Increase history size
                    (HISTSIZE . 500000)
                    (HISTFILESIZE . 100000)
                    ;; Use standard ISO 8601 timestamp for history
                    (HISTTIMEFORMAT . "%F %T  | ")
                    ;; Avoid duplicate history entries
                    (HISTCONTROL . "ignoreboth:erasedups")
                    ;; Ignore certain commands and don't log them to history
                    (HISTIGNORE . "&:[ ]*:exit:ls:bg:fg:history:clear")
                    ;; Record each line as it gets issued
                    (PROMPT_COMMAND . "history -a")
                    ;; Automatically trim long paths in the prompt
                    (PROMPT_DIRTRIM . "2")
                    ;; Guix settings
                    (GUIX_PROFILE . "$HOME/.guix-profile")
                    (GUIX_LOCPATH . "$GUIX_PROFILE/lib/locale")
                    ;; Work
                    (GH_PACKAGES_USERNAME . "jjbavdb")
                    (GH_PACKAGES_TOKEN . "\"\"")
                    ;; Podman
                    (DOCKER_HOST . "unix:///tmp/podman.sock")
                    ;; Bash prompt
                    (PS1 unquote
                         (string-append "${BOLD_TEXT}\\u@\\h${RESET_TEXT}: "
                                        "\\w${GUIX_ENVIRONMENT:+ [env]}\\n"
                                        "${BOLD_TEXT}λ${RESET_TEXT} ")))))

(define bash-path-appends
  (make-parameter `("${KREW_ROOT:-$HOME/.krew}/bin" "$HOME/.local/bin"
                    "$HOME/bin" "$HOME/.guix-profile/bin")))

(define* (bash-aliases #:key clone-dir)
  `((".." . "cd ..;pwd") ("..." . "cd ../..;pwd")
    ("...." . "cd ../../..;pwd")
    (c . "clear")
    (h . "history")
    (tree . "tree --dirsfirst -F")
    (mkdir . "mkdir -p -v")
    (ll . "ls -lAh --group-directories-first")
    (l . "ls -lAh --group-directories-first")
    (e . "emacsclient -t")
    (k . "pkill")
    (fetch . "fastfetch")
    (cat . bat)
    (vanilla-emacs . "emacs -Q")
    (restart-emacs . "pkill emacs && emacs --daemon")
    (keys-show . "wshowkeys -a top -a right -m 12 -t 1")
    (sr unquote
        (format #f "cd ~a && maak reconfigure"
                (heks-linux-clone-dir)))
    (hr unquote
        (format #f "cd ~a && maak home-reconfigure"
                (heks-linux-clone-dir)))
    (install-dnfs unquote
        (format #f "cd ~a && maak install-dnfs"
                (heks-linux-clone-dir)))
    (install-flatpaks unquote
        (format #f "cd ~a && maak install-flatpaks"
                (heks-linux-clone-dir)))
    (upd unquote
        (format #f "cd ~a && maak update-flatpaks && maak update-dnfs"
                (heks-linux-clone-dir)))
    (direnv-mode . "direnv export bash")
    (scala-dev unquote
               (format #f "nix develop ~a/resources/flakes/scala-dev/"
                       clone-dir))
    (haskell-dev unquote
                 (format #f "nix develop ~a/resources/flakes/haskell-dev/"
                         clone-dir))
    (docker . "podman")
    (docker-compose . "podman-compose")
    (podman-unix-socket . "podman system service --time=0 unix:///tmp/podman.sock")

    (find-largest-files . "du -h -x -s -- * | sort -r -h | head -20")))

(define bash-functions
  (make-parameter `((glog . "sudo gzip -d \"$1.gz\" && cat \"$1\"")
                    (hgrep . "history | grep \"$1\"")
                    (work-github-actions-version-replacer unquote
                                                          (string-append
                                                           "find \"$1\" -type f \\( "
                                                           "-name \"*.yml\" -o -name \"*.yaml\" "
                                                           "\\) "
                                                           "-print0 | xargs -0 sed -i "
                                                           "\"s#\\(uses: Vandebron/github-actions/.*@\\).*#\\1$2#\""))
                    (shell-greeting unquote
                                    (string-join '("echo \"${SHELL_GREETING_MSG}\""
                                                   "echo \"\"") "\n")))))

(define bash-postlude
  (list
   ;; Append to history file, don't overwrite it
   "shopt -s histappend"
   ;; Save multi-line commands as one command
   "shopt -s cmdhist"
   ;; Prevent file overwrite on stdout redirection
   ;; Use `>|` to force redirection to an existing file
   "set -o noclobber"
   ;; Use Emacs keybdindings
   "set -o emacs"
   ;; Update window size after every command
   "shopt -s checkwinsize"
   ;; Load bash_completion
   "include /run/current-system/profile/share/bash-completion/bash_completion"
   ;; Integrate Guix-managed Bash & Maak
   "maak_bin_loc=$(command -v maak)"
   "maak_bin_dir=${maak_bin_loc%/*}"
   "maak_install_dir=${maak_bin_dir%/*}"
   "maak_completions=\"${maak_install_dir}/share/scripts/maak-completion.bash\""
   ;; Load Maak completion
   "include \"${maak_completions}\""
   ;; Load fzf (must be after bash_completion)
   "eval \"$(fzf --bash)\" || true"
   ;; Load Nix profile
   "include /run/current-system/profile/etc/profile.d/nix.sh"
   ;; ble.sh settings
   "ble-face -s command_builtin fg=purple"
   "ble-face -s command_builtin_dot fg=purple,bold"
   (format #f "ble-import -d ~a/contrib/integration/fzf-completion.bash"
           (heks-bash-ble-sh-dir))
   (format #f "ble-import -d ~a/contrib/integration/fzf-key-bindings.bash"
           (heks-bash-ble-sh-dir))
   ;; Load direnv
   "eval \"$(direnv hook bash)\""
   ;; Source user Guix profile
   "[ -f \"$GUIX_PROFILE/etc/profile\" ] && . \"$GUIX_PROFILE/etc/profile\""
   ;; GitHub token refresh if needed, in background
   "[[ -z \"$GH_PACKAGES_TOKEN\" ]] && export GH_PACKAGES_TOKEN=\"$(gh auth token)\" || true"
   ;; Greet user
   "shell-greeting"))

(define (serialize-bash-alias a)
  (format #f "\nalias ~a=\"~a\""
          (car a)
          (cdr a)))

(define (serialize-bash-var v)
  (format #f "\nexport ~a=\"~a\""
          (car v)
          (cdr v)))

(define (serialize-bash-path-append a)
  (format #f "\nexport PATH=\"~a:$PATH\"" a))

(define (serialize-bash-function f)
  (format #f "\n~a () {\n\t~a\n}\n"
          (car f)
          (cond
            ((list? (cdr f))
             (string-join (cdr f) "\n\t"))
            (else (cdr f)))))

(define* (bash-config #:key clone-dir)
  (append '("" "# ====== HEKS-BASH configuration ======")
          (list (string-join bash-prelude "\n\n"))
          (map serialize-bash-var
               (bash-vars))
          (map serialize-bash-function
               (bash-functions))
          (map serialize-bash-alias
               (bash-aliases #:clone-dir (heks-bash-clone-dir)))
          (map serialize-bash-path-append
               (bash-path-appends))
          (list (string-join bash-postlude "\n\n"))))

(define (install-bash)
  (let* ((display-config-thunk (lambda ()
                                 (display (string-join (bash-config
                                                        #:clone-dir
                                                        heks-bash-clone-dir)
                                                       "\n")))))
    (with-output-to-file (format #f "~a/.bashrc"
                                 (getenv "HOME"))
      display-config-thunk)
    (with-output-to-file "bashrc.bash"
      display-config-thunk)))


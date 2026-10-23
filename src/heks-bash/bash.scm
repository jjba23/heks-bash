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
  #:use-module (ice-9 textual-ports)
  #:export (install-bash bash-vars
                         bash-identity
                         shell-lib-filename
                         notes-filename
                         notes-directory
                         lesskey-filename
                         lesskey-target-path
                         read-source-file
                         serialize-bash-assignment
                         bash-path-prepends
                         bash-aliases
                         bash-shared-aliases
                         bash-git-shortcuts
                         bash-greetings
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

;; The procedural half of the config (prompt engine, git segment, helper
;; functions, greeting pool) lives in a plain shell file so it can stay
;; byte-identical with the other machines the config runs on. It is spliced
;; into the generated bashrc instead of being quoted as Scheme strings.
(define shell-lib-filename
  (make-parameter "shell-lib.bash"))

;; The notes helpers: the `n' command (capture, find, todo, bookmarks,
;; contacts, birthdays, index pages) for when Emacs is not at hand. Plain bash
;; next to this module, spliced into the generated bashrc after the library.
(define notes-filename
  (make-parameter "notes.bash"))

;; Where the notes are: the same directory the Emacs config points at.
(define notes-directory
  (make-parameter "$HOME/Hacking/private-notes"))

;; The pager keymap. Same idea: a plain data file next to this module, shared
;; verbatim with the other two machines, installed as $XDG_CONFIG_HOME/lesskey.
(define lesskey-filename
  (make-parameter "lesskey"))

;; Machine identity. These CC_* variables are read by the shared shell
;; library to render the prompt and the greeting; changing them is all it
;; takes to make a machine recognisable at a glance.
(define bash-identity
  (make-parameter '(("CC_FLAVOR" . "heks-bash")
                    ("CC_HOST_KIND" . "guix/linux")
                    ("CC_SIGIL" . "λ")
                    ("CC_ACCENT" . "99")
                    ("CC_RC_FILE" . "$HOME/.bashrc"))))

(define (bash-prelude)
  (list "[ -f /etc/bashrc ] && . /etc/bashrc"
        "# shellcheck source=/dev/null"
        (string-append "[[ $- == *i* && -r "
                       (format #f "~a/ble.sh"
                               (heks-bash-ble-sh-dir)) " ]] && source -- "
                       (format #f "~a/ble.sh"
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
                    (HISTIGNORE . "&:[ ]*:exit:ls:bg:fg:history:clear:cd:pwd")
                    (GUIX_PROFILE . "$HOME/.guix-profile")
                    (GUIX_LOCPATH . "$HOME/.guix-profile/lib/locale")
                    (EDITOR . "smart_emacsclient")
                    ;; (GH_PACKAGES_USERNAME . "jjbavdb")
                    ;; (GH_PACKAGES_TOKEN . "")
                    (DOCKER_HOST . "unix:///tmp/podman.sock"))))

;; NOTE: PS1, PROMPT_COMMAND, PAGER and the old [env] marker are gone: the
;; prompt is rebuilt on every command by (shell-lib.bash)'s __cc_prompt, which
;; adds the machine badge, the trimmed path, the git segment and env badges for
;; Guix shells, Nix shells and Python venvs; the pager environment (LESS,
;; LESSKEYIN) is set by the same library.

(define (mkdir-p path)
  "Recursively creates PATH and all required parent directories."
  (unless (or (string-null? path)
              (file-exists? path))
    (let ((parent (dirname path)))
      (when (and (not (string=? parent path))
                 (not (string=? parent ".")))
        (mkdir-p parent))
      (catch 'system-error
             (lambda ()
               (mkdir path))
             (lambda (key . args)
               (unless (and (file-exists? path)
                            (eq? 'directory
                                 (stat:type (stat path))))
                 (apply throw key args)))))))

(define (ensure-smart-emacsclient-bin)
  (let* ((home (getenv "HOME"))
         (bin-dir (format #f "~a/.local/bin" home))
         (script-path (format #f "~a/smart_emacsclient" bin-dir))
         (script-content
          "#!/usr/bin/env bash
if [ -n \"$DISPLAY\" ] || [ -n \"$WAYLAND_DISPLAY\" ]; then
    exec emacsclient -a \"\" -c \"$@\"
else
    exec emacsclient -a \"\" -nw \"$@\"
fi
"))

    (unless (file-exists? bin-dir)
      (mkdir-p bin-dir))

    (when (file-exists? script-path)
      (delete-file script-path))
    (dirname script-path)
    (with-output-to-file script-path
      (lambda ()
        (display script-content)))
    (chmod script-path #o755)))

(define bash-path-prepends
  (make-parameter '("${KREW_ROOT:-$HOME/.krew}/bin" "$HOME/.local/bin"
                    "$HOME/bin"
                    "$HOME/.guix-profile/bin"
                    "/usr/bin"
                    "/usr/sbin"
                    "/usr/local/bin")))

(define* (bash-aliases #:key (clone-dir (heks-bash-clone-dir)))
  (append
   bash-shared-aliases
   (bash-machine-aliases #:clone-dir clone-dir)))

(define bash-shared-aliases
  ;; Navigation, emacs, podman, fetch, ...: the set every machine shares.
  '(("..". "cd ..;pwd")
    ("..." . "cd ../..;pwd")
    ("...." . "cd ../../..;pwd")
    ("c" . "clear")
    ("h" . "history")
    ("hg" . "hgrep")
    ("tree" . "tree --dirsfirst -F")
    ("mkdir" . "mkdir -p -v")
    ("df" . "df -h")
    ("e" . "emacsclient -t")
    ("k" . "pkill")
    ("fetch" . "fastfetch")
    ("vanilla-emacs" . "emacs -Q")
    ("restart-emacs" . "pkill emacs; emacs --daemon")
    ("docker" . "podman")
    ("docker-compose" . "podman compose")
    ("find-largest-files" . "du -h -x -s -- * 2>/dev/null | sort -r -h | head -20")))

;; One-line git shortcuts, as data: (NAME . BODY).  glog is multi-line and
;; stays in shell-lib.bash.
(define bash-git-shortcuts
  '((gst . "git status --short --branch \"$@\";")
    (gd . "git diff \"$@\";")
    (gds . "git diff --stat \"$@\";")
    (gco . "git checkout \"$@\";")
    (gsw . "git switch \"$@\";")
    (gbr . "git branch -vv \"$@\";")
    (gcm . "git commit -m \"$*\";")
    (gpl . "git pull --ff-only \"$@\";")
    (gpu . "git push \"$@\";")
    (gfetch . "git fetch --all --prune \"$@\";")
    (groot . "cdroot;")))

;; The greeting pool: nerd-style sayings about free software, RMS, GNU, Emacs
;; and Linux/Unix.  Plain data; extend freely.
(define bash-greetings
  (make-parameter
   '(;; emacs
     "Vi Vi Vi is the number of the beast. Emacs is salvation."
     "M-x doctor. Tell me about your childhood."
     "Evaluating buffer... Enlightenment achieved."
     "C-x C-c. Are you sure you want to exit your entire reality?"
     "Your .emacs file has more lines of code than most corporate startups."
     "Emacs: The extensible, customizable, self-documenting, real-time display environment."
     "Emacs is a magnificent operating system, it just lacks a good text editor."
     "M-x butterfly"
     "Escape Meta Alt Control Shift. Your pinky finger is strong."
     "C-x C-s. Your progress is saved. Your soul is secure."
     "Welcome to the Church of Emacs. Emacs is my editor, and GNU is its operating system."
     "Living in the buffers since inception."
     "C-h t. Everyone starts as a beginner."
     "Everything is a buffer, until it's a window."
     "M-x emacs-uptime. Reboot? Never heard of it."
     "In Emacs, nobody can hear you C-g."
     "Lisp: the programmable programming language."
     "(lambda (x) x) -- the identity of a hacker."
     ;; gnu / rms / free software
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
     "I'd just like to interject for a moment: what you're referring to as Linux is GNU/Linux."
     "The four freedoms: run, study, share, improve. Number zero is the best one."
     "Copyleft: all rights reversed."
     "Use free software. Your freedom is not a feature request."
     "Software wants to be free, and so do you."
     "Treat your source like a library book: share it."
     ;; unix / linux lore
     "Unix is user-friendly. It's just very selective about who its friends are."
     "In the beginning was the command line."
     "Everything is a file, until it's a process."
     "May the source be with you."
     "RTFM: Read The Fine Manual."
     "Pipe it, grep it, sed it, love it."
     "sudo make me a sandwich."
     "There's no place like 127.0.0.1."
     "rm -rf: the sharpest tool in the shed."
     "Keep calm and `man man`."
     "Linux: because a computer should do what you tell it to."
     "It's not a bug, it's an undocumented feature of the kernel."
     "chmod +x your life."
     "Talk is cheap. Show me the code.")))

(define (shell-double-quote s)
  "Return @var{s} escaped for use inside a double-quoted shell string."
  (string-concatenate
   (map (lambda (c)
          (if (memv c '(#\\ #\" #\$ #\`))
              (string #\\ c)
              (string c)))
        (string->list s))))

(define (serialize-bash-greetings)
  (string-append
   "CC_GREETINGS=(\n"
   (string-join (map (lambda (g)
                       (format #f "\t\"~a\"" (shell-double-quote g)))
                     (bash-greetings))
                "\n")
   "\n)\n"))

(define* (bash-machine-aliases #:key (clone-dir (heks-bash-clone-dir)))
  ;; Only what is truly machine specific.
  `(("ll" . "ls -lAh --group-directories-first")
    ("l" . "ls -lAh --group-directories-first")
    ("tui-emacs" . "alacritty -o 'keyboard.bindings=[]' -e emacsclient -t &")
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
    ("podman-unix-socket" . "podman system service --time=0 unix:///tmp/podman.sock")))

(define bash-functions
  ;; Machine-specific helpers. glog/gunlog, hgrep, git shortcuts, extract,
  ;; mkcd, hist-top, rc-time and friends come from (shell-lib.bash).
  (make-parameter
   `((work-github-actions-version-replacer unquote
                                           (string-append
                                            "find \"$1\" -type f \\( -name \"*.yml\" -o -name \"*.yaml\" \\) "
                                            "-print0 | xargs -0 sed -i "
                                            "\"s#\\(uses: Vandebron/github-actions/.*@\\).*#\\1$2#\""))
     ;; notify, ports, serve, extract, ... live in (shell-lib.bash)
     )))

(define (bash-postlude)
  (list "set -o noclobber"
   "set -o emacs"
   "include /run/current-system/profile/share/bash-completion/bash_completion"

   "command -v fzf &>/dev/null && eval \"$(fzf --bash)\""
   "[[ -f ~/.local/bin/mise ]] && eval \"$(~/.local/bin/mise activate bash)\""

   "include /run/current-system/profile/etc/profile.d/nix.sh"
   "command -v ble-face &>/dev/null && ble-face -s command_builtin fg=purple"
   "command -v ble-face &>/dev/null && ble-face -s command_builtin_dot fg=purple,bold"
   (format #f
           "command -v ble-import &>/dev/null && ble-import -d ~a/contrib/integration/fzf-completion.bash"
           (heks-bash-ble-sh-dir))
   (format #f
           "command -v ble-import &>/dev/null && ble-import -d ~a/contrib/integration/fzf-key-bindings.bash"
           (heks-bash-ble-sh-dir))

   "command -v direnv &>/dev/null && eval \"$(direnv hook bash)\""
   "[ -f \"$GUIX_PROFILE/etc/profile\" ] && . \"$GUIX_PROFILE/etc/profile\""))

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

(define (serialize-bash-assignment a)
  "Serialize a single @var{a} (@code{NAME . VALUE}) as a plain shell assignment.
Unlike @code{serialize-bash-var} nothing is exported: @code{CC_*} variables are
only read by the shared shell library."
  (format #f "~a=\"~a\""
          (car a)
          (cdr a)))

(define (read-source-file name)
  "Return the contents of the repository file @var{name} as a string.
The file sits next to this module, so look there first and fall back to the
repository-relative path for setups that load compiled code."
  (let* ((here (and (current-filename)
                    (dirname (current-filename)))))
    (let loop
        ((paths (list (and here
                           (format #f "~a/~a" here name))
                      (format #f "src/heks-bash/~a" name))))
      (cond ((null? paths)
             (error "heks-bash: cannot find the shared file" name))
            ((and (car paths)
                  (file-exists? (car paths)))
             (call-with-input-file (car paths)
               get-string-all))
            (else (loop (cdr paths)))))))

(define (read-shell-lib)
  "Return the contents of the shared shell library as a string."
  (read-source-file (shell-lib-filename)))

(define (read-notes-lib)
  "Return the contents of the notes helpers as a string."
  (read-source-file (notes-filename)))

(define (lesskey-target-path)
  "Where the shared pager keymap is installed: $XDG_CONFIG_HOME/lesskey, which
is the first place less(1) looks for it."
  (let* ((home (getenv "HOME"))
         (xdg (getenv "XDG_CONFIG_HOME"))
         (conf (if (and xdg (not (string-null? xdg)))
                   xdg
                   (format #f "~a/.config" home))))
    (format #f "~a/lesskey" conf)))

(define* (bash-config #:key (clone-dir (heks-bash-clone-dir)))
  (append '("# shellcheck shell=bash"
            "# shellcheck disable=SC1090  # include() sources rc fragments by path"
            "# shellcheck disable=SC2155  # the tput colour exports are intentional"
            "# shellcheck disable=SC2034  # palette values are consumed indirectly"
            "# ====== HEKS-BASH configuration ======"
            "# auto-generated file! Regenerate with `maak install-bash'."
            "# Sources of truth: src/heks-bash/bash.scm (machine data)"
            "# and src/heks-bash/shell-lib.bash (shared prompt + helpers).\n")
          ;; machine identity read by the shared library
          (list (string-join (map serialize-bash-assignment
                                  (bash-identity)) "\n") "")
          (list (string-join (bash-prelude) "\n") "\n")
          (map serialize-bash-var
               (bash-vars))
          ;; the shared prompt engine and helper library
          (list "" (read-shell-lib) "")
          (list (serialize-bash-greetings))
          (map serialize-bash-function
               bash-git-shortcuts)
          ;; the notes: where they are, and the `n' command that works on them
          (list "# ---- notes (the `n' command) ----"
                (format #f "export NOTES_DIR=\"${NOTES_DIR:-~a}\"" (notes-directory))
                (read-notes-lib)
                "")
          (map serialize-bash-function
               (bash-functions))
          (map serialize-bash-alias
               (bash-aliases #:clone-dir clone-dir))
          ;; a blank line keeps every alias/function block readable
          (map (lambda (line)
                 (string-append line "\n"))
               (map serialize-bash-path-prepend
                    (bash-path-prepends)))
          (list "" (string-join (bash-postlude) "\n") "" "cc_boot")))

(define (install-bash)
  (let* ((target-rc (format #f "~a/.bashrc"
                            (getenv "HOME")))
         (display-config-thunk (lambda ()
                                 (set-port-encoding! (current-output-port)
                                                     "UTF-8")
                                 (display (string-join (bash-config) "\n")))))
    (ensure-smart-emacsclient-bin)
    (when (file-exists? target-rc)
      (let ((backup-rc (string-append target-rc ".bak")))
        (when (file-exists? backup-rc)
          (delete-file backup-rc))
        (copy-file target-rc backup-rc)))

    (with-output-to-file target-rc
      display-config-thunk)
    ;; The pager keymap lives outside the rc so less can read it directly.
    (let ((target-lesskey (lesskey-target-path)))
      (mkdir-p (dirname target-lesskey))
      (with-output-to-file target-lesskey
        (lambda ()
          (set-port-encoding! (current-output-port) "UTF-8")
          (display (read-source-file (lesskey-filename))))))
    (display "\nInstalled Bash configuration!")))

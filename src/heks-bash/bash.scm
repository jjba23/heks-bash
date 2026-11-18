;;; heks-bash

;; Copyright (c) 2025-2026 Josep Bigorra <jjbigorra@gmail.com>
;; SPDX-License-Identifier: MIT

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to
;; deal in the Software without restriction, including without limitation the
;; rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
;; sell copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
;; IN THE SOFTWARE.

(define-module (heks-bash bash)
  #:declarative? #t
  #:use-module (ice-9 match)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 textual-ports)
  #:export (install-bash bash-vars
                         bash-identity
                         heks-bash-version
                         ble-sh-version
                         ble-sh-commit
                         ble-sh-repository
                         shell-lib-filename
                         notes-filename
                         notes-directory
                         lesskey-filename
                         lesskey-target-path
                         bash-pager-keymap
                         serialize-lesskey
                         serialize-bash-pager-keys
                         bash-tools
                         serialize-bash-tools
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
                         display-bash
                         write-bash-config
                         write-lesskey
                         write-rendered
                         heks-bash-clone-dir))

;; Parameters
(define heks-bash-version
  (make-parameter "2.2.0"))
(define heks-bash-clone-dir
  (make-parameter "~/Hacking/heks-bash"))
(define heks-linux-clone-dir
  (make-parameter "~/Hacking/heks-linux"))
(define heks-bash-ble-sh-dir
  (make-parameter "~/.local/share/blesh"))

;; ble.sh builds itself and moves with `ble-update', so the installer pins it
;; instead: one commit, fetched and rebuilt, so two machines that ran
;; `install-ble-sh' on different days still run the same line editor.
(define ble-sh-version
  (make-parameter "0.4.0-devel4+95ae551"))
(define ble-sh-commit
  (make-parameter "95ae551dd687a0c61227839dda43f52ac7ea6631"))
(define ble-sh-repository
  (make-parameter "https://github.com/akinomyoga/ble.sh.git"))

;; The procedural half of the config (prompt engine, git segment, helper
;; functions, greeting pool) lives in a plain shell file, spliced into the
;; generated bashrc instead of being quoted as Scheme strings.
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

;; The pager keymap.  The source is `bash-pager-keymap' above; this is the
;; rendering of it that is checked in, because the two sibling repositories
;; consume the same file.  A test diffs the two, so they cannot drift.
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
        ;; ble.sh, the readline bindings and bash-completion all need a bash
        ;; built with readline and programmable completion.  Nix's bash has
        ;; neither, so every one of those lines prints an error there; ask once
        ;; and let the rest of the rc (and the postlude) skip them.
        "if (shopt -q progcomp && command -v bind) &>/dev/null; then"
        "    CC_COMPLETIONS=1"
        "else"
        "    CC_COMPLETIONS=0"
        "fi"
        "if [[ $CC_COMPLETIONS == 1 && $- == *i* ]]; then"
        "    # shellcheck source=/dev/null"
        (string-append "    [[ -r "
                       (format #f "~a/ble.sh"
                               (heks-bash-ble-sh-dir)) " ]] && source -- "
                       (format #f "~a/ble.sh"
                               (heks-bash-ble-sh-dir)) " || true")
        "    # readline only listens in an interactive shell, and says so on"
        "    # stderr in one that is not."
        "    bind \"set completion-ignore-case on\""
        "    bind \"set completion-map-case on\""
        "    bind \"set show-all-if-ambiguous on\""
        "    bind \"set mark-symlinked-directories on\""
        "fi"
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

;; The pager keymap, as data.  Each section is (NAME (LABEL (KEY . ACTION) ...)):
;; here are the lesskey(1) sections, here is what each group of keys is for, and
;; here are the bindings that implement it.  Two renderings come out of this
;; one list - the `lesskey' file less(1) reads and the table `pager-keys'
;; prints - so the map a person reads and the map the pager obeys cannot drift.
;;
;; A KEY is written the way lesskey(1) writes it (`^N', `\ev'); the help table
;; spells the same key the way a terminal user reads it (`C-n', `M-v').
(define bash-pager-keymap
  (make-parameter
   '((command
      ("one line down / up"
       ("^N" . "forw-line")
       ("^P" . "back-line"))
      ("one screen down / up"
       ("^F" . "forw-screen")
       ("^B" . "back-screen")
       ("^V" . "forw-screen")
       ("\\ev" . "back-screen"))
      ("half a screen down / up"
       ("^D" . "forw-scroll")
       ("^U" . "back-scroll"))
      ("RET scrolls a line too"
       ("\\r" . "forw-line")
       ("\\n" . "forw-line"))
      ("top / bottom of the file"
       ("^A" . "goto-line 1\\rk")
       ("\\e<" . "goto-line 1\\rk")
       ("^E" . "goto-end")
       ("\\e>" . "goto-end"))
      ("go to a line"
       ("\\eg" . "goto-line"))
      ("redraw the screen"
       ("^L" . "repaint"))
      ("search forward / backward"
       ("^S" . "forw-search")
       ("^R" . "back-search"))
      ("clear the search highlighting"
       ("\\eU" . "clear-search"))
      ("the status line"
       ("^G" . "status")))
     (line-edit
      ("beginning / end of the line"
       ("^A" . "home")
       ("^E" . "end")
       ("\\e0" . "home")
       ("\\e$" . "end"))
      ("one character left / right"
       ("^B" . "left")
       ("^F" . "right")
       ("\\eh" . "left")
       ("\\el" . "right"))
      ("one word left / right"
       ("\\eb" . "word-left")
       ("\\ef" . "word-right"))
      ("kill the word before the cursor"
       ("^W" . "word-backspace")
       ("\\kB" . "word-backspace")
       ("\\e\\kb" . "word-backspace"))
      ("delete / kill"
       ("^D" . "delete")
       ("\\ed" . "word-delete")
       ("^K" . "kill-line")
       ("^U" . "kill-line"))
      ("previous / next line"
       ("^P" . "up")
       ("^N" . "down"))
      ("cancel the prompt"
       ("^G" . "abort"))
      ("complete a file name"
       ("\\e\\t" . "back-complete"))))))

;; The runtime dependencies, as data: name, what to look for, how to look for
;; it, what the tool is for and how to get it.  `tools' reports the table with
;; a present/missing column, and the `ai' helper takes its install hint from
;; here, so "this is missing, here is the command" is written once.
(define bash-tools
  (make-parameter
   '(("git" "git" "command" "the prompt's git segment, the shortcuts and the diff colour" "")
     ("less" "less" "command" "the pager, with the keymap installed as lesskey" "install less")
     ("fzf" "fzf" "command" "the notes pickers and fzf's own key bindings" "install fzf")
     ("direnv" "direnv" "command" "per-directory environments" "install direnv")
     ("delta" "delta" "command" "colourised git diffs" "install git-delta")
     ("ble.sh" "~/.local/share/blesh/ble.sh" "file" "syntax highlighting, autosuggestion, the completion menu" "maak install-ble-sh")
     ("eca-cli" "eca-cli" "command" "the `ai' chat, with the workspace set to the project root" "cd ~/Hacking/heks-linux && maak install-eca")
     ("guix" "guix" "command" "the build toolchain and the guix shell badge" "install Guix")
     ("nix" "nix" "command" "the nix develop shortcuts and the nix shell badge" "install Nix")
     ("python3" "python3" "command" "the json helper and serve's HTTP server" "install python3"))))

(define (lesskey-key->display key)
  "Return lesskey's @var{key} - @code{^N}, @code{\\ev} - as @code{C-n},
@code{M-v}: the same key, written for a person reading the help table."
  (cond ((string-prefix? "^" key)
         (string-append "C-" (string-downcase (substring key 1))))
        ((member key '("\\r" "\\n")) "RET")
        ((string=? key "\\e\\t") "M-TAB")
        ((string=? key "\\e\\kb") "M-BS")
        ((member key '("\\kb" "\\kB")) "C-BS")
        ((string-prefix? "\\e" key)
         (string-append "M-" (string-downcase (substring key 2))))
        (else key)))

(define (serialize-lesskey)
  "Render @code{bash-pager-keymap} as a lesskey(1) source file."
  (string-append
   "# ====== pager keymap ======
#
# Generated from bash-pager-keymap in bash.scm: edit the Scheme list, not this
# file.  Installed as $XDG_CONFIG_HOME/lesskey, which less(1) 582 and later
# read directly, so there is no `lesskey' compile step and no binary to keep in
# sync.  Everything not listed here keeps its default less binding (j k space b
# g G / ? n N m ' ! | :x q ...), so both muscle memories work.
"
   (string-join
    (map (lambda (section)
           (string-append
            (format #f "~%#~a~%" (car section))
            (string-join
             (map (lambda (row)
                    (format #f "~a~a~%"
                            (format #f "# ~a~%" (car row))
                            (string-join
                             (map (lambda (binding)
                                    (format #f "~a ~a"
                                            (car binding)
                                            (cdr binding)))
                                  (cdr row))
                             "\n")))
                  (cdr section))
             "\n")))
         (bash-pager-keymap))
    "")))

(define (serialize-bash-pager-keys)
  "Render @code{bash-pager-keymap} as the arrays @code{pager-keys} prints."
  (string-append
   (string-join
    (map (lambda (section)
           (format #f "CC_PAGER_KEYS_~a=(\n~a)\n"
                   (string-upcase
                    (string-map (lambda (c)
                                  (if (char=? c #\-) #\_ c))
                                (symbol->string (car section))))
                   (string-join
                    (map (lambda (row)
                           (format #f "\t\"~a\""
                                   (shell-double-quote
                                    (format #f "~a\t~a"
                                            (car row)
                                            (string-join
                                             (map (lambda (binding)
                                                    (lesskey-key->display
                                                     (car binding)))
                                                  (cdr row))
                                             ", ")))))
                         (cdr section))
                    "\n")))
         (bash-pager-keymap))
    "\n")
   "\n"))

(define (serialize-bash-tools)
  "Render @code{bash-tools} as the array @code{tools} reports from.
Every field is written for a double-quoted shell string, so an apostrophe in a
description stays a character and a backtick - `ai', say - does not start a
command substitution in the rc."
  (string-append
   "CC_TOOLS=(\n"
   (string-join
    (map (lambda (tool)
           (format #f "\t\"~a\""
                   (shell-double-quote (string-join tool "\t"))))
         (bash-tools))
    "\n")
   "\n)\n"))

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
   ;; `set -o emacs' (readline) and everything completion related live here
   ;; too; CC_COMPLETIONS comes from the prelude.
   "if [[ $CC_COMPLETIONS == 1 ]]; then"
   "    set -o emacs"
   "    include /run/current-system/profile/share/bash-completion/bash_completion"
   "    command -v fzf &>/dev/null && eval \"$(fzf --bash)\""
   "fi"

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
  ;; A directory that is not there is a dead PATH entry, and on a machine
  ;; without a Guix profile that is exactly what these paths are; the test runs
  ;; before the export so the entry only exists when it can resolve something.
  (format #f "[[ -d \"~a\" ]] && export PATH=\"~a:$PATH\"\n" p p))

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
  (append (list "# shellcheck shell=bash"
                "# shellcheck disable=SC1090  # include() sources rc fragments by path"
                "# shellcheck disable=SC2155  # the tput colour exports are intentional"
                "# shellcheck disable=SC2034  # palette values are consumed indirectly"
                (format #f "# ====== HEKS-BASH ~a configuration ======"
                        (heks-bash-version))
                "# auto-generated file! Regenerate with `maak install-bash'."
                "# Sources of truth: src/heks-bash/bash.scm (machine data)"
                "# and src/heks-bash/shell-lib.bash (shared prompt + helpers).\n")
          ;; version and machine identity, read by the shared library
          (list (string-join (map serialize-bash-assignment
                                  (append (list (cons "CC_VERSION"
                                                      (heks-bash-version)))
                                          (bash-identity)))
                             "\n")
                "")
          (list (string-join (bash-prelude) "\n") "\n")
          (map serialize-bash-var
               (bash-vars))
          ;; data the shared library reads: the greeting pool, the pager keymap
          ;; and the dependency table, all declared above in Scheme
          (list "" (serialize-bash-greetings))
          (list (serialize-bash-pager-keys))
          (list (serialize-bash-tools))
          ;; the shared prompt engine and helper library
          (list "" (read-shell-lib) "")
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

(define* (display-bash #:key (clone-dir (heks-bash-clone-dir)))
  "Write the rendered Bash configuration to the current output port and
return nothing.  Rendering is a pure function of the parameters, so this is
what a golden file and a diff are made of."
  (set-port-encoding! (current-output-port) "UTF-8")
  (display (string-join (bash-config #:clone-dir clone-dir) "\n")))

(define (write-rendered path text)
  "Write @var{text} to @var{path} as UTF-8 and return @var{path}."
  (let ((port (open-output-file path)))
    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (set-port-encoding! port "UTF-8")
        (display text port))
      (lambda () (close-port port))))
  path)

(define* (write-bash-config path #:key (clone-dir (heks-bash-clone-dir)))
  "Render the configuration into @var{path} and return @var{path}.
This creates that one file and nothing else: @code{install-bash} is the entry
point that also installs the pager keymap."
  (write-rendered path (string-join (bash-config #:clone-dir clone-dir) "\n")))

(define (write-lesskey path)
  "Render the pager keymap into @var{path} and return @var{path}."
  (write-rendered path (serialize-lesskey)))

(define* (install-bash #:key (target #f))
  "Write the Bash configuration to @var{target}, ~/.bashrc by default, and
install the pager keymap beside it.  Another path is what lets a test render
into a synthetic home instead of the real one."
  (let ((target-rc (or target
                       (format #f "~a/.bashrc"
                               (getenv "HOME")))))
    (ensure-smart-emacsclient-bin)
    (when (file-exists? target-rc)
      (let ((backup-rc (string-append target-rc ".bak")))
        (when (file-exists? backup-rc)
          (delete-file backup-rc))
        (copy-file target-rc backup-rc)))

    (write-bash-config target-rc)
    ;; The pager keymap lives outside the rc so less can read it directly; it
    ;; is the rendering of `bash-pager-keymap', not the checked-in copy, so a
    ;; stale file in the tree cannot reach the install.
    (let ((target-lesskey (lesskey-target-path)))
      (mkdir-p (dirname target-lesskey))
      (write-lesskey target-lesskey))
    (display (format #f "\nInstalled Bash configuration in ~a!" target-rc))))

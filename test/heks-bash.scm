;;; heks-bash tests

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

;;; Commentary:
;;
;; Two halves, because the generated file makes two kinds of claim.
;;
;; The first is a pure claim: `bash-config' is a function of the module's
;; parameters to a string, so it is asserted directly and needs no shell.
;;
;; The second can only be answered by running a shell.  The file's whole job is
;; to change an interactive session, so these tests source it in a synthetic
;; home and ask it questions - `about', `tools', `pager-keys', `n help' - and
;; check the exit status, the standard output and, above all, that nothing was
;; written to standard error.  A generated rc that prints an error is a broken
;; rc even when the prompt still appears.
;;
;; What is deliberately not asserted: the prompt's exact bytes (a colour escape
;; is not a contract), the greeting text (it is a random saying), and anything
;; about an interactive TTY beyond "it starts, in a pty, and does not fail".
;;
;; Nothing here reads or writes the real ~/.bashrc, ~/.config/lesskey or
;; ~/.local: HOME and XDG_CONFIG_HOME point at a temporary directory for the
;; duration of a case and are restored afterwards.
;;
;; Run it with:  guile -L ./src test/heks-bash.scm
;; or, with the linter and the pinned toolchain:  maak check
;;
;; Adding a test: the pure half is a `test-assert' over `rendered' or over one
;; of the serialisers, and needs nothing else.  The shell half is a script for
;; `run-shell-case' - it gets a fresh temporary home with the rc already
;; installed, a PATH holding only the system directories, and its standard error
;; captured to a file, so "nothing was printed on stderr" is something a test
;; can assert.  A case that needs a terminal asks for `#:interactive? #t' and
;; asserts markers, because a pty echoes and merges the two streams.

;;; Code:

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 popen)
             (ice-9 ftw)
             (ice-9 textual-ports)
             (ice-9 format))

(use-modules ((heks-bash bash) #:prefix bash:))

;; One runner for the whole file: with the default one, `test-end' pops it and
;; the verdict below would read a fresh, empty runner and always fail.
(define test-runner (test-runner-simple))
(test-runner-current test-runner)

;;; ====== Helpers ===========================================================

(define (slurp path)
  "Return the whole of @var{path} as a string, or the empty string."
  (if (file-exists? path)
      (call-with-input-file path get-string-all)
      ""))

(define (which program)
  "Return the first @var{program} on PATH, or #f."
  (let loop ((dirs (string-split (or (getenv "PATH") "") #\:)))
    (if (null? dirs)
        #f
        (let ((candidate (string-append (car dirs) "/" program)))
          (if (and (file-exists? candidate)
                   (not (eq? 'directory (stat:type (stat candidate)))))
              candidate
              (loop (cdr dirs)))))))

(define (make-temp-dir)
  "Create and return an empty temporary directory."
  ;; mkstemp! rewrites the template in place, so it must not be a literal.
  (let* ((template (string-copy "/tmp/heks-bash-test-XXXXXX"))
         (port (mkstemp! template)))
    (close-port port)
    (delete-file template)
    (mkdir template)
    template))

(define (delete-tree path)
  "Remove @var{path} and everything below it."
  (when (file-exists? path)
    (if (eq? 'directory (stat:type (stat path)))
        (begin
          (for-each (lambda (entry)
                      (unless (member entry '("." ".."))
                        (delete-tree (string-append path "/" entry))))
                    (scandir path))
          (rmdir path))
        (delete-file path))))

(define (call-with-environment bindings thunk)
  "Run @var{thunk} with the environment variables in @var{bindings} - a list of
(name . value) pairs - then put the previous values back."
  (let ((saved (map (lambda (binding)
                      (cons (car binding) (getenv (car binding))))
                    bindings)))
    (dynamic-wind
      (lambda ()
        (for-each (lambda (binding)
                    (setenv (car binding) (cdr binding)))
                  bindings))
      thunk
      (lambda ()
        (for-each (lambda (entry)
                    (if (cdr entry)
                        (setenv (car entry) (cdr entry))
                        (unsetenv (car entry))))
                  saved)))))

;;; ====== The shell harness ================================================

;; A case is a bash script.  It runs with HOME, XDG_CONFIG_HOME, CC_PLAIN and
;; TERM set for the duration, its standard error goes to a file in the same
;; temporary home (so a stray warning fails the test instead of scrolling past)
;; and it is started with argv, never with a shell string built from a path.

(define (capture-command program . arguments)
  "Run @var{program} with @var{arguments} and return (exit-code stdout)."
  (let* ((port (apply open-pipe* OPEN_READ program arguments))
         (stdout (get-string-all port))
         (status (close-pipe port)))
    (list (status:exit-val status) stdout)))

(define (test-path)
  "A PATH for a shell case: the usual system directories plus wherever this
run's bash and script(1) live.

Inheriting the caller's PATH would make the PATH assertion below meaningless -
it would be measuring the shell that started the tests, not the rc."
  (string-join
   (delete-duplicates
    (append (list (dirname (which "bash")))
            (if (which "script") (list (dirname (which "script"))) '())
            '("/usr/local/bin" "/usr/bin" "/bin")))
   ":"))

(define* (run-shell-case home script #:key (interactive? #f) (term "dumb"))
  "Run @var{script} under bash with @var{home} as HOME.

Returns (exit-code stdout stderr).  With @var{interactive?} the script runs as
the commands of an interactive bash on a pty - which sources ~/.bashrc on its
own, so @var{script} is then the body only.  The pty merges the two streams, so
only the exit status and markers in the output are worth asserting there."
  (let* ((stderr-file (string-append home "/stderr.log"))
         (script-file (string-append home "/case.bash"))
         (bash (which "bash"))
         (bindings (list (cons "HOME" home)
                         (cons "XDG_CONFIG_HOME" (string-append home "/.config"))
                         (cons "XDG_DATA_HOME" (string-append home "/.local/share"))
                         (cons "CC_PLAIN" "1")
                         (cons "TERM" term)
                         (cons "PATH" (test-path))
                         (cons "HEKS_TEST_STDERR" stderr-file))))
    (call-with-environment
     bindings
     (lambda ()
       (call-with-output-file script-file
         (lambda (port)
           (unless interactive?
             ;; One redirect at the top keeps every later line plain bash.
             (display "exec 2> \"$HEKS_TEST_STDERR\"\n" port))
           (display script port)))
       (cond
        ((not interactive?)
         (let ((case (capture-command bash script-file)))
           (list (first case) (second case) (slurp stderr-file))))
        ((not (which "script"))
         (list 0 "script(1) is not installed, skipped" ""))
        (else
         ;; script(1) gives bash the terminal it insists on.  Its -c argument
         ;; is a command line, and the only things in it are a program path and
         ;; a temporary file name this run created.
         (let ((case (capture-command
                      (which "script") "-q" "-e" "-c"
                      (string-append bash " -i " script-file)
                      "/dev/null")))
           (list (first case) (second case) ""))))))))

(define (prepare-home)
  "Create a temporary home with the rendered rc at ~/.bashrc, and return it."
  (let ((home (make-temp-dir)))
    ;; install-bash reports where it wrote; a test run wants the bytes, not
    ;; the line, so the message is captured and dropped.
    (with-output-to-string
      (lambda () (bash:install-bash #:target (string-append home "/.bashrc"))))
    home))

;;; ====== The rendered file, as data =======================================

(define rendered (string-join (bash:bash-config) "\n"))

(define (rendered-contains? needle)
  (string-contains rendered needle))

(test-begin "rendered-config")

(test-assert "rendering twice gives the same bytes"
             (string=? rendered (string-join (bash:bash-config) "\n")))

(test-assert "machine identity reaches the file"
             (rendered-contains? "CC_FLAVOR=\"heks-bash\""))

(test-assert "the version reaches the file"
             (rendered-contains? (format #f "CC_VERSION=\"~a\""
                                         (bash:heks-bash-version))))

(test-assert "no absolute home path is baked in"
             (let ((home (getenv "HOME")))
               (not (and home
                         (not (string-null? home))
                         (rendered-contains? home)))))

(test-assert "every alias is serialized"
             (every (lambda (alias)
                      (rendered-contains? (format #f "alias ~a=\""
                                                  (car alias))))
                    (bash:bash-aliases)))

(test-assert "git shortcuts are functions, not aliases"
             (every (lambda (shortcut)
                      (rendered-contains? (format #f "~a () {"
                                                  (car shortcut))))
                    bash:bash-git-shortcuts))

(test-assert "the greetings pool is data in the file"
             (and (rendered-contains? "CC_GREETINGS=(")
                  (rendered-contains? (car (bash:bash-greetings)))))

(test-assert "the completion layer is behind a capability check"
             (and (rendered-contains? "CC_COMPLETIONS=1")
                  (rendered-contains? "shopt -q progcomp")))

(test-assert "the notes completer is guarded too"
             (rendered-contains? "__cc_has complete && complete -F _n_complete n"))

(test-assert "every prepended path is tested before it is used"
             (every (lambda (path)
                      (rendered-contains? (format #f "[[ -d \"~a\" ]]" path)))
                    (bash:bash-path-prepends)))

(test-assert "the pager keymap is rendered from Scheme"
             (let ((lesskey (bash:serialize-lesskey)))
               (and (string-contains lesskey "#command")
                    (string-contains lesskey "#line-edit")
                    (string-contains lesskey "forw-line"))))

(test-assert "the checked-in lesskey is that rendering, not a second source"
             ;; The sibling repositories carry this file, so it is committed;
             ;; `maak render' refreshes it and this test is what notices when
             ;; someone edited one of the two by hand.
             (string=? (slurp (string-append "src/heks-bash/"
                                             (bash:lesskey-filename)))
                       (bash:serialize-lesskey)))

(test-assert "the tool table is rendered from Scheme"
             (let ((tools (bash:serialize-bash-tools)))
               (and (string-contains tools "CC_TOOLS=(")
                    (string-contains tools "eca-cli"))))

(test-end "rendered-config")

;;; ====== The rendered file, in a shell ====================================

(test-begin "shell")

(let ((home #f))
  (test-assert "sourcing the rc prints nothing on standard error"
               (let* ((home (prepare-home))
                      (case (run-shell-case home ". \"$HOME/.bashrc\"\n"))
                      (exit (first case))
                      (stderr (third case)))
                 (delete-tree home)
                 (test-equal "exit status" 0 exit)
                 (test-equal "stderr" "" stderr)
                 #t)))

(test-assert "about answers with the identity and the version"
             (let* ((home (prepare-home))
                    (case (run-shell-case home ". \"$HOME/.bashrc\"\nabout\n"))
                    (stdout (second case)))
               (delete-tree home)
               (and (string-contains stdout (bash:heks-bash-version))
                    (string-contains stdout "heks-bash")
                    (string-contains stdout "kind"))))

(test-assert "pager-keys prints the map it installed"
             (let* ((home (prepare-home))
                    (case (run-shell-case home ". \"$HOME/.bashrc\"\npager-keys\n"))
                    (stdout (second case)))
               (delete-tree home)
               (and (string-contains stdout "pager")
                    (string-contains stdout "search forward"))))

(test-assert "tools names every tool and says what is missing"
             (let* ((home (prepare-home))
                    (case (run-shell-case home ". \"$HOME/.bashrc\"\ntools\n"))
                    (stdout (second case)))
               (delete-tree home)
               (every (lambda (tool) (string-contains stdout (car tool)))
                      (bash:bash-tools))))

(test-assert "the notes command answers"
             (let* ((home (prepare-home))
                    (case (run-shell-case home ". \"$HOME/.bashrc\"\nn help\n"))
                    (stdout (second case)))
               (delete-tree home)
               (string-contains stdout "n capture")))

(test-assert "a bash without progcomp skips the completion layer quietly"
             (let* ((home (prepare-home))
                    (case (run-shell-case
                           home
                           (string-append
                            "enable -n complete 2>/dev/null\n"
                            "enable -n bind 2>/dev/null\n"
                            ". \"$HOME/.bashrc\"\n"
                            "echo \"COMPLETIONS=$CC_COMPLETIONS\"\n"))
                           )
                    (exit (first case))
                    (stdout (second case))
                    (stderr (third case)))
               (delete-tree home)
               (test-equal "exit status" 0 exit)
               (test-equal "stderr" "" stderr)
               (string-contains stdout "COMPLETIONS=0")))

(test-assert "the PATH the rc builds has no entry that does not exist"
             (let* ((home (prepare-home))
                    (case (run-shell-case
                           home
                           (string-append
                            ". \"$HOME/.bashrc\"\n"
                            "printf '%s\\n' \"$PATH\" | tr ':' '\\n' | "
                            "while read -r p; do [[ -d $p ]] || echo \"dead:$p\"; done\n")))
                    (stdout (second case)))
               (delete-tree home)
               (not (string-contains stdout "dead:"))))

(test-assert "an interactive shell starts on a pty and greets"
             (let* ((home (prepare-home))
                    ;; bash -i sources the rc by itself here.
                    (case (run-shell-case home "echo MARK-$CC_FLAVOR\nexit\n"
                                          #:interactive? #t
                                          #:term "xterm-256color"))
                    (exit (first case))
                    (stdout (second case)))
               (delete-tree home)
               (and (zero? exit)
                    (string-contains stdout "MARK-heks-bash"))))

(test-end "shell")

;;; ====== Startup cost =====================================================

;; A budget, not a benchmark: the number exists so a change that puts a fork in
;; the prompt or a plugin in the startup path fails here instead of being felt.
;; The median of a handful of runs is stable enough on a machine that is also
;; running something else, which a mean is not.

(define startup-runs 5)
(define startup-budget-ms 700)

(define (median numbers)
  (let* ((sorted (sort numbers <))
         (count (length sorted)))
    (list-ref sorted (quotient count 2))))

(define (measure-startup home)
  "Return the cost in milliseconds of sourcing the rc in @var{home}, one sample
per run."
  (let ((case (run-shell-case
               home
               (string-append
                "for i in $(seq " (number->string startup-runs) "); do\n"
                ;; EPOCHREALTIME carries the locale's decimal separator, which
                ;; awk reads as the end of the number.
                "    t0=${EPOCHREALTIME//,/.}\n"
                "    ( . \"$HOME/.bashrc\" ) >/dev/null 2>&1\n"
                "    t1=${EPOCHREALTIME//,/.}\n"
                "    LC_ALL=C awk -v a=\"$t0\" -v b=\"$t1\""
                " 'BEGIN { printf \"%.1f\\n\", (b - a) * 1000 }'\n"
                "done\n"))))
    (delete "" (map string-trim-both (string-split (second case) #\newline)))))

(test-begin "startup")

(test-assert "sourcing the rc stays inside its budget"
             (let* ((home (prepare-home))
                    (samples (filter-map string->number (measure-startup home))))
               (delete-tree home)
               (if (null? samples)
                   (begin
                     (format (current-error-port)
                             "~%startup: no samples, the measurement is broken~%~%")
                     #f)
                   (let ((ms (median samples)))
                     (format (current-error-port)
                             "~%startup: median ~a ms of ~a runs (budget ~a ms)~%~%"
                             ms (length samples) startup-budget-ms)
                     (< ms startup-budget-ms)))))

(test-end "startup")

;;; ====== Verdict ==========================================================

(let* ((failures (test-runner-fail-count test-runner))
       (passed (test-runner-pass-count test-runner)))
  (format #t "~%~a passed, ~a failed~%" passed failures)
  (exit (if (and (zero? failures) (positive? passed)) 0 1)))

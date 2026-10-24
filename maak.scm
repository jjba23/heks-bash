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

;;; Commentary:
;;
;; Repository tasks, run with maak.
;;
;; Each task names the program it runs and lets maak build the argv, so a path
;; with a space in it stays one argument and a program that fails raises where
;; the task can see it.  `time-machine-manifest-shell` covers the tasks that
;; need the project's own libraries, which are in the pinned manifest rather
;; than in the machine's profile.

;;; Code:

(define-module (maak)
  #:declarative? #t
  #:use-module (maak maak))

(define (default)
  "List the tasks this project defines."
  (list-tasks))

(define (install-bash)
  "Install the Bash configuration and completions heks-bash ships."
  (time-machine-manifest-shell
   (list "guile -L ./src -c" "'((@(heks-bash bash) install-bash))'")
   #:verbose? #t))

(define (install-ble-sh)
  "Install ble.sh from upstream under ~/.local.

The upstream tree is cloned shallow with its submodules -- ble.sh vendors its
own completion packages that way -- and `make install' is pointed at ~/.local,
so nothing outside the home directory is touched."
  (let ((source "/tmp/ble.sh")
        (prefix (format #f "PREFIX=~a/.local" (getenv "HOME"))))
    (delete-file-recursively source)
    (run (list "git" "clone" "--recursive" "--depth" "1"
               "--shallow-submodules"
               "https://github.com/akinomyoga/ble.sh.git" source)
         #:verbose? #t)
    (run (list "make" "-C" source "install" prefix)
         #:verbose? #t)))

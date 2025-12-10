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

(define-module (maak)
  #:declarative? #t
  #:use-module (maak maak))

(define (install-bash)
  (time-machine-manifest-shell (list "guile -L ./src -c"
                                     "'((@(heks-bash bash) install-bash))'")
                               #:verbose? #t))

(define (install-ble-sh)
  ($ '("cd /tmp &&" "git clone --recursive --depth 1 --shallow-submodules "
       "https://github.com/akinomyoga/ble.sh.git" " &&"
       "make -C ble.sh install PREFIX=~/.local")))

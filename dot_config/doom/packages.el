;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here and run 'doom sync'
;; on the command line, then restart Emacs for the changes to take effect -- or
;; use 'M-x doom/reload'.


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;(package! some-package)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/radian-software/straight.el#the-recipe-format
;(package! another-package
;  :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;(package! this-package
;  :recipe (:host github :repo "username/repo"
;           :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;(package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;(package! builtin-package :recipe (:nonrecursive t))
;(package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see radian-software/straight.el#279)
;(package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
;(package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
;(unpin! pinned-package)
;; ...or multiple packages
;(unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
;(unpin! t)

;; https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org#installing-packages-from-external-sources
;; Install it directly from a github repository. For this to work, the package
;; must have an appropriate PACKAGENAME.el file which must contain at least a
;; Package-Version or Version line in its header.
(package! go-translate
  :recipe (:host github :repo "lorniu/go-translate"))

;; FIXME M-x package-install 生成了 ~/.config/doom/custom.el
;; (package! google-translate
;;   :recipe (:host github :repo "atykhonov/google-translate"))

;; FIXME emacs-everywhere-clipboard-sleep-delay | https://github.com/tecosaur/emacs-everywhere/issues/54
;; (unpin! (:app everywhere))

;; https://github.com/zerolfx/copilot.el#example-for-doom-emacs
(package! copilot
  :recipe (:host github :repo "zerolfx/copilot.el" :files ("*.el" "dist")))

;; https://github.com/DogLooksGood/emacs-rime/blob/master/INSTALLATION.org#macos-1
(package! rime
  :recipe (:host github :repo "DogLooksGood/emacs-rime" :files ("*.el" "Makefile" "lib.c")))

;; https://codeberg.org/ideasman42/emacs-idle-highlight-mode
(package! idle-highlight-mode
  :recipe (:host codeberg :repo "ideasman42/emacs-idle-highlight-mode"))

(package! immersive-translate
  :recipe (:host github :repo "Elilif/emacs-immersive-translate"))

(package! mermaid-mode
  :recipe (:host github :repo "abrochard/mermaid-mode"))

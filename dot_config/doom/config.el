;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "John Doe"
      user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; https://github.com/doomemacs/doomemacs/blob/master/docs/faq.org#change-my-fonts
;; https://github.com/doomemacs/doomemacs/blob/develop/docs/faq.org#how-do-i-change-the-fonts
;; (setq doom-font "JetBrainsMono Nerd Font:pixelsize=12:weight=light:slant=normal:width=normal:spacing=0:scalable=true")
;; M-x nerd-icons-install-fonts
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 12 :weight 'light)
      doom-variable-pitch-font (font-spec :family "IBM Plex Sans") ; TODO what is this?
      ;; 这样设置会导致emoji等unicode字符显示不了 (在不勾选init.el中的emoji时)
      ;; doom-unicode-font (font-spec :family "LXGW WenKai Mono")
      ;; doom-unicode-font (font-spec :family "Sarasa Mono SC" :weight 'semi-light)
      doom-big-font (font-spec :family "JetBrainsMono Nerd Font" :size 18 :weight 'light))
;; https://emacs-china.org/t/doom-emacs/23513/10
(defun my-cjk-font()
  (dolist (charset '(kana han cjk-misc symbol bopomofo))
    (set-fontset-font t charset (font-spec :family "Sarasa Mono SC" :weight 'semi-light))))
(add-hook 'after-setting-font-hook #'my-cjk-font)

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; https://discourse.doomemacs.org/t/maximize-or-fullscreen-emacs-on-startup/135
;; https://emacsredux.com/blog/2020/12/04/maximize-the-emacs-frame-on-startup/
(add-to-list 'initial-frame-alist '(fullscreen . maximized))

;; No Titlebar
;; https://github.com/d12frosted/homebrew-emacs-plus#emacs-29-and-emacs-30
;; (add-to-list 'default-frame-alist '(undecorated . t)) ; square corners
(add-to-list 'default-frame-alist '(undecorated-round . t)) ; round corners

;; M-x describe-key
(map! :nvo "H" 'evil-first-non-blank)
(map! :nvo "L" 'evil-end-of-line)

;; https://discourse.doomemacs.org/t/typing-jk-deletes-j-and-returns-to-normal-mode/59/7
;; ~/.config/doomemacs/modules/editor/evil/config.el#L339
(after! evil-escape
  (setq evil-escape-key-sequence "jj"
        evil-escape-delay 0.3))

;; this is bad for "enter normal mode" and "send j/k" for zsh-vi-mode in vterm
;; https://stackoverflow.com/questions/10569165/how-to-map-jj-to-esc-in-emacs-evil-mode
;; kj -> esc
;; (define-key evil-insert-state-map "k" #'cofi/maybe-exit-k)
;; (evil-define-command cofi/maybe-exit-k ()
;;   :repeat change
;;   (interactive)
;;   (let ((modified (buffer-modified-p)))
;;     (insert "k")
;;     (let ((evt (read-event (format "Insert %c to exit insert state" ?j)
;;                nil 0.2)))
;;       (cond
;;        ((null evt) (message ""))
;;        ((and (integerp evt) (char-equal evt ?j))
;;     (delete-char -1)
;;     (set-buffer-modified-p modified)
;;     (push 'escape unread-command-events))
;;        (t (setq unread-command-events (append unread-command-events
;;                           (list evt))))))))
;; jk -> esc
;; (define-key evil-insert-state-map "j" #'cofi/maybe-exit-j)
;; (evil-define-command cofi/maybe-exit-j ()
;;   :repeat change
;;   (interactive)
;;   (let ((modified (buffer-modified-p)))
;;     (insert "j")
;;     (let ((evt (read-event (format "Insert %c to exit insert state" ?k)
;;                nil 0.2)))
;;       (cond
;;        ((null evt) (message ""))
;;        ((and (integerp evt) (char-equal evt ?k))
;;     (delete-char -1)
;;     (set-buffer-modified-p modified)
;;     (push 'escape unread-command-events))
;;        (t (setq unread-command-events (append unread-command-events
;;                           (list evt))))))))

;; TODO `:!java -version` is still 1.8, is this matter?
;; https://xpressrazor.wordpress.com/2020/11/04/java-programming-in-emacs/
(setenv "JAVA_HOME" "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home")
(setq lsp-java-java-path "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home/bin/java")
;; https://github.com/emacs-lsp/lsp-java#faq
(setq lsp-java-configuration-runtimes '[(:name "JavaSE-17"
                                                :path "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home")
                                        (:name "JavaSE-1.8"
                                                :path "/Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home"
                                                :default t)])
;; current VSCode defaults
;; (setq lsp-java-vmargs '("-XX:+UseParallelGC" "-XX:GCTimeRatio=4" "-XX:AdaptiveSizePolicyWeight=90" "-Dsun.zip.disableMemoryMapping=true" "-Xmx2G" "-Xms100m"))
;; ~/Library/Application Support/JetBrains/IdeaIC2023.1/idea.vmoptions
(setq lsp-java-vmargs '("-XX:+UseParallelGC" "-XX:GCTimeRatio=4" "-XX:AdaptiveSizePolicyWeight=90" "-Dsun.zip.disableMemoryMapping=true" "-Xmx4096m" "-Xms2048m"))
;; TODO https://github.com/emacs-lsp/lsp-java#spring-boot-support-experimental

;; https://github.com/lorniu/go-translate#more-configuration
;; https://github.com/lorniu/go-translate/issues/6
;; go-translate: https://github.com/lorniu/go-translate
(after! go-translate
  (setq gts-translate-list '(("en" "zh")))
  (setq gts-default-translator
        (gts-translator
         ;; :picker (gts-prompt-picker)
         :picker (gts-noprompt-picker)
         :engines ; engines, one or more. Provide a parser to give different output.
         (list
          (gts-bing-engine)
          ;;(gts-deepl-engine :auth-key [YOUR_AUTH_KEY] :pro nil)
          (gts-google-engine :parser (gts-google-summary-parser))
          (gts-google-rpc-engine))
         ;; :render (gts-buffer-render)
         :render (gts-posframe-pop-render)
         ))
  ;; disable the evil mode to allow plugin keybindings: https://github.com/lorniu/go-translate/issues/6#issuecomment-700038291
  (add-hook 'gts-after-buffer-render-hook ;; use 'gts-after-buffer-multiple-render-hook instead if you have multiple engines
            (defun your-hook-that-disable-evil-mode-in-go-translate-buffer (&rest _)
              (turn-off-evil-mode)))
  )
(map! :leader :desc "Translate" :nv "T" #'gts-do-translate)

;; FIXME
;; (after! google-translate
;;   (setq google-translate-default-source-language "en")
;;   (setq google-translate-default-target-language "zh-CN")
;;   (setq google-translate-backend-method 'curl))

;; https://github.com/zerolfx/copilot.el#example-for-doom-emacs
;; accept completion from copilot and fallback to company
(use-package! copilot
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . 'copilot-accept-completion)
              ("TAB" . 'copilot-accept-completion)
              ("C-TAB" . 'copilot-accept-completion-by-word)
              ("C-<tab>" . 'copilot-accept-completion-by-word)
              ("M-n" . 'copilot-next-completion) ; https://github.com/zerolfx/copilot.el/issues/103
              ("M-p" . 'copilot-previous-completion)))

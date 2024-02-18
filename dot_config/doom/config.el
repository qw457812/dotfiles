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
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 13 :weight 'light)
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
;; (map! :leader :desc "Translate" :nv "T" #'gts-do-translate)

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

;; https://github.com/DogLooksGood/emacs-rime
(use-package! rime
  :custom
  (default-input-method "rime")
  ;; curl -L -O https://github.com/rime/librime/releases/download/1.8.5/rime-08dd95f-macOS.tar.bz2
  (rime-librime-root "~/librime/dist")
  ;; 共享目录：Rime 安装后放置配置（包括输入方案）的目录
  ;; Squirrel 0.16.2
  (rime-share-data-dir "~/Library/Rime/")
  ;; 用户目录：emacs-rime 布署的位置（包括词频等）。默认为 ~/.emacs.d/rime
  (rime-user-data-dir "~/.config/emacs-rime")
  (rime-emacs-module-header-root "/opt/homebrew/opt/emacs-plus@29/include")
  ;; 候选框展示风格
  ;; (rime-show-candidate 'posframe) ; 使用 posframe 展示跟随的候选，在不可用的时候会用 popup
  ;; (rime-show-candidate 'minibuffer) ; 在 minibuffer 中展示， 推荐使用的方式
  (rime-show-candidate nil) ; 不展示
  ;; 编码的展示形式
  ;; (rime-show-preedit 'inline) ; 替换上屏预览
  ;; (rime-show-preedit t) ; 展示在菜单中
  (rime-show-preedit nil) ; 不展示
  ;; (rime-cursor "˰")
  :bind
  (:map rime-mode-map
        ("C-`" . 'rime-send-keybinding)))
(setq rime-posframe-properties
 (list :font "Sarasa UI SC:pixelsize=16:weight=regular:slant=normal:width=normal:spacing=0:scalable=true"
       ;; :internal-border-width 10
       :internal-border-width 7))
;; 自动化设置
;; 临时英文模式：其中有任何一个断言的值 **不是** nil 时，会自动使用英文
(setq rime-disable-predicates
      '(rime-predicate-evil-mode-p                   ; 在 evil-mode 的非编辑状态下
        rime-predicate-after-alphabet-char-p         ; 在英文字符串之后（必须为以字母开头的英文字符串）
        ;; rime-predicate-prog-in-code-p                ; 在 prog-mode 和 conf-mode 中除了注释和引号内字符串之外的区域
        ;; rime-predicate-after-ascii-char-p            ; 任意英文字符后
        rime-predicate-in-code-string-p              ; 在代码的字符串中，不含注释的字符串
        rime-predicate-ace-window-p                  ; 激活 ace-window-mode
        rime-predicate-hydra-p                       ; 如果激活了一个 hydra keymap
        ;; rime-predicate-current-input-punctuation-p   ; 当要输入的是符号时
        rime-predicate-punctuation-after-space-cc-p  ; 当要在中文字符且有空格之后输入符号时
        rime-predicate-punctuation-after-ascii-p     ; 当要在任意英文字符之后输入符号时
        rime-predicate-punctuation-line-begin-p      ; 在行首要输入符号时
        ;; rime-predicate-space-after-ascii-p           ; 在任意英文字符且有空格之后
        rime-predicate-space-after-cc-p              ; 在中文字符且有空格之后
        rime-predicate-current-uppercase-letter-p    ; 将要输入的为大写字母时
        rime-predicate-tex-math-or-command-p         ; 在 (La)TeX 数学环境中或者输入 (La)TeX 命令时
        ))
;; 可提示临时英文状态的提示符：如下设置可替换输入法的符号，使其用颜色提示当前的临时英文状态
(setq mode-line-mule-info '((:eval (rime-lighter))))
;; 虎码jj从
;; 结合 evil-escape 一起使用 (以下代码可能有性能问题)
;; (defun rime-evil-escape-advice (orig-fun key)
;;   "advice for `rime-input-method' to make it work together with `evil-escape'.
;;         Mainly modified from `evil-escape-pre-command-hook'"
;;   (if rime--preedit-overlay
;;       ;; if `rime--preedit-overlay' is non-nil, then we are editing something, do not abort
;;       (apply orig-fun (list key))
;;     (when (featurep 'evil-escape)
;;       (let (
;;             (fkey (elt evil-escape-key-sequence 0))
;;             (skey (elt evil-escape-key-sequence 1))
;;             )
;;         (if (or (char-equal key fkey)
;;                 (and evil-escape-unordered-key-sequence
;;                      (char-equal key skey)))
;;             (let ((evt (read-event nil nil evil-escape-delay)))
;;               (cond
;;                ((and (characterp evt)
;;                      (or (and (char-equal key fkey) (char-equal evt skey))
;;                          (and evil-escape-unordered-key-sequence
;;                               (char-equal key skey) (char-equal evt fkey))))
;;                 (evil-repeat-stop)
;;                 (evil-normal-state))
;;                ((null evt) (apply orig-fun (list key)))
;;                (t
;;                 (apply orig-fun (list key))
;;                 (if (numberp evt)
;;                     (apply orig-fun (list evt))
;;                   (setq unread-command-events (append unread-command-events (list evt))))))
;;               )
;;           (apply orig-fun (list key)))))))
;; (advice-add 'rime-input-method :around #'rime-evil-escape-advice)

;; https://github.com/hlissner/evil-snipe
;; ~/.config/doomemacs/modules/editor/evil/config.el
;; https://www.const.no/init/
(after! evil-snipe
  (setq evil-snipe-scope 'visible))

;; FIXME 无法区分 idle-highlight 与 evil-visual-state 的高亮
;; https://codeberg.org/ideasman42/emacs-idle-highlight-mode
;; (use-package! idle-highlight-mode
;;   :config (setq idle-highlight-idle-time 0.2)
;;   :hook ((prog-mode text-mode) . idle-highlight-mode))

(use-package! immersive-translate)
;; https://github.com/Elilif/emacs-immersive-translate
;; (require 'immersive-translate)
(add-hook 'elfeed-show-mode-hook #'immersive-translate-setup)
(add-hook 'nov-pre-html-render-hook #'immersive-translate-setup)
;; use Baidu Translation
;; (setq immersive-translate-backend 'baidu
;;       immersive-translate-baidu-appid "your-appid")
;; use ChatGPT
;; (setq immersive-translate-backend 'chatgpt
;;       immersive-translate-chatgpt-host "api.openai.com")
;; use translate-shell
(setq immersive-translate-backend 'trans)
(map! :leader :desc "Translate" :n "T" #'immersive-translate-paragraph)

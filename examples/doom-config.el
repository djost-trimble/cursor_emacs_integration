;;; examples/doom-config.el --- Example Doom Emacs configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; This file shows example configurations for using cursor-mode in Doom Emacs.
;; Copy relevant sections to your ~/.doom.d/config.el

;;; Code:

;;; Basic Setup
;; Add to ~/.doom.d/config.el after (doom! ...) block

(use-package! cursor-mode
  :config
  ;; Enable globally
  (global-cursor-mode 1)
  
  ;; Basic settings
  (setq cursor-api-endpoint "http://localhost:8765"
        cursor-websocket-endpoint "ws://localhost:8765"
        cursor-default-model "claude-4-sonnet"
        cursor-auto-start-session t)
  
  ;; Sync settings
  (setq cursor-sync-debounce-delay 0.5
        cursor-sync-max-size (* 10 1024 1024)
        cursor-sync-on-conflict 'ask
        cursor-sync-ignore-patterns
        '("node_modules/" ".git/" "*.log" "*.tmp" "*~" "#*#"
          "dist/" "build/" "__pycache__/"))
  
  ;; Chat settings
  (setq cursor-chat-window-side 'right
        cursor-chat-window-width 80
        cursor-chat-save-history t))

;;; Keybindings
;; Doom-style leader key bindings

(map! :leader
      (:prefix ("c" . "cursor agent")
       :desc "Ask agent" "k" #'cursor-ask-agent
       :desc "Open chat" "c" #'cursor-open-chat
       :desc "Fix at point" "f" #'cursor-fix-at-point
       :desc "Explain region" "e" #'cursor-explain-region
       :desc "Refactor region" "R" #'cursor-refactor-region
       :desc "Optimize function" "o" #'cursor-optimize-function
       :desc "Generate tests" "t" #'cursor-generate-tests
       :desc "Generate docstring" "d" #'cursor-generate-docstring
       :desc "View context" "v" #'cursor-show-context
       :desc "Set context scope" "S" #'cursor-set-context-scope
       :desc "Start session" "s" #'cursor-start-session
       :desc "Resume session" "r" #'cursor-resume-session
       :desc "List sessions" "l" #'cursor-list-sessions
       :desc "End session" "q" #'cursor-end-session
       (:prefix ("p" . "sync")
        :desc "Push changes" "p" #'cursor-sync-push
        :desc "Pull changes" "P" #'cursor-sync-pull
        :desc "Sync status" "s" #'cursor-sync-status)))

;;; Evil Mode Keybindings
;; Direct keybindings for normal and visual modes

(map! :mode cursor-mode
      :n "g a" #'cursor-ask-agent
      :n "g f" #'cursor-fix-at-point
      :n "g e" #'cursor-explain-region
      :n "g c" #'cursor-open-chat
      :v "g a" #'cursor-ask-agent
      :v "g e" #'cursor-explain-region
      :v "g r" #'cursor-refactor-region)

;;; Advanced Configuration

;; Automatically start session for specific projects
(defun my/cursor-maybe-start-session ()
  "Start cursor session for specific projects."
  (when (and (project-current)
             (string-match-p "my-project" (project-root (project-current)))
             (not cursor--current-session-id))
    (cursor-start-session)))

(add-hook 'find-file-hook #'my/cursor-maybe-start-session)

;; Custom model selection per project
(defun my/cursor-select-model ()
  "Select appropriate model based on project."
  (cond
   ((string-match-p "python" default-directory) "claude-4-sonnet")
   ((string-match-p "javascript\\|typescript" default-directory) "gpt-5-mini")
   (t "claude-4-sonnet")))

(setq cursor-default-model (my/cursor-select-model))

;; Custom sync patterns per language
(defun my/cursor-sync-patterns ()
  "Set sync patterns based on major mode."
  (pcase major-mode
    ('python-mode
     (setq-local cursor-sync-ignore-patterns
                (append cursor-sync-ignore-patterns
                       '("*.pyc" "__pycache__/" ".venv/" ".pytest_cache/"))))
    ('js-mode
     (setq-local cursor-sync-ignore-patterns
                (append cursor-sync-ignore-patterns
                       '("node_modules/" "dist/" ".next/" "coverage/"))))))

(add-hook 'cursor-sync-mode-hook #'my/cursor-sync-patterns)

;; Integration with other Doom modules
(after! projectile
  ;; Automatically enable cursor-mode in projects
  (defun my/enable-cursor-in-project ()
    (when (projectile-project-p)
      (cursor-mode 1)))
  (add-hook 'projectile-after-switch-project-hook #'my/enable-cursor-in-project))

(after! company
  ;; Disable company while typing in chat buffer
  (add-hook 'cursor-chat-mode-hook
           (lambda ()
             (company-mode -1))))

(after! evil
  ;; Custom evil motions for chat navigation
  (evil-define-motion my/cursor-chat-next-message (count)
    "Jump to next message in chat."
    :type exclusive
    (re-search-forward "^\\(You\\|Agent\\):" nil t count))
  
  (evil-define-motion my/cursor-chat-prev-message (count)
    "Jump to previous message in chat."
    :type exclusive
    (re-search-backward "^\\(You\\|Agent\\):" nil t count))
  
  (map! :map cursor-chat-mode-map
        :n "]m" #'my/cursor-chat-next-message
        :n "[m" #'my/cursor-chat-prev-message))

;; Modeline integration
(after! doom-modeline
  (defun my/cursor-modeline-segment ()
    "Display cursor session in modeline."
    (when (and cursor-mode cursor--current-session-id)
      (concat
       " "
       (propertize "󰚩" 'face 'doom-modeline-info)
       " "
       (propertize (substring cursor--current-session-id 0 8)
                  'face 'doom-modeline-buffer-minor-mode))))
  
  (add-to-list 'doom-modeline-fn-alist
              '(cursor-session . my/cursor-modeline-segment)))

;; Popup rules for cursor buffers
(set-popup-rule! "^\\*cursor-chat:" :side 'right :width 0.4 :select t :quit nil)
(set-popup-rule! "^\\*Cursor Sessions\\*" :side 'bottom :height 0.3 :select t :quit t)
(set-popup-rule! "^\\*Cursor Sync Conflict\\*" :side 'bottom :height 0.3 :select t :quit nil)

;; Workspace integration
(after! persp-mode
  ;; Save cursor sessions per workspace
  (defvar my/cursor-workspace-sessions (make-hash-table :test 'equal)
    "Map of workspace to cursor session ID.")
  
  (defun my/cursor-save-workspace-session ()
    "Save current cursor session for workspace."
    (when (and cursor--current-session-id
               (bound-and-true-p persp-mode))
      (puthash (safe-persp-name (get-current-persp))
              cursor--current-session-id
              my/cursor-workspace-sessions)))
  
  (defun my/cursor-restore-workspace-session ()
    "Restore cursor session for workspace."
    (when (bound-and-true-p persp-mode)
      (let ((session (gethash (safe-persp-name (get-current-persp))
                             my/cursor-workspace-sessions)))
        (when session
          (cursor-resume-session session)))))
  
  (add-hook 'persp-before-switch-functions #'my/cursor-save-workspace-session)
  (add-hook 'persp-activated-functions #'my/cursor-restore-workspace-session))

;; Snippets integration
(after! yasnippet
  ;; Create snippet from agent suggestion
  (defun my/cursor-create-snippet ()
    "Create yasnippet from last agent response."
    (interactive)
    (let* ((last-msg (car cursor-chat--message-history))
           (content (plist-get last-msg :content))
           (name (read-string "Snippet name: "))
           (key (read-string "Snippet key: "))
           (mode (intern (read-string "Mode: " (symbol-name major-mode)))))
      (yas-new-snippet)
      (insert (format "# -*- mode: snippet -*-\n"))
      (insert (format "# name: %s\n" name))
      (insert (format "# key: %s\n" key))
      (insert (format "# --\n%s" content))
      (message "Created snippet: %s" name))))

;; Which-key integration
(after! which-key
  (which-key-add-key-based-replacements
    "SPC c" "cursor agent"
    "SPC c p" "sync"
    "SPC c s" "start session"
    "SPC c r" "resume session"))

;;; Performance Optimizations

;; Disable sync for large files
(defun my/cursor-check-file-size ()
  "Disable sync for very large files."
  (when (> (buffer-size) (* 5 1024 1024))  ; 5MB
    (cursor-sync-mode -1)
    (message "Sync disabled: file too large")))

(add-hook 'cursor-sync-mode-hook #'my/cursor-check-file-size)

;; Batch sync for multiple buffers
(defun my/cursor-sync-all-buffers ()
  "Push all modified buffers with sync enabled."
  (interactive)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and cursor-sync-mode
                (buffer-modified-p)
                (buffer-file-name))
        (cursor-sync-push buffer)))))

;; Keyboard macro for common workflows
(fset 'my/cursor-review-and-apply
     "\C-c c e\C-x o\C-x o")  ; Explain, switch to chat, switch back

(global-set-key (kbd "C-c c x") 'my/cursor-review-and-apply)

;;; Hook Examples

;; Automatically explain on error
(defun my/cursor-explain-error ()
  "Ask cursor to explain error at point."
  (when (and cursor-mode
             (bound-and-true-p flycheck-mode)
             (flycheck-overlay-errors-at (point)))
    (cursor-fix-at-point)))

;; Ask for commit message
(defun my/cursor-generate-commit-message ()
  "Ask cursor to generate a commit message."
  (interactive)
  (when (and cursor-mode (magit-toplevel))
    (let ((diff (shell-command-to-string "git diff --cached")))
      (cursor-ask-agent
       (format "Generate a concise commit message for these changes:\n\n%s"
              (substring diff 0 (min (length diff) 2000)))))))

(after! magit
  (map! :map magit-status-mode-map
        :n "g m" #'my/cursor-generate-commit-message))

;;; examples/doom-config.el ends here

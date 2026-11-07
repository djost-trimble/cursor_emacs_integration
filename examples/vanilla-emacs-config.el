;;; examples/vanilla-emacs-config.el --- Example vanilla Emacs configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; This file shows example configurations for using cursor-mode in vanilla Emacs.
;; Copy relevant sections to your ~/.emacs or ~/.emacs.d/init.el

;;; Code:

;;; Basic Setup

;; Add to load path
(add-to-list 'load-path "/path/to/cursor-emacs-integration/elisp")

;; Load the package
(require 'cursor-mode)

;; Enable globally
(global-cursor-mode 1)

;;; Configuration

(setq cursor-api-endpoint "http://localhost:8765"
      cursor-websocket-endpoint "ws://localhost:8765"
      cursor-default-model "claude-4-sonnet"
      cursor-auto-start-session t)

;; Sync configuration
(setq cursor-sync-debounce-delay 0.5
      cursor-sync-max-size (* 10 1024 1024)
      cursor-sync-on-conflict 'ask)

;; Chat configuration
(setq cursor-chat-window-side 'right
      cursor-chat-window-width 80
      cursor-chat-save-history t)

;;; Keybindings

;; Global keybindings
(global-set-key (kbd "C-c c k") 'cursor-ask-agent)
(global-set-key (kbd "C-c c c") 'cursor-open-chat)
(global-set-key (kbd "C-c c f") 'cursor-fix-at-point)
(global-set-key (kbd "C-c c e") 'cursor-explain-region)
(global-set-key (kbd "C-c c R") 'cursor-refactor-region)
(global-set-key (kbd "C-c c o") 'cursor-optimize-function)
(global-set-key (kbd "C-c c t") 'cursor-generate-tests)
(global-set-key (kbd "C-c c d") 'cursor-generate-docstring)
(global-set-key (kbd "C-c c v") 'cursor-show-context)
(global-set-key (kbd "C-c c S") 'cursor-set-context-scope)

;; Session management
(global-set-key (kbd "C-c c s") 'cursor-start-session)
(global-set-key (kbd "C-c c r") 'cursor-resume-session)
(global-set-key (kbd "C-c c l") 'cursor-list-sessions)
(global-set-key (kbd "C-c c q") 'cursor-end-session)

;; Sync keybindings
(global-set-key (kbd "C-c c p") 'cursor-sync-push)
(global-set-key (kbd "C-c c P") 'cursor-sync-pull)
(global-set-key (kbd "C-c c S") 'cursor-sync-status)

;;; Integration with built-in modes

;; Enable cursor-mode for programming modes
(add-hook 'prog-mode-hook #'cursor-mode)

;; Automatically start session when opening a project
(defun my/cursor-auto-start ()
  "Automatically start cursor session."
  (when (and (not cursor--current-session-id)
             (buffer-file-name))
    (cursor-start-session)))

(add-hook 'find-file-hook #'my/cursor-auto-start)

;;; Window Management

;; Display chat in side window
(add-to-list 'display-buffer-alist
            '("\\*cursor-chat:.*\\*"
              (display-buffer-in-side-window)
              (side . right)
              (window-width . 80)))

;; Display sessions list at bottom
(add-to-list 'display-buffer-alist
            '("\\*Cursor Sessions\\*"
              (display-buffer-at-bottom)
              (window-height . 10)))

;;; Custom Functions

(defun my/cursor-explain-function-at-point ()
  "Explain the function at point."
  (interactive)
  (save-excursion
    (beginning-of-defun)
    (let ((start (point))
          (end (progn (end-of-defun) (point))))
      (cursor-explain-region start end))))

(global-set-key (kbd "C-c c F") 'my/cursor-explain-function-at-point)

(defun my/cursor-review-buffer ()
  "Ask cursor to review the entire buffer."
  (interactive)
  (cursor-ask-agent
   (format "Review this code for potential issues:\n\n%s"
          (buffer-substring-no-properties (point-min) (point-max)))))

(global-set-key (kbd "C-c c b") 'my/cursor-review-buffer)

;;; Modeline Integration

(defun my/cursor-modeline ()
  "Display cursor status in modeline."
  (when cursor-mode
    (concat
     " [Cursor"
     (when cursor--current-session-id
       (format ":%s" (substring cursor--current-session-id 0 8)))
     "]")))

;; Add to mode-line-format
(setq-default mode-line-format
             (append mode-line-format
                    '((:eval (my/cursor-modeline)))))

;;; Integration with other packages

;; Company mode integration
(when (require 'company nil t)
  ;; Disable company in chat buffer
  (add-hook 'cursor-chat-mode-hook
           (lambda ()
             (company-mode -1))))

;; Flycheck integration
(when (require 'flycheck nil t)
  (defun my/cursor-fix-flycheck-error ()
    "Ask cursor to fix the flycheck error at point."
    (interactive)
    (let ((error (flycheck-overlay-errors-at (point))))
      (when error
        (cursor-ask-agent
         (format "Fix this error: %s"
                (flycheck-error-message (car error)))))))
  
  (global-set-key (kbd "C-c c X") 'my/cursor-fix-flycheck-error))

;; Markdown mode integration
(when (require 'markdown-mode nil t)
  ;; Better rendering in chat
  (add-hook 'cursor-chat-mode-hook
           (lambda ()
             (markdown-display-inline-images))))

;; VC mode integration
(when (require 'vc nil t)
  (defun my/cursor-generate-commit-msg ()
    "Generate commit message using cursor."
    (interactive)
    (let ((diff (shell-command-to-string "git diff --cached")))
      (when (> (length diff) 0)
        (cursor-ask-agent
         (format "Generate a commit message for:\n\n%s"
                (substring diff 0 (min 2000 (length diff))))))))
  
  (global-set-key (kbd "C-c c m") 'my/cursor-generate-commit-msg))

;;; Performance Optimizations

;; Disable sync for remote files
(defun my/cursor-disable-for-remote ()
  "Disable cursor-sync for remote files."
  (when (file-remote-p default-directory)
    (cursor-sync-mode -1)))

(add-hook 'find-file-hook #'my/cursor-disable-for-remote)

;; Limit sync to specific file types
(defun my/cursor-enable-for-code ()
  "Enable cursor-mode only for code files."
  (when (derived-mode-p 'prog-mode 'text-mode)
    (cursor-mode 1)))

(remove-hook 'prog-mode-hook #'cursor-mode)
(add-hook 'after-change-major-mode-hook #'my/cursor-enable-for-code)

;;; examples/vanilla-emacs-config.el ends here

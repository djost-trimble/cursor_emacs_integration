;;; cursor-sync.el --- File synchronization for Cursor Agent -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Cursor Integration
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: tools, ai, cursor
;; URL: https://github.com/cursor/doom-emacs-integration

;;; Commentary:

;; This module provides bidirectional file synchronization between Emacs
;; and Cursor agents, with conflict detection and resolution.

;;; Code:

(require 'cursor-bridge)

(defgroup cursor-sync nil
  "Settings for Cursor file synchronization."
  :group 'cursor
  :prefix "cursor-sync-")

(defcustom cursor-sync-auto-enable t
  "Automatically enable sync when cursor-mode is activated."
  :type 'boolean
  :group 'cursor-sync)

(defcustom cursor-sync-debounce-delay 0.5
  "Delay in seconds before syncing buffer changes."
  :type 'number
  :group 'cursor-sync)

(defcustom cursor-sync-max-size (* 10 1024 1024)
  "Maximum file size to sync (in bytes)."
  :type 'integer
  :group 'cursor-sync)

(defcustom cursor-sync-ignore-patterns
  '("node_modules/" ".git/" "*.log" "*.tmp" "*~" "#*#")
  "Patterns to exclude from synchronization."
  :type '(repeat string)
  :group 'cursor-sync)

(defcustom cursor-sync-on-conflict 'ask
  "What to do when a sync conflict is detected.
- ask: Prompt user to choose
- emacs: Always keep Emacs version
- agent: Always keep agent version
- diff: Show diff and ask"
  :type '(choice (const :tag "Ask user" ask)
                (const :tag "Keep Emacs version" emacs)
                (const :tag "Keep agent version" agent)
                (const :tag "Show diff" diff))
  :group 'cursor-sync)

(defvar-local cursor-sync--version 0
  "Version counter for tracking buffer state.")

(defvar-local cursor-sync--pending-changes nil
  "List of pending changes to sync.")

(defvar-local cursor-sync--debounce-timer nil
  "Timer for debouncing sync operations.")

(defvar cursor-sync--enabled-buffers nil
  "List of buffers with sync enabled.")

(defvar cursor-sync-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c c p") 'cursor-sync-push)
    (define-key map (kbd "C-c c P") 'cursor-sync-pull)
    (define-key map (kbd "C-c c S") 'cursor-sync-status)
    map)
  "Keymap for `cursor-sync-mode'.")

;;;###autoload
(define-minor-mode cursor-sync-mode
  "Minor mode for synchronizing buffer changes with Cursor agent."
  :lighter " CSync"
  :keymap cursor-sync-mode-map
  :group 'cursor-sync
  (if cursor-sync-mode
      (cursor-sync--enable)
    (cursor-sync--disable)))

(defun cursor-sync--enable ()
  "Enable cursor sync for current buffer."
  (when (and (buffer-file-name)
             (cursor-sync--should-sync-p))
    (add-hook 'after-change-functions #'cursor-sync--after-change nil t)
    (add-hook 'before-save-hook #'cursor-sync--before-save nil t)
    (add-to-list 'cursor-sync--enabled-buffers (current-buffer))
    (cursor-sync--setup-websocket-handlers)
    (message "Cursor sync enabled for %s" (buffer-name))))

(defun cursor-sync--disable ()
  "Disable cursor sync for current buffer."
  (remove-hook 'after-change-functions #'cursor-sync--after-change t)
  (remove-hook 'before-save-hook #'cursor-sync--before-save t)
  (setq cursor-sync--enabled-buffers
        (delq (current-buffer) cursor-sync--enabled-buffers))
  (when cursor-sync--debounce-timer
    (cancel-timer cursor-sync--debounce-timer)
    (setq cursor-sync--debounce-timer nil))
  (message "Cursor sync disabled for %s" (buffer-name)))

(defun cursor-sync--should-sync-p ()
  "Check if current buffer should be synced."
  (and (buffer-file-name)
       (< (buffer-size) cursor-sync-max-size)
       (not (cursor-sync--is-binary-p))
       (not (cursor-sync--matches-ignore-pattern-p))))

(defun cursor-sync--is-binary-p ()
  "Check if current buffer contains binary data."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward "[^\000-\177]" (* 1024 8) t)))

(defun cursor-sync--matches-ignore-pattern-p ()
  "Check if current buffer file matches any ignore pattern."
  (let ((file (buffer-file-name)))
    (cl-some (lambda (pattern)
              (string-match-p pattern file))
            cursor-sync-ignore-patterns)))

(defun cursor-sync--setup-websocket-handlers ()
  "Setup WebSocket handlers for sync events."
  (cursor-bridge-ws-on "file-changed"
                      #'cursor-sync--handle-file-changed)
  (cursor-bridge-ws-on "sync-conflict"
                      #'cursor-sync--handle-conflict))

(defun cursor-sync--after-change (beg end len)
  "Track changes in buffer for syncing.
BEG, END, and LEN are the standard after-change-functions arguments."
  (when cursor-sync-mode
    (cl-incf cursor-sync--version)
    (let ((change (list :type (if (zerop len) 'insert 'change)
                       :position beg
                       :length (- end beg)
                       :deleted-length len
                       :text (buffer-substring-no-properties beg end)
                       :version cursor-sync--version)))
      (push change cursor-sync--pending-changes))
    (cursor-sync--schedule-sync)))

(defun cursor-sync--schedule-sync ()
  "Schedule a debounced sync operation."
  (when cursor-sync--debounce-timer
    (cancel-timer cursor-sync--debounce-timer))
  (setq cursor-sync--debounce-timer
        (run-with-timer cursor-sync-debounce-delay nil
                       #'cursor-sync--send-changes (current-buffer))))

(defun cursor-sync--send-changes (buffer)
  "Send pending changes from BUFFER to bridge service."
  (when (and (buffer-live-p buffer)
             (buffer-local-value 'cursor-sync-mode buffer))
    (with-current-buffer buffer
      (when cursor-sync--pending-changes
        (let ((file (buffer-file-name))
              (version cursor-sync--version)
              (changes (nreverse cursor-sync--pending-changes)))
          (cursor-bridge-ws-send
           `((type . "buffer-changed")
             (file . ,file)
             (version . ,version)
             (changes . ,changes)))
          (setq cursor-sync--pending-changes nil)
          (setq cursor-sync--debounce-timer nil))))))

(defun cursor-sync--before-save ()
  "Hook called before saving buffer."
  (when cursor-sync--debounce-timer
    (cancel-timer cursor-sync--debounce-timer)
    (cursor-sync--send-changes (current-buffer))))

(defun cursor-sync--handle-file-changed (msg)
  "Handle file-changed event MSG from WebSocket."
  (let* ((file (alist-get 'file msg))
         (version (alist-get 'version msg))
         (buffer (find-buffer-visiting file)))
    (when (and buffer
               (buffer-local-value 'cursor-sync-mode buffer))
      (with-current-buffer buffer
        (when (< cursor-sync--version version)
          (cursor-sync--pull-changes file))))))

(defun cursor-sync--pull-changes (file)
  "Pull changes for FILE from agent."
  (let ((buffer (find-buffer-visiting file)))
    (when buffer
      (with-current-buffer buffer
        (revert-buffer t t t)
        (message "Pulled agent changes for %s" (file-name-nondirectory file))))))

(defun cursor-sync--handle-conflict (msg)
  "Handle sync conflict MSG."
  (let* ((file (alist-get 'file msg))
         (emacs-version (alist-get 'emacsVersion msg))
         (agent-version (alist-get 'agentVersion msg))
         (buffer (find-buffer-visiting file)))
    (when buffer
      (with-current-buffer buffer
        (message "Sync conflict detected in %s" (file-name-nondirectory file))
        (cursor-sync--resolve-conflict msg)))))

(defun cursor-sync--resolve-conflict (conflict)
  "Resolve sync CONFLICT based on configuration."
  (pcase cursor-sync-on-conflict
    ('emacs
     (message "Keeping Emacs version")
     (cursor-sync-push))
    ('agent
     (message "Keeping agent version")
     (cursor-sync-pull))
    ('diff
     (cursor-sync--show-conflict-diff conflict))
    ('ask
     (cursor-sync--prompt-conflict-resolution conflict))))

(defun cursor-sync--show-conflict-diff (conflict)
  "Show diff for CONFLICT."
  (let* ((file (alist-get 'file conflict))
         (emacs-content (alist-get 'emacsContent conflict))
         (agent-content (alist-get 'agentContent conflict))
         (diff-buffer (get-buffer-create "*Cursor Sync Conflict*")))
    (with-current-buffer diff-buffer
      (erase-buffer)
      (insert "=== EMACS VERSION ===\n")
      (insert emacs-content)
      (insert "\n\n=== AGENT VERSION ===\n")
      (insert agent-content)
      (diff-mode)
      (goto-char (point-min)))
    (display-buffer diff-buffer)
    (cursor-sync--prompt-conflict-resolution conflict)))

(defun cursor-sync--prompt-conflict-resolution (conflict)
  "Prompt user to resolve CONFLICT."
  (let ((choice (read-char-choice
                "Sync conflict: Keep [e]macs, [a]gent, or [m]erge? "
                '(?e ?a ?m))))
    (pcase choice
      (?e (cursor-sync-resolve-keep-emacs))
      (?a (cursor-sync-resolve-keep-agent))
      (?m (cursor-sync-resolve-merge conflict)))))

;;;###autoload
(defun cursor-sync-push (&optional buffer)
  "Manually push BUFFER (or current buffer) to agent."
  (interactive)
  (with-current-buffer (or buffer (current-buffer))
    (when (buffer-file-name)
      (when cursor-sync--debounce-timer
        (cancel-timer cursor-sync--debounce-timer))
      (cursor-sync--send-changes (current-buffer))
      (message "Pushed %s to agent" (buffer-name)))))

;;;###autoload
(defun cursor-sync-pull (&optional buffer)
  "Manually pull changes from agent to BUFFER (or current buffer)."
  (interactive)
  (with-current-buffer (or buffer (current-buffer))
    (when (buffer-file-name)
      (cursor-sync--pull-changes (buffer-file-name)))))

;;;###autoload
(defun cursor-sync-status ()
  "Display sync status for current buffer."
  (interactive)
  (if cursor-sync-mode
      (message "Sync enabled: version %d, %d pending changes"
              cursor-sync--version
              (length cursor-sync--pending-changes))
    (message "Sync disabled for this buffer")))

(defun cursor-sync-resolve-keep-emacs ()
  "Resolve conflict by keeping Emacs version."
  (interactive)
  (cursor-sync-push)
  (message "Kept Emacs version"))

(defun cursor-sync-resolve-keep-agent ()
  "Resolve conflict by keeping agent version."
  (interactive)
  (cursor-sync-pull)
  (message "Kept agent version"))

(defun cursor-sync-resolve-merge (conflict)
  "Resolve CONFLICT by manual merge using ediff."
  (interactive)
  (let* ((file (alist-get 'file conflict))
         (agent-content (alist-get 'agentContent conflict))
         (temp-file (make-temp-file "cursor-agent-")))
    (with-temp-file temp-file
      (insert agent-content))
    (ediff-files file temp-file)
    (add-hook 'ediff-quit-hook
             (lambda ()
               (delete-file temp-file))
             nil t)))

(provide 'cursor-sync)

;;; cursor-sync.el ends here

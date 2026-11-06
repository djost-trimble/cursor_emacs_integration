;;; cursor-chat.el --- Chat interface for Cursor Agent -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Cursor Integration
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (markdown-mode "2.5"))
;; Keywords: tools, ai, cursor
;; URL: https://github.com/cursor/doom-emacs-integration

;;; Commentary:

;; This module provides a dedicated chat interface for conversations with
;; Cursor agents, featuring markdown rendering and code block highlighting.

;;; Code:

(require 'markdown-mode)
(require 'cursor-bridge)

(defgroup cursor-chat nil
  "Settings for Cursor chat interface."
  :group 'cursor
  :prefix "cursor-chat-")

(defcustom cursor-chat-window-side 'right
  "Side of the frame to display the chat window."
  :type '(choice (const :tag "Right" right)
                (const :tag "Left" left)
                (const :tag "Bottom" bottom))
  :group 'cursor-chat)

(defcustom cursor-chat-window-width 80
  "Width of the chat window in columns."
  :type 'integer
  :group 'cursor-chat)

(defcustom cursor-chat-save-history t
  "Whether to save chat history to disk."
  :type 'boolean
  :group 'cursor-chat)

(defcustom cursor-chat-history-file
  (expand-file-name "cursor-chat-history.el" user-emacs-directory)
  "File to save chat history."
  :type 'file
  :group 'cursor-chat)

(defface cursor-chat-header-face
  '((t :inherit header-line :weight bold))
  "Face for chat header."
  :group 'cursor-chat)

(defface cursor-chat-user-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for user messages."
  :group 'cursor-chat)

(defface cursor-chat-agent-face
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for agent messages."
  :group 'cursor-chat)

(defface cursor-chat-prompt-face
  '((t :inherit minibuffer-prompt))
  "Face for input prompt."
  :group 'cursor-chat)

(defface cursor-chat-timestamp-face
  '((t :inherit font-lock-comment-face))
  "Face for timestamps."
  :group 'cursor-chat)

(defface cursor-chat-code-face
  '((t :inherit font-lock-string-face :background "#f5f5f5"))
  "Face for code blocks."
  :group 'cursor-chat)

(defvar-local cursor-chat--session-id nil
  "Session ID for this chat buffer.")

(defvar-local cursor-chat--message-history nil
  "Message history for this chat session.")

(defvar-local cursor-chat--input-marker nil
  "Marker for the input area.")

(defvar cursor-chat--buffers (make-hash-table :test 'equal)
  "Hash table of session ID to chat buffer.")

(defvar cursor-chat-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'cursor-chat-send-message)
    (define-key map (kbd "C-c C-c") 'cursor-chat-send-message)
    (define-key map (kbd "C-c C-k") 'cursor-chat-clear)
    (define-key map (kbd "C-c C-x") 'cursor-chat-export)
    (define-key map (kbd "C-c C-n") 'cursor-chat-new-session)
    (define-key map (kbd "q") 'quit-window)
    map)
  "Keymap for `cursor-chat-mode'.")

(define-derived-mode cursor-chat-mode special-mode "Cursor-Chat"
  "Major mode for Cursor agent chat interface.

\\{cursor-chat-mode-map}"
  (setq-local cursor-chat--message-history nil)
  (setq-local cursor-chat--input-marker (point-max-marker))
  (setq buffer-read-only nil)
  (cursor-chat--setup-websocket))

(defun cursor-chat--setup-websocket ()
  "Setup WebSocket handlers for this chat session."
  (cursor-bridge-ws-on "agent-message"
                      (lambda (msg)
                        (cursor-chat--handle-agent-message msg)))
  (cursor-bridge-ws-on "agent-edit"
                      (lambda (msg)
                        (cursor-chat--handle-agent-edit msg))))

(defun cursor-chat-open (session-id)
  "Open or focus chat buffer for SESSION-ID."
  (let ((buffer (gethash session-id cursor-chat--buffers)))
    (unless buffer
      (setq buffer (get-buffer-create (format "*cursor-chat: %s*" session-id)))
      (with-current-buffer buffer
        (cursor-chat-mode)
        (setq cursor-chat--session-id session-id)
        (cursor-chat--render-buffer))
      (puthash session-id buffer cursor-chat--buffers))
    
    (display-buffer buffer
                   `((display-buffer-in-side-window)
                     (side . ,cursor-chat-window-side)
                     (window-width . ,cursor-chat-window-width)))
    (select-window (get-buffer-window buffer))
    buffer))

(defun cursor-chat--render-buffer ()
  "Render the chat buffer with current history."
  (let ((inhibit-read-only t)
        (old-point (point)))
    (erase-buffer)
    
    (insert (propertize
             (format "Cursor Chat - Session: %s\n"
                    (or cursor-chat--session-id "unknown"))
             'face 'cursor-chat-header-face))
    (insert (propertize (make-string (window-width) ?─)
                       'face 'cursor-chat-header-face)
            "\n\n")
    
    (dolist (msg (reverse cursor-chat--message-history))
      (cursor-chat--render-message msg))
    
    (insert "\n" (propertize "▼ " 'face 'cursor-chat-prompt-face))
    (setq cursor-chat--input-marker (point-marker))
    (set-marker-insertion-type cursor-chat--input-marker nil)
    
    (goto-char (max old-point cursor-chat--input-marker))))

(defun cursor-chat--render-message (msg)
  "Render a single message MSG in the chat buffer."
  (let* ((role (plist-get msg :role))
         (content (plist-get msg :content))
         (timestamp (plist-get msg :timestamp))
         (face (if (eq role 'user)
                  'cursor-chat-user-face
                'cursor-chat-agent-face)))
    
    (insert (propertize
             (format "%s"
                    (capitalize (symbol-name role)))
             'face face))
    (insert " ")
    (insert (propertize
             (format "(%s)"
                    (format-time-string "%H:%M:%S" timestamp))
             'face 'cursor-chat-timestamp-face))
    (insert ":\n")
    
    (cursor-chat--render-content content)
    (insert "\n\n")))

(defun cursor-chat--render-content (content)
  "Render message CONTENT with markdown formatting."
  (let ((start (point)))
    (insert content)
    
    (save-excursion
      (goto-char start)
      (while (re-search-forward "```\\([a-z]*\\)\n\\(\\(?:.\\|\n\\)*?\\)```" nil t)
        (let ((language (match-string 1))
              (code (match-string 2))
              (code-start (match-beginning 0))
              (code-end (match-end 0)))
          (cursor-chat--render-code-block code language code-start code-end))))))

(defun cursor-chat--render-code-block (code language code-start code-end)
  "Render CODE block in LANGUAGE between CODE-START and CODE-END."
  (let ((ov (make-overlay code-start code-end)))
    (overlay-put ov 'cursor-chat-code t)
    (overlay-put ov 'face 'cursor-chat-code-face)
    
    (goto-char code-end)
    (insert "\n")
    (let ((button-start (point)))
      (insert-button "Apply to buffer"
                    'action #'cursor-chat--apply-code
                    'code code
                    'follow-link t)
      (insert " ")
      (insert-button "Copy"
                    'action #'cursor-chat--copy-code
                    'code code
                    'follow-link t)
      (insert "\n"))))

(defun cursor-chat--apply-code (button)
  "Apply code from BUTTON to target buffer."
  (let ((code (button-get button 'code)))
    (with-current-buffer (other-buffer)
      (insert code)
      (message "Code applied to %s" (buffer-name)))))

(defun cursor-chat--copy-code (button)
  "Copy code from BUTTON to kill ring."
  (let ((code (button-get button 'code)))
    (kill-new code)
    (message "Code copied to kill ring")))

(defun cursor-chat-send-message ()
  "Send message in input area to agent."
  (interactive)
  (when (< (point) cursor-chat--input-marker)
    (goto-char (point-max)))
  
  (let* ((input-start cursor-chat--input-marker)
         (message (string-trim
                  (buffer-substring-no-properties input-start (point-max)))))
    (when (> (length message) 0)
      (push (list :role 'user
                 :content message
                 :timestamp (current-time))
           cursor-chat--message-history)
      
      (cursor-bridge--http-post "/api/agent/ask"
                               `((sessionId . ,cursor-chat--session-id)
                                 (message . ,message))
                               #'cursor-chat--handle-response)
      
      (let ((inhibit-read-only t))
        (delete-region input-start (point-max)))
      
      (cursor-chat--render-buffer))))

(defun cursor-chat--handle-response (response)
  "Handle agent RESPONSE from HTTP request."
  (when response
    (let ((content (alist-get 'content response))
          (message-id (alist-get 'messageId response)))
      (push (list :role 'assistant
                 :content content
                 :timestamp (current-time)
                 :message-id message-id)
           cursor-chat--message-history)
      
      (with-current-buffer (gethash cursor-chat--session-id cursor-chat--buffers)
        (cursor-chat--render-buffer)
        (goto-char (point-max))))))

(defun cursor-chat--handle-agent-message (msg)
  "Handle agent message MSG from WebSocket."
  (let ((session-id (alist-get 'sessionId msg))
        (content (alist-get 'content msg))
        (message-id (alist-get 'messageId msg)))
    (when (equal session-id cursor-chat--session-id)
      (push (list :role 'assistant
                 :content content
                 :timestamp (current-time)
                 :message-id message-id)
           cursor-chat--message-history)
      (cursor-chat--render-buffer)
      (goto-char (point-max)))))

(defun cursor-chat--handle-agent-edit (msg)
  "Handle agent edit MSG from WebSocket."
  (let ((session-id (alist-get 'sessionId msg))
        (file (alist-get 'file msg))
        (changes (alist-get 'changes msg)))
    (when (equal session-id cursor-chat--session-id)
      (message "Agent edited: %s (%d changes)"
              (file-name-nondirectory file)
              (length changes)))))

(defun cursor-chat--display-response (response)
  "Display agent RESPONSE in chat buffer."
  (let ((session-id cursor-chat--session-id))
    (unless session-id
      (error "No active chat session"))
    (cursor-chat--handle-response response)))

(defun cursor-chat-clear ()
  "Clear the chat history."
  (interactive)
  (when (yes-or-no-p "Clear chat history? ")
    (setq cursor-chat--message-history nil)
    (cursor-chat--render-buffer)
    (message "Chat history cleared")))

(defun cursor-chat-export ()
  "Export chat history to a file."
  (interactive)
  (let* ((default-file (format "cursor-chat-%s.md"
                              (format-time-string "%Y%m%d-%H%M%S")))
         (file (read-file-name "Export to: " nil default-file)))
    (with-temp-buffer
      (insert (format "# Cursor Chat Export\n\n"))
      (insert (format "Session: %s\n" cursor-chat--session-id))
      (insert (format "Exported: %s\n\n"
                     (format-time-string "%Y-%m-%d %H:%M:%S")))
      (insert "---\n\n")
      
      (dolist (msg (reverse cursor-chat--message-history))
        (insert (format "## %s (%s)\n\n"
                       (capitalize (symbol-name (plist-get msg :role)))
                       (format-time-string "%H:%M:%S"
                                         (plist-get msg :timestamp))))
        (insert (plist-get msg :content))
        (insert "\n\n"))
      
      (write-region (point-min) (point-max) file))
    (message "Chat exported to %s" file)))

(defun cursor-chat-new-session ()
  "Create a new chat session."
  (interactive)
  (call-interactively #'cursor-start-session)
  (when cursor--current-session-id
    (cursor-chat-open cursor--current-session-id)))

(provide 'cursor-chat)

;;; cursor-chat.el ends here

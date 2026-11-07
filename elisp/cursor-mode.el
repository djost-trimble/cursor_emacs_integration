;;; cursor-mode.el --- Cursor Agent integration for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Cursor Integration
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (websocket "1.13") (request "0.3.2"))
;; Keywords: tools, ai, cursor
;; URL: https://github.com/cursor/doom-emacs-integration

;;; Commentary:

;; This package integrates Cursor's AI agent system with Emacs, providing
;; commands for AI-assisted development, code analysis, and refactoring.

;;; Code:

(require 'cursor-bridge)
(require 'cursor-chat)
(require 'cursor-sync)

(defgroup cursor nil
  "Cursor Agent integration for Emacs."
  :group 'tools
  :prefix "cursor-")

(defcustom cursor-default-model "claude-4-sonnet"
  "Default AI model for new sessions."
  :type 'string
  :group 'cursor)

(defcustom cursor-auto-start-session t
  "Automatically start a session when first needed."
  :type 'boolean
  :group 'cursor)

(defcustom cursor-api-key nil
  "Cursor API key. If nil, will use auth-source."
  :type '(choice (const :tag "Use auth-source" nil)
                (string :tag "API Key"))
  :group 'cursor)

(defvar cursor--current-session-id nil
  "ID of the current active session.")

(defvar cursor--sessions (make-hash-table :test 'equal)
  "Hash table of session ID to session data.")

(defvar cursor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c a a") 'cursor-ask-agent)
    (define-key map (kbd "C-c a c") 'cursor-open-chat)
    (define-key map (kbd "C-c a f") 'cursor-fix-at-point)
    (define-key map (kbd "C-c a e") 'cursor-explain-region)
    (define-key map (kbd "C-c a R") 'cursor-refactor-region)
    (define-key map (kbd "C-c a s") 'cursor-start-session)
    (define-key map (kbd "C-c a r") 'cursor-resume-session)
    (define-key map (kbd "C-c a l") 'cursor-list-sessions)
    (define-key map (kbd "C-c a q") 'cursor-end-session)
    map)
  "Keymap for `cursor-mode'.")

;;;###autoload
(define-minor-mode cursor-mode
  "Minor mode for Cursor Agent integration."
  :lighter " Cursor"
  :keymap cursor-mode-map
  :group 'cursor
  (if cursor-mode
      (cursor--enable)
    (cursor--disable)))

;;;###autoload
(define-globalized-minor-mode global-cursor-mode cursor-mode
  (lambda () (cursor-mode 1))
  :group 'cursor)

(defun cursor--enable ()
  "Enable Cursor mode."
  (unless (cursor-bridge-ws-connected-p)
    (cursor-bridge-ws-connect))
  
  (when (and cursor-auto-start-session
             (not cursor--current-session-id))
    (cursor-start-session))
  
  (cursor-sync-mode 1)
  (message "Cursor mode enabled"))

(defun cursor--disable ()
  "Disable Cursor mode."
  (cursor-sync-mode -1)
  (message "Cursor mode disabled"))

(defun cursor--get-api-key ()
  "Retrieve Cursor API key from configuration or auth-source."
  (or cursor-api-key
      (let ((auth-info (auth-source-search
                       :host "cursor-api"
                       :max 1
                       :require '(:secret))))
        (when auth-info
          (let ((secret (plist-get (car auth-info) :secret)))
            (if (functionp secret)
                (funcall secret)
              secret))))
      (read-passwd "Cursor API key: ")))

(defun cursor--ensure-session ()
  "Ensure there is an active session, creating one if needed."
  (unless cursor--current-session-id
    (if cursor-auto-start-session
        (cursor-start-session)
      (error "No active Cursor session. Use `cursor-start-session' to create one"))))

(defun cursor--gather-context ()
  "Gather context information from current buffer and position."
  (let ((context (make-hash-table :test 'equal)))
    (when (buffer-file-name)
      (puthash 'file (buffer-file-name) context)
      (puthash 'language (symbol-name major-mode) context))
    (puthash 'line (line-number-at-pos) context)
    (puthash 'column (current-column) context)
    (when (region-active-p)
      (puthash 'region (list (region-beginning) (region-end)) context)
      (puthash 'region-text (buffer-substring-no-properties
                            (region-beginning) (region-end)) context))
    context))

;;;###autoload
(defun cursor-start-session (&optional model workspace)
  "Start a new Cursor agent session with MODEL in WORKSPACE."
  (interactive)
  (let* ((model (or model cursor-default-model))
         (workspace (or workspace
                       (when (project-current)
                         (project-root (project-current)))
                       default-directory))
         (data `((model . ,model)
                (workspace . ,workspace)))
         (response (cursor-bridge--http-post "/api/sessions/create" data)))
    (when response
      (let ((session-id (alist-get 'sessionId response)))
        (setq cursor--current-session-id session-id)
        (puthash session-id response cursor--sessions)
        (message "Started Cursor session: %s (model: %s)"
                session-id model)
        session-id))))

;;;###autoload
(defun cursor-resume-session (session-id)
  "Resume existing Cursor session SESSION-ID."
  (interactive
   (list (completing-read "Session ID: "
                         (cursor--list-session-ids)
                         nil t)))
  (let ((response (cursor-bridge--http-post
                  (format "/api/sessions/%s/resume" session-id)
                  nil)))
    (when response
      (setq cursor--current-session-id session-id)
      (puthash session-id response cursor--sessions)
      (message "Resumed session: %s" session-id)
      session-id)))

;;;###autoload
(defun cursor-end-session (&optional session-id)
  "End Cursor session SESSION-ID or current session."
  (interactive)
  (let ((session-id (or session-id cursor--current-session-id)))
    (unless session-id
      (error "No active session"))
    (cursor-bridge--http-delete (format "/api/sessions/%s" session-id))
    (remhash session-id cursor--sessions)
    (when (equal session-id cursor--current-session-id)
      (setq cursor--current-session-id nil))
    (message "Ended session: %s" session-id)))

(defun cursor--list-session-ids ()
  "Return list of session IDs."
  (let ((response (cursor-bridge--http-get "/api/sessions")))
    (when response
      (mapcar (lambda (s) (alist-get 'sessionId s))
             (alist-get 'sessions response)))))

;;;###autoload
(defun cursor-list-sessions ()
  "List all Cursor sessions."
  (interactive)
  (let ((response (cursor-bridge--http-get "/api/sessions")))
    (if response
        (let ((sessions (alist-get 'sessions response)))
          (with-current-buffer (get-buffer-create "*Cursor Sessions*")
            (cursor-sessions-mode)
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert (propertize "Cursor Agent Sessions\n\n" 'face 'bold))
              (insert (format "%-20s %-20s %-30s %s\n"
                            "Session ID" "Model" "Created" "Last Active"))
              (insert (make-string 90 ?─) "\n")
              (dolist (session sessions)
                (insert (format "%-20s %-20s %-30s %s\n"
                              (alist-get 'sessionId session)
                              (alist-get 'model session)
                              (alist-get 'created session)
                              (alist-get 'lastActive session))))
              (goto-char (point-min)))
            (display-buffer (current-buffer))))
      (message "Failed to retrieve sessions"))))

(define-derived-mode cursor-sessions-mode special-mode "Cursor-Sessions"
  "Major mode for listing Cursor sessions."
  (setq truncate-lines t))

;;;###autoload
(defun cursor-ask-agent (prompt)
  "Ask Cursor agent with PROMPT in current context."
  (interactive "sCursor agent: ")
  (cursor--ensure-session)
  (let* ((context (cursor--gather-context))
         (data `((sessionId . ,cursor--current-session-id)
                (message . ,prompt)
                (context . ,context))))
    (cursor-bridge--http-post "/api/agent/ask" data
      (lambda (response)
        (if response
            (progn
              (cursor-chat--display-response response)
              (message "Agent responded"))
          (message "Failed to get response from agent"))))))

;;;###autoload
(defun cursor-fix-at-point ()
  "Ask agent to fix issue at point."
  (interactive)
  (cursor--ensure-session)
  (let* ((line (line-number-at-pos))
         (line-text (thing-at-point 'line t))
         (prompt (format "Fix the issue at line %d: %s" line line-text)))
    (cursor-ask-agent prompt)))

;;;###autoload
(defun cursor-explain-region (start end)
  "Explain code in region from START to END."
  (interactive "r")
  (cursor--ensure-session)
  (let* ((code (buffer-substring-no-properties start end))
         (prompt (format "Explain this code:\n\n%s" code)))
    (cursor-ask-agent prompt)))

;;;###autoload
(defun cursor-refactor-region (start end)
  "Refactor code in region from START to END."
  (interactive "r")
  (cursor--ensure-session)
  (let* ((code (buffer-substring-no-properties start end))
         (prompt (format "Refactor this code to improve quality:\n\n%s" code)))
    (cursor-ask-agent prompt)))

;;;###autoload
(defun cursor-optimize-function ()
  "Optimize the function at point."
  (interactive)
  (cursor--ensure-session)
  (save-excursion
    (beginning-of-defun)
    (let* ((start (point))
           (end (progn (end-of-defun) (point)))
           (code (buffer-substring-no-properties start end))
           (prompt (format "Optimize this function for performance:\n\n%s" code)))
      (cursor-ask-agent prompt))))

;;;###autoload
(defun cursor-generate-tests ()
  "Generate tests for the current function or region."
  (interactive)
  (cursor--ensure-session)
  (if (region-active-p)
      (let* ((code (buffer-substring-no-properties (region-beginning) (region-end)))
             (prompt (format "Generate comprehensive tests for this code:\n\n%s" code)))
        (cursor-ask-agent prompt))
    (save-excursion
      (beginning-of-defun)
      (let* ((start (point))
             (end (progn (end-of-defun) (point)))
             (code (buffer-substring-no-properties start end))
             (prompt (format "Generate comprehensive tests for this function:\n\n%s" code)))
        (cursor-ask-agent prompt)))))

;;;###autoload
(defun cursor-generate-docstring ()
  "Generate docstring for the function at point."
  (interactive)
  (cursor--ensure-session)
  (save-excursion
    (beginning-of-defun)
    (let* ((start (point))
           (end (progn (end-of-defun) (point)))
           (code (buffer-substring-no-properties start end))
           (prompt (format "Generate a comprehensive docstring for this function:\n\n%s" code)))
      (cursor-ask-agent prompt))))

;;;###autoload
(defun cursor-open-chat (&optional session-id)
  "Open Cursor chat interface for SESSION-ID or current session."
  (interactive)
  (cursor--ensure-session)
  (cursor-chat-open (or session-id cursor--current-session-id)))

(defun cursor--format-time (time-string)
  "Format TIME-STRING for display."
  (if time-string
      (format-time-string "%Y-%m-%d %H:%M:%S"
                         (date-to-time time-string))
    "Unknown"))

;;; Cloud Session Management

;;;###autoload
(defun cursor-list-cloud-sessions ()
  "List cloud sessions from Cursor web UI."
  (interactive)
  (let ((response (cursor-bridge--http-get "/api/cloud/sessions")))
    (if (and response (not (alist-get 'error response)))
        (let ((sessions (alist-get 'sessions response))
              (total (alist-get 'total response)))
          (with-current-buffer (get-buffer-create "*Cursor Cloud Sessions*")
            (cursor-cloud-sessions-mode)
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert (propertize "Cursor Cloud Sessions\n\n" 'face 'bold))
              (insert (format "Total: %d sessions\n\n" total))
              (insert (format "%-30s %-20s %-20s %s\n"
                            "Cloud Session ID" "Model" "Workspace" "Created"))
              (insert (make-string 100 ?─) "\n")
              (dolist (session sessions)
                (let ((cloud-id (alist-get 'cloudSessionId session))
                      (model (alist-get 'model session))
                      (workspace (or (alist-get 'workspace session) "N/A"))
                      (created (alist-get 'created session)))
                  (insert (propertize (format "%-30s" cloud-id)
                                    'cloud-session-id cloud-id)
                          (format " %-20s %-20s %s\n"
                                model
                                (file-name-nondirectory
                                 (directory-file-name workspace))
                                created))))
              (goto-char (point-min)))
            (display-buffer (current-buffer))))
      (message "Failed to retrieve cloud sessions: %s"
              (or (alist-get 'error response) "Unknown error")))))

(define-derived-mode cursor-cloud-sessions-mode special-mode "Cursor-Cloud-Sessions"
  "Major mode for listing Cursor cloud sessions."
  (setq truncate-lines t)
  (define-key cursor-cloud-sessions-mode-map (kbd "RET") 'cursor-cloud-session-import-at-point)
  (define-key cursor-cloud-sessions-mode-map (kbd "i") 'cursor-cloud-session-import-at-point)
  (define-key cursor-cloud-sessions-mode-map (kbd "c") 'cursor-cloud-session-show-context)
  (define-key cursor-cloud-sessions-mode-map (kbd "h") 'cursor-cloud-session-show-history)
  (define-key cursor-cloud-sessions-mode-map (kbd "r") 'cursor-list-cloud-sessions))

(defun cursor-cloud-session-import-at-point ()
  "Import cloud session at point."
  (interactive)
  (let ((cloud-id (get-text-property (point) 'cloud-session-id)))
    (if cloud-id
        (cursor-import-cloud-session cloud-id)
      (message "No cloud session at point"))))

(defun cursor-cloud-session-show-context ()
  "Show context for cloud session at point."
  (interactive)
  (let ((cloud-id (get-text-property (point) 'cloud-session-id)))
    (if cloud-id
        (let ((response (cursor-bridge--http-get
                        (format "/api/cloud/sessions/%s/context" cloud-id))))
          (if (and response (not (alist-get 'error response)))
              (with-current-buffer (get-buffer-create "*Cursor Cloud Context*")
                (erase-buffer)
                (insert (format "Cloud Session: %s\n\n" cloud-id))
                (insert (pp-to-string response))
                (goto-char (point-min))
                (display-buffer (current-buffer)))
            (message "Failed to fetch context: %s"
                    (or (alist-get 'error response) "Unknown error"))))
      (message "No cloud session at point"))))

(defun cursor-cloud-session-show-history ()
  "Show history for cloud session at point."
  (interactive)
  (let ((cloud-id (get-text-property (point) 'cloud-session-id)))
    (if cloud-id
        (let ((response (cursor-bridge--http-get
                        (format "/api/cloud/sessions/%s/history" cloud-id))))
          (if (and response (not (alist-get 'error response)))
              (with-current-buffer (get-buffer-create "*Cursor Cloud History*")
                (erase-buffer)
                (insert (format "Cloud Session History: %s\n\n" cloud-id))
                (let ((messages (alist-get 'messages response))
                      (files (alist-get 'files response)))
                  (insert (format "Messages: %d\n" (length messages)))
                  (insert (format "Files: %d\n\n" (length files)))
                  (when files
                    (insert "Files:\n")
                    (dolist (file files)
                      (insert (format "  - %s\n" file)))
                    (insert "\n"))
                  (when messages
                    (insert "Recent Messages:\n")
                    (dolist (msg (seq-take messages 10))
                      (insert (format "\n[%s] %s:\n%s\n"
                                    (alist-get 'timestamp msg)
                                    (alist-get 'role msg)
                                    (truncate-string-to-width
                                     (alist-get 'content msg) 200 nil nil "..."))))))
                (goto-char (point-min))
                (display-buffer (current-buffer)))
            (message "Failed to fetch history: %s"
                    (or (alist-get 'error response) "Unknown error"))))
      (message "No cloud session at point"))))

;;;###autoload
(defun cursor-import-cloud-session (cloud-session-id)
  "Import a cloud session CLOUD-SESSION-ID as a local session."
  (interactive "sCloud Session ID: ")
  (let ((response (cursor-bridge--http-post
                  (format "/api/sessions/import/%s" cloud-session-id)
                  nil)))
    (if (and response (not (alist-get 'error response)))
        (let ((session-id (alist-get 'sessionId response))
              (model (alist-get 'model response))
              (workspace (alist-get 'workspace response)))
          (setq cursor--current-session-id session-id)
          (puthash session-id response cursor--sessions)
          (message "Imported cloud session as local session: %s (model: %s)"
                  session-id model)
          (when workspace
            (message "Workspace: %s" workspace))
          session-id)
      (message "Failed to import cloud session: %s"
              (or (alist-get 'error response) "Unknown error"))
      nil)))

;;;###autoload
(defun cursor-sync-to-cloud (&optional session-id)
  "Upload local session SESSION-ID to cloud (if API supports).
If SESSION-ID is nil, uses the current session."
  (interactive)
  (cursor--ensure-session)
  (let* ((session-id (or session-id cursor--current-session-id))
         (response (cursor-bridge--http-post
                   (format "/api/sessions/%s/sync-to-cloud" session-id)
                   nil)))
    (if (and response (not (alist-get 'error response)))
        (let ((cloud-session-id (alist-get 'cloudSessionId response)))
          (message "Synced session to cloud: %s" cloud-session-id)
          cloud-session-id)
      (message "Failed to sync to cloud: %s"
              (or (alist-get 'error response) "Unknown error"))
      nil)))

(provide 'cursor-mode)

;;; cursor-mode.el ends here

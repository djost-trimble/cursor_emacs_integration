;;; cursor-bridge.el --- Communication bridge for Cursor Agent SDK -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Cursor Integration
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (websocket "1.13") (request "0.3.2"))
;; Keywords: tools, ai, cursor
;; URL: https://github.com/cursor/doom-emacs-integration

;;; Commentary:

;; This module provides low-level communication with the Cursor Bridge service,
;; handling HTTP requests and WebSocket connections for real-time updates.

;;; Code:

(require 'json)
(require 'url)
(require 'websocket)

(defgroup cursor-bridge nil
  "Settings for Cursor bridge communication."
  :group 'cursor
  :prefix "cursor-bridge-")

(defcustom cursor-bridge-http-endpoint "http://localhost:8765"
  "HTTP endpoint for Cursor bridge service."
  :type 'string
  :group 'cursor-bridge)

(defcustom cursor-bridge-ws-endpoint "ws://localhost:8765"
  "WebSocket endpoint for Cursor bridge service."
  :type 'string
  :group 'cursor-bridge)

(defcustom cursor-bridge-timeout 30
  "Timeout in seconds for HTTP requests."
  :type 'integer
  :group 'cursor-bridge)

(defcustom cursor-bridge-max-retries 3
  "Maximum number of retry attempts for failed requests."
  :type 'integer
  :group 'cursor-bridge)

(defvar cursor-bridge--ws-connection nil
  "Active WebSocket connection to bridge service.")

(defvar cursor-bridge--ws-callbacks (make-hash-table :test 'equal)
  "Hash table of message type to callback functions.")

(defvar cursor-bridge--request-id 0
  "Counter for generating unique request IDs.")

(defun cursor-bridge--generate-request-id ()
  "Generate a unique request ID."
  (format "req_%d_%d" (float-time) (cl-incf cursor-bridge--request-id)))

(defun cursor-bridge--make-url (path)
  "Construct full URL from PATH."
  (concat cursor-bridge-http-endpoint path))

(defun cursor-bridge--http-request (method path &optional data callback)
  "Make HTTP request with METHOD to PATH with optional DATA.
If CALLBACK is provided, make async request, otherwise block."
  (let* ((url (cursor-bridge--make-url path))
         (url-request-method method)
         (url-request-extra-headers
          '(("Content-Type" . "application/json")))
         (url-request-data
          (when data (encode-coding-string (json-encode data) 'utf-8)))
         (buffer nil))
    (if callback
        (url-retrieve url
                      (lambda (status)
                        (cursor-bridge--handle-response status callback))
                      nil t)
      (setq buffer (url-retrieve-synchronously url t nil cursor-bridge-timeout))
      (when buffer
        (with-current-buffer buffer
          (goto-char (point-min))
          (re-search-forward "^$" nil t)
          (let* ((json-object-type 'alist)
                 (json-array-type 'list)
                 (json-key-type 'symbol)
                 (response (condition-case err
                              (json-read)
                            (error
                             (message "Failed to parse JSON: %s" err)
                             nil))))
            (kill-buffer buffer)
            response))))))

(defun cursor-bridge--handle-response (status callback)
  "Handle HTTP response with STATUS and call CALLBACK."
  (if (plist-get status :error)
      (progn
        (message "HTTP request failed: %s" (plist-get status :error))
        (when callback (funcall callback nil)))
    (goto-char (point-min))
    (re-search-forward "^$" nil t)
    (let* ((json-object-type 'alist)
           (json-array-type 'list)
           (json-key-type 'symbol)
           (response (condition-case err
                        (json-read)
                      (error
                       (message "Failed to parse JSON: %s" err)
                       nil))))
      (when callback (funcall callback response))))
  (kill-buffer (current-buffer)))

(defun cursor-bridge--http-get (path &optional callback)
  "HTTP GET request to PATH with optional CALLBACK."
  (cursor-bridge--http-request "GET" path nil callback))

(defun cursor-bridge--http-post (path data &optional callback)
  "HTTP POST request to PATH with DATA and optional CALLBACK."
  (cursor-bridge--http-request "POST" path data callback))

(defun cursor-bridge--http-delete (path &optional callback)
  "HTTP DELETE request to PATH with optional CALLBACK."
  (cursor-bridge--http-request "DELETE" path nil callback))

(defun cursor-bridge--http-put (path data &optional callback)
  "HTTP PUT request to PATH with DATA and optional CALLBACK."
  (cursor-bridge--http-request "PUT" path data callback))

(defun cursor-bridge-check-health ()
  "Check if bridge service is running."
  (interactive)
  (let ((response (cursor-bridge--http-get "/health")))
    (if response
        (progn
          (message "Bridge service is healthy: %s" (alist-get 'status response))
          t)
      (message "Bridge service is not responding")
      nil)))

(defun cursor-bridge-ws-connect ()
  "Establish WebSocket connection to bridge service."
  (interactive)
  (when cursor-bridge--ws-connection
    (cursor-bridge-ws-disconnect))
  
  (setq cursor-bridge--ws-connection
        (websocket-open
         cursor-bridge-ws-endpoint
         :on-open (lambda (_ws)
                   (message "WebSocket connected to Cursor bridge")
                   (cursor-bridge--on-ws-open))
         :on-message #'cursor-bridge--on-ws-message
         :on-close (lambda (_ws)
                    (message "WebSocket disconnected")
                    (setq cursor-bridge--ws-connection nil))
         :on-error (lambda (_ws type err)
                    (message "WebSocket error (%s): %s" type err)))))

(defun cursor-bridge-ws-disconnect ()
  "Close WebSocket connection."
  (interactive)
  (when cursor-bridge--ws-connection
    (websocket-close cursor-bridge--ws-connection)
    (setq cursor-bridge--ws-connection nil)))

(defun cursor-bridge-ws-connected-p ()
  "Check if WebSocket is connected."
  (and cursor-bridge--ws-connection
       (websocket-openp cursor-bridge--ws-connection)))

(defun cursor-bridge--on-ws-open ()
  "Handle WebSocket connection opened."
  (cursor-bridge-ws-send '((type . "ping"))))

(defun cursor-bridge--on-ws-message (_ws frame)
  "Handle incoming WebSocket message FRAME."
  (let* ((payload (websocket-frame-payload frame))
         (json-object-type 'alist)
         (json-array-type 'list)
         (json-key-type 'symbol)
         (message (condition-case err
                     (json-read-from-string payload)
                   (error
                    (message "Failed to parse WebSocket message: %s" err)
                    nil))))
    (when message
      (let* ((msg-type (alist-get 'type message))
             (callback (gethash msg-type cursor-bridge--ws-callbacks)))
        (if callback
            (funcall callback message)
          (message "Unhandled message type: %s" msg-type))))))

(defun cursor-bridge-ws-send (message)
  "Send MESSAGE through WebSocket."
  (if (cursor-bridge-ws-connected-p)
      (websocket-send-text cursor-bridge--ws-connection
                          (json-encode message))
    (message "WebSocket not connected")))

(defun cursor-bridge-ws-on (msg-type callback)
  "Register CALLBACK for WebSocket messages of MSG-TYPE."
  (puthash msg-type callback cursor-bridge--ws-callbacks))

(defun cursor-bridge--with-retry (func &optional max-attempts)
  "Execute FUNC with retry logic up to MAX-ATTEMPTS."
  (let ((attempts 0)
        (max-attempts (or max-attempts cursor-bridge-max-retries))
        (delay 1)
        (result nil)
        (success nil))
    (while (and (not success) (< attempts max-attempts))
      (condition-case err
          (progn
            (setq result (funcall func))
            (setq success t))
        (error
         (cl-incf attempts)
         (message "Request failed (attempt %d/%d): %s"
                 attempts max-attempts (error-message-string err))
         (when (< attempts max-attempts)
           (sleep-for delay)
           (setq delay (* delay 2))))))
    (if success
        result
      (error "Request failed after %d attempts" max-attempts))))

(provide 'cursor-bridge)

;;; cursor-bridge.el ends here

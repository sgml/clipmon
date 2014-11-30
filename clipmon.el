;;; clipmon.el --- Clipboard monitor - paste contents of clipboard on change.
;;; About:

;; Copyright (C) 2014 Brian Burns
;; 
;; Author: Brian Burns <bburns.km@gmail.com>
;; URL: https://github.com/bburns/clipmon
;; Version: 0.1.20141130
;; 
;; Keywords: clipboard, paste, autopaste
;; Package-Requires: ((s "0.0.1"))
;; License: MIT. NO WARRANTY.
;; Created: 2014-02-21


;;; Commentary:

;; Automatically pastes contents of clipboard if change detected
;; after n seconds. Useful for taking notes from web pages, etc.
;; 
;; Usage
;; Bind (clipmon-toggle) to a key, eg M-f2, and use this to start/stop clipmon. 
;; Start the timer - it will check the clipboard every clipmon-interval seconds.
;; If the clipboard has changed, it will paste the contents at the current location. 
;; If no change is detected after clipmon-timeout seconds, it will turn off the timer, 
;; or you can call (clipmon-stop) turn it off manually.
;; You can also call (clipmon-toggle) to turn it on or off. 
;;
;; Suggested binding
;; (global-set-key (kbd "<M-f2>") 'clipmon-toggle)
 

;;; Todo:

;> add visual indicator that clipmon is on
;> only use external clipboard, not emacs one. so can cut/rearrange text while it's running.
;> make custom group
 
;> bug - try to start with empty kill ring - gives error on calling current-kill

;> bug - lost timer
; when put laptop to sleep with it on, on resuming,
; it seemed to lose track of the timer, and couldn't turn it off without
; calling (cancel-function-timers 'clipmon-tick)


;;; Code:

(require 's) ; string library

;;;; Public settings

(defcustom clipmon-interval 2
  "Interval for checking clipboard, in seconds.")

(defcustom clipmon-timeout 5
  "Stop the timer if no clipboard activity after this many minutes. Set to nil for no timeout.")

(defcustom clipmon-trim-string t
  "Remove leading whitespace from string before pasting.")

; (defcustom clipmon-remove-regexp "\\[[0-9]+\\]\\|\\[citation needed\\]"
(defcustom clipmon-remove-regexp "\\[[0-9]+\\]\\|\\[citation needed\\]\\|\\[by whom?\\]"
  "Regexp to match text to remove before pasting, eg Wikipedia-style references - [3], [12].")

; test
; (setq clipmon-remove-regexp "\\[([0-9]+\\|citation needed)\\]")
; (setq clipmon-remove-regexp "\\[[0-9]+\\]")
; (setq clipmon-remove-regexp "\\[citation needed\\]")
; (setq clipmon-remove-regexp "\\[[0-9]+\\]\\|\\[citation needed\\]")
; (replace-regexp-in-string clipmon-remove-regexp "" "Page [37][citation needed]foo.")

; (replace-regexp-in-string  "[0-9]+" ""  "Page[37][foo]1932.")
; (replace-regexp-in-string  "\\[[0-9]+\\]" ""  "Page[37][foo]1932.")
; (replace-regexp-in-string  "\\[foo\\]" ""  "Page[37][foo]1932.")
; (replace-regexp-in-string  "foo\\|37" ""  "Page[37][foo]1932.")
; (replace-regexp-in-string "\\[[0-9]+\\]" "" "[3] foo [[bar]] [zork] [] [14.0] quirp[37][38][39]. changed[40][41]")


(defcustom clipmon-newlines 2
  "Number of newlines to append after pasting clipboard contents.")

; (defcustom clipmon-sound (concat (load-file-directory) "ting.wav")
(defcustom clipmon-sound (concat (load-file-directory) "ding.wav")
  "Sound to play when pasting text - t for default beep, nil for none, or path to sound file.")

; test
; (unbind 'clipmon-sound)
; (setq clipmon-sound nil)
; (setq clipmon-sound t)
; (setq clipmon-sound (path-current "ting.wav"))
; (setq clipmon-sound (path-current "ding.wav"))
; (setq clipmon-sound (concat (file-directory) "ting.wav"))
; (setq clipmon-sound (concat (file-directory) "ding.wav"))


;;;; Public functions

(defun clipmon-toggle ()
  "Turn clipmon on and off."
  (interactive)
  (if clipmon-timer (clipmon-stop) (clipmon-start)))


(defun clipmon-start () 
  "Start the clipboard monitor timer, and check the clipboard contents each interval."
  (interactive)
  (setq clipmon-keys (function-get-keys 'clipmon-toggle)) ; eg "<M-f2>, C-0"
  (if clipmon-timer (message "Clipboard monitor already running. Stop with %s." clipmon-keys)
    (setq clipmon-previous-contents (clipboard-contents))
    (setq clipmon-timeout-start (time))
    (setq clipmon-timer (run-at-time nil clipmon-interval 'clipmon-tick))
    (message "Clipboard monitor started with timer interval %d seconds. Stop with %s." clipmon-interval clipmon-keys)
    (clipmon-play-sound)
    ))


(defun clipmon-stop () 
  "Stop the clipboard monitor timer."
  (interactive)
  (cancel-timer clipmon-timer)
  (setq clipmon-timer nil)
  (message "Clipboard monitor stopped.")
  (clipmon-play-sound)
  )

; test
; (clipmon-start)
; timer-list
; (clipmon-stop)
; (cancel-function-timers 'clipmon-tick)



;;;; ------------------------------------------------------------
;;;; Private variables

(defvar clipmon-timer nil "Timer handle for clipboard monitor.")
(defvar clipmon-timeout-start nil "Time that timeout timer was started.")
(defvar clipmon-previous-contents nil "Last contents of the clipboard.")


;;;; Private functions

(defun clipmon-tick ()
  "Check the contents of the clipboard - if it has changed, paste the contents."
  (let ((s (clipboard-contents)))
    (if (not (string-equal s clipmon-previous-contents))
        (clipmon-paste s)
        ; no change in clipboard - if timeout is set, stop monitor if it's been idle a while
        (if clipmon-timeout
            (let ((idletime (- (time) clipmon-timeout-start)))
              (when (> idletime (* 60 clipmon-timeout))
                (clipmon-stop)
                (message "Clipboard monitor stopped after %d minutes of inactivity." clipmon-timeout)
                )))
        )))


(defun clipmon-paste (s)
  "Insert the string at the current location, play sound, and update the state."
  (setq clipmon-previous-contents s)
  (if clipmon-trim-string (setq s (s-trim-left s)))
  ; (if clipmon-remove-wikipedia-references (setq s (replace-regexp-in-string "\\[[0-9]+\\]" "" s)))
  (if clipmon-remove-regexp (setq s (replace-regexp-in-string clipmon-remove-regexp "" s)))
  (insert s)
  (dotimes (i clipmon-newlines) (insert "\n"))
  (if clipmon-sound (clipmon-play-sound))
  (setq clipmon-timeout-start (time)))


(defun clipmon-play-sound ()
  "Play a sound file, the default beep, or nothing."
  (if clipmon-sound
      (if (stringp clipmon-sound) (play-sound-file clipmon-sound) (beep))))


;;;; Library functions

(defun clipboard-contents (&optional arg)
  "Return the current or previous clipboard contents.
With nil or 0 argument, return the most recent item.
With numeric argument, return that item.
With :all, return all clipboard contents in a list."
  (cond
   ((null arg) (current-kill 0))
   ((integerp arg) (current-kill arg))
   ((eq :all arg) kill-ring)
   (t nil)))

; test
; (clipboard-contents)
; (clipboard-contents 0)
; (clipboard-contents 9)
; (clipboard-contents :all)


(defun function-get-keys (function)
  "Get list of keys bound to a function, as a string.
For example, (function-get-keys 'ibuffer) => 'C-x C-b, <menu-bar>...'"
  (mapconcat 'key-description (where-is-internal function) ", "))

; test
; (function-get-keys 'where-is)
; (function-get-keys 'ibuffer)
; (function-get-keys 'undo)


; used to get path to included sound file
(defun load-file-directory ()
  "Get directory of file being loaded."
  (file-name-directory load-file-name))

; test - load-file-name is normally set by emacs during file load
; (let ((load-file-name "c:/foo/")) (load-file-directory))
; (let ((load-file-name "c:/foo/")) (concat (load-file-directory) "ting.wav")) 


;;;; Provide

(provide 'clipmon)

;;; clipmon.el ends here

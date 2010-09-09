;;;; General utility code used by all of Vimpulse;
;;;; may be useful to the end user

;;; Autogenerated vi bindings

(defun vimpulse-augment-keymap
  (map augment-alist &optional replace)
  "Augment MAP with bindings from AUGMENT-ALIST.
If REPLACE is non-nil, bindings in MAP may be overwritten.
AUGMENT-ALIST has the format ((KEY . DEF) ...),
where KEY and DEF are passed to `define-key'."
  (let (key def num)
    (dolist (binding augment-alist)
      (setq key (car binding)
            def (cdr binding)
            num (lookup-key map key))
      (cond
       (replace
        (when (numberp num)
          (define-key map (vimpulse-truncate key num) nil))
        (define-key map key def))
       (t
        (when (numberp num)
          (setq num (lookup-key map (vimpulse-truncate key num))))
        (unless num
          (define-key map key def)))))))

(defun vimpulse-add-vi-bindings (map cmds &optional replace filter)
  "Add vi bindings for CMDS to MAP.
Add forcefully if REPLACE is t. Don't add keys matching FILTER,
which is a list of key vectors."
  (let ((bindings (apply 'vimpulse-get-vi-bindings cmds)))
    (unless filter
      (when (and (boundp 'viper-want-ctl-h-help)
                 viper-want-ctl-h-help)
        (add-to-list 'filter [?\C-h]))
      (unless (and (boundp 'vimpulse-want-C-u-like-Vim)
                   vimpulse-want-C-u-like-Vim)
        (add-to-list 'filter [?\C-u])))
    (dolist (key filter)
      (setq bindings (assq-delete-all key bindings)))
    (vimpulse-augment-keymap map bindings replace)))

(defun vimpulse-get-bindings (cmd &rest maps)
  "Return assocation list of bindings for CMD in MAPS."
  (let (keys bindings)
    (setq maps (or maps '(nil)))
    (dolist (map maps bindings)
      (unless (keymapp map)
        (setq map (eval map)))
      (setq keys (where-is-internal cmd map))
      (dolist (key keys)
        (unless (assq key bindings)
          (add-to-list 'bindings (cons key cmd) t))))))

(defun vimpulse-get-vi-bindings (&rest cmds)
  "Return assocation list of vi bindings for CMDS."
  (let (bindings)
    (dolist (cmd cmds bindings)
      (dolist (binding (apply 'vimpulse-get-bindings cmd
                              '(viper-vi-intercept-map
                                viper-vi-local-user-map
                                viper-vi-global-user-map
                                viper-vi-kbd-map
                                viper-vi-diehard-map
                                viper-vi-basic-map)))
        (unless (assq (car binding) bindings)
          (add-to-list 'bindings binding t))))))

(defun vimpulse-add-movement-cmds (map &optional replace)
  "Add Viper/Vimpulse movement commands to MAP.
The commands are taken from `vimpulse-viper-movement-cmds' and looked
up in vi keymaps. If REPLACE is non-nil, may overwrite bindings
in MAP."
  (vimpulse-add-vi-bindings map vimpulse-viper-movement-cmds replace))

;; the default for this function is to replace rather than augment,
;; as core navigation should be present everywhere
(defun vimpulse-add-core-movement-cmds (map &optional augment)
  "Add \"core\" movement commands to MAP, forcefully.
The commands are taken from `vimpulse-core-movement-cmds'.
If AUGMENT is non-nil, don't overwrite bindings in MAP."
  (vimpulse-add-vi-bindings map
                            vimpulse-core-movement-cmds
                            (not augment)))

(defun vimpulse-inhibit-cmds (map cmds &optional replace)
  "Remap CMDS to `viper-nil' in MAP.
REPLACE is passed to `vimpulse-augment-keymap'."
  (vimpulse-augment-keymap
   map (mapcar (lambda (cmd)
                 (cons `[remap ,cmd] 'viper-nil))
               cmds) replace))

(defun vimpulse-inhibit-movement-cmds (map &optional replace)
  "Remap Viper movement commands to `viper-nil' in MAP.
The commands are taken from `vimpulse-viper-movement-cmds'.
If REPLACE is non-nil, may overwrite bindings in MAP."
  (vimpulse-inhibit-cmds map vimpulse-viper-movement-cmds replace))

(defun vimpulse-inhibit-other-movement-cmds (map &optional replace)
  "Remap non-core Viper movement commands to `viper-nil' in MAP.
The commands are taken from `vimpulse-viper-movement-cmds'.
If REPLACE is non-nil, may overwrite bindings in MAP."
  (let ((cmds vimpulse-viper-movement-cmds))
    ;; remove core movement commands
    (dolist (cmd vimpulse-core-movement-cmds)
      (setq cmds (delq cmd cmds)))
    (vimpulse-inhibit-cmds map cmds replace)))

(defun vimpulse-inhibit-destructive-cmds (map &optional replace)
  "Remap destructive Viper commands to `viper-nil' in MAP."
  (let ((cmds '(viper-Append
                viper-Insert
                viper-append
                viper-change-to-eol
                viper-command-argument
                viper-insert
                viper-kill-line
                viper-substitute
                viper-substitute-line
                vimpulse-change
                vimpulse-delete
                vimpulse-visual-append
                vimpulse-visual-insert)))
    (vimpulse-inhibit-cmds map cmds replace)))

(defmacro vimpulse-remap (keymap from to)
  "Remap FROM to TO in KEYMAP.
For XEmacs compatibility, KEYMAP should have a `remap-alist'
property referring to a variable used for storing a \"remap
association list\"."
  (if (featurep 'xemacs)
      `(let ((remap-alist (get ',keymap 'remap-alist))
             (from ,from) (to ,to))
         (when remap-alist
           (add-to-list remap-alist (cons from to))))
    `(let ((keymap ,keymap) (from ,from) (to ,to))
       (define-key keymap `[remap ,from] to))))

(defun vimpulse-vi-remap (from to &optional keymap)
  "Remap FROM to TO in vi (command) state.
If KEYMAP is specified, take the keys that FROM is bound to
in vi state and bind them to TO in KEYMAP."
  (if keymap
      (vimpulse-augment-keymap
       keymap
       (mapcar (lambda (binding)
                 (cons (car binding) to))
               (vimpulse-get-vi-bindings from)))
    (define-key viper-vi-basic-map `[remap ,from] to)))

;;; States

(defmacro vimpulse-with-state (state &rest body)
  "Execute BODY with Viper state STATE, then restore previous state."
  (declare (indent defun))
  `(let ((new-viper-state ,state)
         (old-viper-state viper-current-state))
     (unwind-protect
         (progn
           (viper-set-mode-vars-for new-viper-state)
           (let ((viper-current-state new-viper-state))
             (viper-normalize-minor-mode-map-alist)
             ,@body))
       (viper-set-mode-vars-for old-viper-state)
       (viper-normalize-minor-mode-map-alist))))

(when (fboundp 'font-lock-add-keywords)
  (font-lock-add-keywords
   'emacs-lisp-mode
   '(("(\\(vimpulse-with-state\\)\\>" 1 font-lock-keyword-face))))

;;; Vector tools

(defun vimpulse-truncate (vector length &optional offset)
  "Return a copy of VECTOR truncated to LENGTH.
If LENGTH is negative, skip last elements of VECTOR.
If OFFSET is specified, skip first elements of VECTOR."
  ;; if LENGTH is too large, trim it
  (when (> length (length vector))
    (setq length (length vector)))
  ;; if LENGTH is negative, convert it to the positive equivalent
  (when (< length 0)
    (setq length (max 0 (+ (length vector) length))))
  (if offset
      (setq length (- length offset))
    (setq offset 0))
  (let ((result (make-vector length t)))
    (dotimes (idx length result)
      (aset result idx (aref vector (+ idx offset))))))

;; This is useful for deriving a "standard" key-sequence from
;; `this-command-keys', to be looked up in `vimpulse-careful-alist'.
(defun vimpulse-strip-prefix (key-sequence &optional string)
  "Strip any prefix argument keypresses from KEY-SEQUENCE.
If STRING is t, output a string if possible.
Otherwise output a vector."
  (let* ((offset 0)
         (temp-sequence (vconcat key-sequence))
         (key (aref temp-sequence offset))
         (length (length temp-sequence))
         temp-string)
    ;; if XEmacs, get rid of the event object type
    (and (featurep 'xemacs) (eventp key)
         (setq key (event-to-character key nil t)))
    ;; any keys bound to `universal-argument', `digit-argument' or
    ;; `negative-argument' or bound in `universal-argument-map'
    ;; are considered prefix keys
    (while (and (or (memq (key-binding (vector key) t)
                          '(universal-argument
                            digit-argument
                            negative-argument))
                    (lookup-key universal-argument-map
                                (vector key)))
                (setq offset (1+ offset))
                (< offset length))
      (setq key (aref temp-sequence offset))
      (and (featurep 'xemacs) (eventp key)
           (setq key (event-to-character key nil t))))
    (if (and string
             ;; string conversion is impossible if the vector
             ;; contains a non-numerical element
             (not (memq nil (mapcar 'integerp (append temp-sequence nil)))))
        (concat (vimpulse-truncate temp-sequence length offset))
      (vimpulse-truncate temp-sequence length offset))))

;; GNU Emacs 22 lacks `characterp'
(unless (fboundp 'characterp)
  (defalias 'characterp 'integerp))

;;; Movement

(defun vimpulse-move-to-column (column &optional dir force)
  "Move point to column COLUMN in the current line.
Places point at left of the tab character (at the right
if DIR is non-nil) and returns point.
If `vimpulse-visual-block-untabify' is non-nil, then
tabs are changed to spaces. (FORCE untabifies regardless.)"
  (interactive "p")
  (if (or vimpulse-visual-block-untabify force)
      (move-to-column column t)
    (move-to-column column)
    (when (or (not dir) (and (numberp dir) (< dir 1)))
      (when (> (current-column) column)
        (unless (bolp)
          (backward-char)))))
  (point))

(defmacro vimpulse-limit (start end &rest body)
  "Eval BODY, but limit point to buffer-positions START and END.
Both may be nil. Returns position."
  (declare (indent 2))
  `(let ((start (or ,start (point-min)))
         (end   (or ,end   (point-max))))
     (when (> start end)
       (setq start (prog1 end
                     (setq end start))))
     (save-restriction
       (narrow-to-region start end)
       ,@body
       (point))))

(defmacro vimpulse-skip (dir bounds &rest body)
  "Eval BODY, but limit point to BOUNDS in DIR direction.
Returns position."
  (declare (indent 2))
  `(let ((dir ,dir) (bounds ,bounds) start end)
     (setq dir (if (and (numberp dir) (< dir 0)) -1 1))
     (dolist (bound bounds)
       (unless (numberp bound)
         (setq bounds (delq bound bounds))))
     (when bounds
       (if (< dir 0)
           (setq start (apply 'min bounds))
         (setq end (apply 'max bounds))))
     (vimpulse-limit start end ,@body)))

(defun vimpulse-skip-regexp (regexp dir &rest bounds)
  "Move point in DIR direction based on REGEXP and BOUNDS.
REGEXP is passed to `looking-at' or `looking-back'.
If DIR is positive, move forwards to the end of the regexp match,
but not beyond any buffer positions listed in BOUNDS.
If DIR is negative, move backwards to the beginning of the match.
Returns the new position."
  (setq dir (if (and (numberp dir) (< dir 0)) -1 1))
  (setq regexp (or regexp ""))
  (vimpulse-skip dir bounds
    (if (< dir 0)
        (when (looking-back regexp nil t)
          (goto-char (match-beginning 0)))
      (when (looking-at regexp)
        (goto-char (match-end 0))))))

;; XEmacs only has `looking-at'
(unless (fboundp 'looking-back)
  (defun looking-back (regexp &optional limit greedy)
    "Return t if text before point matches regular expression REGEXP."
    (let ((start (point))
          (pos
           (save-excursion
             (and (re-search-backward
                   (concat "\\(?:" regexp "\\)\\=") limit t)
                  (point)))))
      (if (and greedy pos)
          (save-restriction
            (narrow-to-region (point-min) start)
            (while (and (> pos (point-min))
                        (save-excursion
                          (goto-char pos)
                          (backward-char 1)
                          (looking-at
                           (concat "\\(?:" regexp "\\)\\'"))))
              (setq pos (1- pos)))
            (save-excursion
              (goto-char pos)
              (looking-at (concat "\\(?:"  regexp "\\)\\'")))))
      (not (null pos)))))

(defun vimpulse-backward-up-list (&optional arg)
  "Like `backward-up-list', but breaks out of strings."
  (interactive "p")
  (let ((orig (point)))
    (setq arg (or arg 1))
    (while (progn
             (condition-case
                 nil (backward-up-list arg)
               (error nil))
             (when (eq (point) orig)
               (backward-char)
               (setq orig (point)))))))

;;; Region

;; GNU Emacs 22 lacks `region-active-p'
(unless (fboundp 'region-active-p)
  (defun region-active-p ()
    (and transient-mark-mode mark-active)))

(defun vimpulse-region-face ()
  "Return face of region."
  (if (featurep 'xemacs) 'zmacs-region 'region))

(defun vimpulse-deactivate-region (&optional now)
  "Deactivate region, respecting Emacs version."
  (cond
   ((and (boundp 'cua-mode) cua-mode
         (fboundp 'cua--deactivate))
    (cua--deactivate now))
   ((featurep 'xemacs)
    (let ((zmacs-region-active-p t))
      (zmacs-deactivate-region)))
   (now
    (setq mark-active nil))
   (t
    (setq deactivate-mark t))))

(defun vimpulse-activate-region (&optional pos)
  "Activate mark if there is one. Otherwise set mark at point.
If POS if specified, set mark at POS instead."
  (setq pos (or pos (mark t) (point)))
  (cond
   ((and (boundp 'cua-mode) cua-mode)
    (let ((opoint (point))
          (oldmsg (current-message))
          message-log-max
          cua-toggle-set-mark)
      (goto-char (or pos (mark t) (point)))
      (unwind-protect
          (and (fboundp 'cua-set-mark)
               (cua-set-mark))
        (if oldmsg (message "%s" oldmsg)
          (message nil)))
      (goto-char opoint)))
   (t
    (let (this-command)
      (push-mark pos t t)))))

(defun vimpulse-set-region (beg end &optional widen dir)
  "Set Emacs region to BEG and END.
Preserves the order of point and mark, unless specified by DIR:
a positive number means mark goes before or is equal to point,
a negative number means point goes before mark. If WIDEN is
non-nil, only modifies region if it does not already encompass
BEG and END. Returns nil if region is unchanged."
  (cond
   (widen
    (vimpulse-set-region
     (min beg end (or (region-beginning) (point)))
     (max beg end (or (region-end) (point)))
     nil dir))
   (t
    (unless (region-active-p)
      (vimpulse-activate-region))
    (let* ((oldpoint (point))
           (oldmark  (or (mark t) oldpoint))
           (newmark  (min beg end))
           (newpoint (max beg end)))
      (when (or (and (numberp dir) (< dir 0))
                (and (not (numberp dir))
                     (< oldpoint oldmark)))
        (setq newpoint (prog1 newmark
                         (setq newmark newpoint))))
      (unless (or (and (numberp dir)
                       (= (min newpoint newmark)
                          (min oldpoint oldmark))
                       (= (max newpoint newmark)
                          (max oldpoint oldmark)))
                  (and (= newpoint oldpoint)
                       (= newmark  oldmark)))
        (set-mark newmark)
        (goto-char newpoint))))))

;;; Overlays (extents in XEmacs)

(eval-and-compile
  (cond
   ((featurep 'xemacs)                  ; XEmacs
    (defalias 'vimpulse-delete-overlay 'delete-extent)
    (defalias 'vimpulse-overlays-at 'extents-at))
   (t                                   ; GNU Emacs
    (defalias 'vimpulse-delete-overlay 'delete-overlay)
    (defalias 'vimpulse-overlays-at 'overlays-at))))

;; `viper-make-overlay' doesn't handle FRONT-ADVANCE
;; and REAR-ADVANCE properly in XEmacs
(defun vimpulse-make-overlay
  (beg end &optional buffer front-advance rear-advance)
  "Create a new overlay with range BEG to END in BUFFER.
In XEmacs, create an extent."
  (cond
   ((featurep 'xemacs)
    (let ((extent (make-extent beg end buffer)))
      (set-extent-property extent 'start-open front-advance)
      (set-extent-property extent 'end-closed rear-advance)
      (set-extent-property extent 'detachable nil)
      extent))
   (t
    (make-overlay beg end buffer front-advance rear-advance))))

(defun vimpulse-overlay-before-string (overlay string &optional face)
  "Set the `before-string' property of OVERLAY to STRING.
In XEmacs, change the `begin-glyph' property."
  (cond
   ((featurep 'xemacs)
    (setq face (or face (get-text-property 0 'face string)))
    (when (and string (not (glyphp string)))
      (setq string (make-glyph string)))
    (when face
      (set-glyph-face string face))
    (set-extent-begin-glyph overlay string))
   (t
    (viper-overlay-put overlay 'before-string string))))

(defun vimpulse-overlay-after-string (overlay string &optional face)
  "Set the `after-string' property of OVERLAY to STRING.
In XEmacs, change the `end-glyph' property."
  (cond
   ((featurep 'xemacs)
    (setq face (or face (get-text-property 0 'face string)))
    (when (and string (not (glyphp string)))
      (setq string (make-glyph string)))
    (when face
      (set-glyph-face string face))
    (set-extent-end-glyph overlay string))
   (t
    (viper-overlay-put overlay 'after-string string))))

;;; Undo

(defun vimpulse-refresh-undo-step ()
  "Refresh `buffer-undo-list' entries for current undo step.
Undo boundaries until `vimpulse-undo-list-pointer' are removed
to make the entries undoable as a single action.
See `vimpulse-start-undo-step'."
  (setq buffer-undo-list
        (vimpulse-filter-undo-boundaries buffer-undo-list
                                         vimpulse-undo-list-pointer)))

(defun vimpulse-filter-undo-boundaries (undo-list &optional pointer)
  "Filter undo boundaries from beginning of UNDO-LIST, until POINTER.
A boundary is a nil element, typically inserted by `undo-boundary'.
Return the filtered list."
  (cond
   ((null undo-list)
    nil)
   ((not (listp undo-list))
    undo-list)
   ((eq undo-list pointer)
    undo-list)
   ((null (car undo-list))
    (vimpulse-filter-undo-boundaries (cdr undo-list) pointer))
   (t
    (cons (car undo-list)
          (vimpulse-filter-undo-boundaries (cdr undo-list) pointer)))))

(defun vimpulse-start-undo-step ()
  "Start a single undo step.
End the step with `vimpulse-end-undo-step'.
All intermediate buffer modifications will be undoable as a
single action."
  (when (listp buffer-undo-list)
    (unless (null (car buffer-undo-list))
      (add-to-list 'buffer-undo-list nil))
    (setq vimpulse-undo-list-pointer buffer-undo-list)
    ;; Continually refresh the undo entries for the step,
    ;; ensuring proper synchronization between `buffer-undo-list'
    ;; and `buffer-undo-tree'
    (add-hook 'post-command-hook 'vimpulse-refresh-undo-step nil t)))

(defun vimpulse-end-undo-step ()
  "End a single undo step.
The step must have been started with `vimpulse-start-undo-step'.
All intermediate buffer modifications will be undoable as a
single action."
  (when (memq 'vimpulse-refresh-undo-step post-command-hook)
    (vimpulse-refresh-undo-step)
    (undo-boundary)
    (remove-hook 'post-command-hook 'vimpulse-refresh-undo-step t)))

(defmacro vimpulse-single-undo (&rest body)
  "Execute BODY as a single undo step."
  `(unwind-protect
       (progn
         (vimpulse-start-single-undo)
         ,@body)
     (vimpulse-end-single-undo)))

;;; Motion type system

(defun vimpulse-range-p (object)
  "Return t if OBJECT is a pure range (BEG END)."
  (and (listp object)
       (eq (length object) 2)
       (numberp (car object))
       (numberp (cadr object))))

(defun vimpulse-motion-range-p (object)
  "Return t if OBJECT is a motion range (TYPE BEG END)."
  (and (listp object)
       (symbolp (car object))
       (vimpulse-range-p (cdr object))))

(defun vimpulse-motion-range (object)
  "Return the range part of OBJECT."
  (cond
   ((vimpulse-motion-range-p object)
    (cdr object))
   ((vimpulse-range-p object)
    object)
   (t
    (list (point) (point)))))

(defun vimpulse-range-beginning (range)
  "Return the beginning of RANGE."
  (apply 'min (vimpulse-motion-range range)))

(defun vimpulse-range-end (range)
  "Return the end of RANGE."
  (apply 'max (vimpulse-motion-range range)))

(defun vimpulse-range-height (range &optional normalized)
  "Return height of RANGE. Normalize unless NORMALIZED.

A block range has height and width, a line range
has only height, and a character range has only width."
  (let* ((range (if normalized range
                  (vimpulse-normalize-motion-range range)))
         (beg (vimpulse-range-beginning range))
         (end (vimpulse-range-end range))
         (type (vimpulse-motion-type range)))
    (cond
     ((eq type 'block)
      (count-lines beg
                   (save-excursion
                     (goto-char end)
                     (if (and (bolp) (not (eobp)))
                         (1+ end)
                       end))))
     ((eq type 'line)
      (count-lines beg end))
     (t
      nil))))

(defun vimpulse-range-width (range &optional normalized)
  "Return width of RANGE. Normalize unless NORMALIZED.

A block range has height and width, a line range
has only height, and a character range has only width."
  (let* ((range (if normalized range
                  (vimpulse-normalize-motion-range range)))
         (beg (vimpulse-range-beginning range))
         (end (vimpulse-range-end range))
         (type (vimpulse-motion-type range)))
    (cond
     ((eq type 'block)
      (abs (- (save-excursion
                (goto-char end)
                (current-column))
              (save-excursion
                (goto-char beg)
                (current-column)))))
     ((eq type 'line)
      nil)
     (t
      (abs (- end beg))))))

(defun vimpulse-motion-type (object &optional raw)
  "Return motion type of OBJECT.
The type is one of `exclusive', `inclusive', `line' and `block'.
Defaults to `exclusive' unless RAW is specified."
  (let ((type (cond
               ((symbolp object)
                (get object 'motion-type))
               ((vimpulse-motion-range-p object)
                (car object)))))
    (if raw
        type
      (or type 'exclusive))))

(defun vimpulse-make-motion-range (beg end &optional type normalize)
  "Return motion range (TYPE BEG END).
If NORMALIZE is non-nil, normalize the range with
`vimpulse-normalize-motion-range'."
  (let* ((range (list (min beg end) (max beg end)))
         (type (or type 'exclusive)))
    (if normalize
        (vimpulse-normalize-motion-range range type)
      (cons type range))))

;; This implements section 1 of motion.txt (Vim Reference Manual)
(defun vimpulse-normalize-motion-range (range &optional type)
  "Normalize the beginning and end of a motion range (TYPE FROM TO).
Returns the normalized range.

Usually, a motion range should be normalized only once, as
information is lost in the process: an unnormalized motion range
has the form (TYPE FROM TO), while a normalized motion range has
the form (TYPE BEG END).

See also `vimpulse-block-range', `vimpulse-line-range',
`vimpulse-inclusive-range' and `vimpulse-exclusive-range'."
  (let* ((type (or type (vimpulse-motion-type range)))
         (range (vimpulse-motion-range range))
         (from (car range))
         (to   (cadr range)))
    (cond
     ((memq type '(blockwise block))
      (vimpulse-block-range from to))
     ((memq type '(linewise line))
      (vimpulse-line-range from to))
     ((eq type 'inclusive)
      (vimpulse-inclusive-range from to))
     (t
      (vimpulse-exclusive-range from to t)))))

;; Ranges returned by these functions have the form (TYPE BEG END)
;; where TYPE is one of `inclusive', `exclusive', `line' or `block'
;; and BEG and END are the buffer positions.
(defun vimpulse-block-range (from to)
  "Return a blockwise motion range delimited by FROM and TO.
Like `vimpulse-inclusive-range', but for rectangles:
the last column is included."
  (let* ((beg (min from to))
         (end (max from to))
         (beg-col (save-excursion
                    (goto-char beg)
                    (current-column)))
         (end-col (save-excursion
                    (goto-char end)
                    (current-column))))
    (save-excursion
      (cond
       ((= beg-col end-col)
        (goto-char end)
        (cond
         ((eolp)
          (goto-char beg)
          (if (eolp)
              (vimpulse-make-motion-range beg end 'block)
            (vimpulse-make-motion-range (1+ beg) end 'block)))
         (t
          (vimpulse-make-motion-range beg (1+ end) 'block))))
       ((< beg-col end-col)
        (goto-char end)
        (if (eolp)
            (vimpulse-make-motion-range beg end 'block)
          (vimpulse-make-motion-range beg (1+ end) 'block)))
       (t
        (goto-char beg)
        (if (eolp)
            (vimpulse-make-motion-range beg end 'block)
          (vimpulse-make-motion-range (1+ beg) end 'block)))))))

(defun vimpulse-line-range (from to)
  "Return a linewise motion range delimited by FROM and TO."
  (let* ((beg (min from to))
         (end (max from to)))
    (vimpulse-make-motion-range
     (save-excursion
       (goto-char beg)
       (line-beginning-position))
     (save-excursion
       (goto-char end)
       (line-beginning-position 2))
     'line)))

(defun vimpulse-inclusive-range (from to)
  "Return an inclusive motion range delimited by FROM and TO.
That is, the last character is included."
  (let* ((beg (min from to))
         (end (max from to)))
    (save-excursion
      (goto-char end)
      (unless (eobp)
        (setq end (1+ end)))
      (vimpulse-make-motion-range beg end 'inclusive))))

(defun vimpulse-exclusive-range (from to &optional normalize)
  "Return an exclusive motion range delimited by FROM and TO.
However, if NORMALIZE is t and the end of the range is at the
beginning of a line, a different type of range is returned:

  * If the start of the motion is at or before the first
    non-blank in the line, the motion becomes `line' (normalized).

  * Otherwise, the end of the motion is moved to the end of the
    previous line and the motion becomes `inclusive' (normalized)."
  (let* ((beg (min from to))
         (end (max from to)))
    (save-excursion
      (cond
       ((and normalize
             (/= beg end)
             (progn
               (goto-char end)
               (bolp)))
        (viper-backward-char-carefully)
        (setq end (max beg (point)))
        (cond
         ((save-excursion
            (goto-char beg)
            (looking-back "^[ \f\t\v]*"))
          (vimpulse-make-motion-range beg end 'line t))
         (t
          (vimpulse-make-motion-range beg end 'inclusive))))
       (t
        (vimpulse-make-motion-range beg end 'exclusive))))))

(provide 'vimpulse-utils)

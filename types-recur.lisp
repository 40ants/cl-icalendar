;; types-recur.lisp ---
;;
;;     This file implements the recur data type.
;;
;; Copyrigth (C) 2009, 2010 Mario Castelán Castro <marioxcc>
;; Copyrigth (C) 2009, 2010, 2011 David Vázquez
;;
;; This file is part of cl-icalendar.
;;
;; cl-icalendar is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; cl-icalendar is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with cl-icalendar.  If not, see <http://www.gnu.org/licenses/>.

(in-package :cl-icalendar)

;;; The RECUR data type implementation involves iteration across RECUR
;;; instances. Iteration is used in order to implement the COUNT and BYSETPOS
;;; rules basically. In the special case these rules are not present, we will
;;; say the recur is _simple_. We will use `%simple-recur-instance-p'.
;;; However, the iteration mechanism will works anyway.
;;;
;;; According to FREQ recur rule, the BY* rules could be classified in
;;; expansion rules and limitation ones. On the one hand, the expansion rules,
;;; are used to select what datetimes of a interval are instances in a
;;; recur. On the other hand, the limitation rules are used in order to
;;; distinguish which intervals are candidate to contain instances. See BYDAY
;;; for some exceptions. This is implemented in the source code described here
;;; by couples of functions which are named %recur-list-instances-* and
;;; %recur-next-*, respectively. These functions ignore COUNT and BYSETPOS
;;; recur rules.
;;;
;;; Finally, `recur-iterator-new' and `recur-iterator-next' will dispatch upon
;;; previous functions, in addition of add support for COUNT and BYSETPOS
;;; rules. A high level macro `do-recur-instances' is also provided.

(deftype non-zero-integer (a b)
  `(and (integer ,a ,b) (not (eql 0))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *frequencies*
    '(:secondly :minutely :hourly :daily :weekly :monthly :yearly)))

(deftype recur-frequence () `(member ,@*frequencies*))

;;; Alist of frequency strings and values.
(defvar *frequency-table*
  (mapcar (lambda (s) (cons (string s) s)) *frequencies*))

;;; The recur data type value is documented in the section 3.3.10,
;;; named `Recurrence Rule' of RFC5545.
(defclass recur ()
  ((freq
    :initarg :freq
    :type recur-frequence
    :reader recur-freq)
   (until
    :initarg :until
    :type (or null datetime date)
    :initform nil
    :reader recur-until)
   (count
    :initarg :count
    :type (or null unsigned-byte)
    :initform nil
    :reader recur-count)
   (interval
    :initarg :interval
    :type (integer 1 *)
    :initform 1
    :reader recur-interval)
   (bysecond
    :initarg :bysecond
    :type list
    :initform nil
    :reader recur-bysecond)
   (byminute
    :initarg :byminute
    :type list
    :initform nil
    :reader recur-byminute)
   (byhour
    :initarg :byhour
    :type list
    :initform nil
    :reader recur-byhour)
   ;; Each element of byday list is a pair (wday . n), where wday is a weekday
   ;; value, and n is the optional prefix in the byday rule.
   (byday
    :initarg :byday
    :type list
    :initform nil
    :reader recur-byday)
   (bymonthday
    :initarg :bymonthday
    :type list
    :initform nil
    :reader recur-bymonthday)
   (byyearday
    :initarg :byyearday
    :type list
    :initform nil
    :reader recur-byyearday)
   (byweekno
    :initarg :byweekno
    :type list
    :initform nil
    :reader recur-byweekno)
   (bymonth
    :initarg :bymonth
    :type list
    :initform nil
    :reader recur-bymonth)
   (bysetpos
    :initarg :bysetpos
    :type list
    :initform nil
    :reader recur-bysetpos)
   (wkst
    :initarg :wkst
    :type weekday
    :initform :monday
    :reader recur-wkst)))

(register-ical-value recur)

;;; Return a new recur value.
(defun make-recur (freq &rest args)
  (apply #'make-instance 'recur :freq freq args))

;;; The predicate function in order to check if an arbitrary object is a
;;; recurrence value.
(define-predicate-type recur)

(defprinter (obj recur)
  (write-string (format-value obj 'recur)))

;;; Bind the symbols FREQ, UNTIL, COUNT, INTERVAL, BYSECOND, BYMINUTE, BYHOUR,
;;; BYDAY, BYMONTHDAY, BYYEARDAY, BYWEEKNO, BYMONTH, BYSETPOSWKST, WKST and
;;; BYSETPOS to the respective slot values of RECUR. These symbols are
;;; setf-able too.
(defmacro with-recur-slots (recur &body code)
  `(with-slots (freq until count interval bysecond byminute byhour
                     byday bymonthday byyearday byweekno bymonth
                     bysetposwkst wkst bysetpos)
       ,recur
     (declare (ignorable
               freq until count interval bysecond byminute byhour
               byday bymonthday byyearday byweekno bymonth
               bysetposwkst wkst bysetpos))
     ,@code))

;;; Check the consistency of RECUR. This function makes sure the type of
;;; slot's values in the recur instance are valid. This is not redundant with
;;; :type slots options. The slot types are checked when a recur is
;;; instantiated, while check-recur-consistency is called after
;;; parsing. Indeed, check-recur-consistency is more intensive.
(defun check-recur-consistency (recur)
  (unless (slot-boundp recur 'freq)
    (%parse-error "FREQ rule is required."))
  (with-recur-slots recur
    (check-type freq recur-frequence)
    (unless (or (not until) (not count))
      (%parse-error "You cannot specify both UNTIL and COUNT recur rules."))
    ;; Check optional slots
    (check-type until (or null date datetime))
    (check-type count (or null (integer 0 *)))
    (check-type interval (or null (integer 0 *)))
    (check-type wkst weekday)
    ;; Check list slots
    (unless (or (eq freq :monthly)
                (eq freq :yearly))
      (dolist (bydayrule byday)
        (when (cdr bydayrule)
          (%parse-error "prefix weekday cannot be specified in a other monthly or yearly recurs."))))
    (check-type-list bysecond (integer 0 60))
    (check-type-list byminute (integer 0 59))
    (check-type-list byhour (integer 0 23))
    (check-type-list bymonthday (non-zero-integer  -31  31))
    (check-type-list byyearday (non-zero-integer -366 366))
    (check-type-list byweekno (non-zero-integer  -53  53))
    (check-type-list bymonth (integer 0 12))
    (check-type-list bysetpos (non-zero-integer -366 366))))


;;;; Date and time related functions

;;; Check if the frequence X is lesser than the Y one.
(defun freq< (x y)
  (declare (recur-frequence x y))
  (member< x y *frequencies*))

;;; Return the nth DAY of month in year. This handles negative days propertily .
(defun monthday (day month year)
  (let ((monthdays
         (if (leap-year-p year)
             #(0 31 29 31 30 31 30 31 31 30 31 30 31)
             #(0 31 28 31 30 31 30 31 31 30 31 30 31))))
    (mod* day (svref monthdays month))))

(defun monthday-list (days month year)
  (mapcar #'monthday days (circular month) (circular year)))

;;; Return the nth DAY in year. This handles negative days propertily.
(defun yearday (day year)
  (if (leap-year-p year)
      (mod* day 366)
      (mod* day 365)))

(defun yearday-list (days year)
  (mapcar #'yearday days (circular year)))

;;; Iterate across the cartesian product of several lists. Each element of
;;; FORMS is a list of the form (variable list). LIST is evaluated and the
;;; body is run with variables bound to the values.
(defmacro do-cartesian (forms &body code)
  (if (null forms)
      `(progn ,@code)
      (destructuring-bind ((var list) &rest others)
          forms
        `(dolist (,var ,list)
           (do-cartesian ,others
             ,@code)))))

;;; The until-satisfy-conditions macro implements a new control form. The syntax is:
;;;
;;;    (until-satisfy-conditions (variable initial-form)
;;;      (condition1
;;;        ...body1...)
;;;      (condition2
;;;        ...body2...)
;;;      ...)
;;;
;;; First, INITIAL-FORM is evaluated and VARIABLE is bound to its value. Then,
;;; for each iteration the conditions are evaluated in order, until one is not
;;; verified. In that case, the associated body is run and the we repeat the
;;; loop modifying the variable to the returned value by the last expression
;;; in that body. If all conditions are verified, the loop finishes and return
;;; the current value of VARIABLE.
(defmacro until-satisfy-conditions ((variable value) &body code)
  (with-gensyms (initial)
    (check-type variable symbol)
    `(let ((,variable ,value))
         (tagbody
            ,initial
            ,@(loop
                 for (condition . body) in code
                 collect
                 `(unless ,condition
                    (setf ,variable (progn ,@body))
                    (go ,initial))))
         ,variable)))


(defmacro belong (list element &key key)
  (once-only (list element key)
    `(implyp ,list (find ,element ,list :key ,key))))


;;; Return a recur such that the omitted rules: BYSECOND, BYMINUTE, BYHOUR,
;;; BYMONTHDAY, BYMONTH, and BYDAY, are filled with default values taken from
;;; the DTSTART datetime.
(defun %complete-recur (recur dtstart)
  (decoded-universal-time
      (:second dtsec :minute dtmin :hour dthour :date dtdate :month dtmonth)
      dtstart
    (with-recur-slots recur
      (make-instance 'recur
                     :freq freq
                     :until until
                     :count count
                     :interval interval
                     :bysetpos bysetpos
                     :wkst wkst
                     :byyearday byyearday
                     :byweekno byweekno
                     :bysecond (or bysecond (list dtsec))
                     :byminute (or byminute (and (freq< :minutely freq) (list dtmin)))
                     :byhour (or byhour (and (freq< :hourly freq) (list dthour)))
                     :byday (or byday
                                (and (or byweekno (eq freq :weekly))
                                     (list (list (day-of-week dtstart)))))
                     :bymonthday
                     (or bymonthday (and (freq< :weekly freq)
                                         (not byday)
                                         (not byyearday)
                                         (not byweekno)
                                         (list dtdate)))
                     :bymonth
                     (or bymonth (and (freq< :monthly freq)
                                      (not byday)
                                      (not byyearday)
                                      (not byweekno)
                                      (list dtmonth)))))))

;;; Given a DATETIME and a RECUR, return a couple of values which are the
;;; limits of the interval which the datetime belongs to.
(defun interval-limits (datetime recur)
  (case (recur-freq recur)
    (:secondly
     (values datetime datetime))
    (:minutely
     (values (adjust-time datetime :second 0)
             (adjust-time datetime :second 59)))
    (:hourly
     (values (adjust-time datetime :minute 00 :second 00)
             (adjust-time datetime :minute 59 :second 59)))
    (:daily
     (values (adjust-time datetime :hour 00 :minute 00 :second 00)
             (adjust-time datetime :hour 23 :minute 59 :second 59)))
    (:weekly
     (values (previous-weekday (date+ datetime 1) (recur-wkst recur))
             (date+ (next-weekday datetime (recur-wkst recur)) -1)))
    (:monthly
     (values (beginning-of-month datetime)
             (end-of-month datetime)))
    (:yearly
     (values (beginning-of-year datetime)
             (end-of-year datetime)))))

;;; Check if DATETIME is compatible with a byday VALUE for the interval given
;;; for START and END datetimes. The limits START and END are inclusive.
(defun byday-compatible-p (value datetime start end)
  (let* ((day-of-week (day-of-week datetime))
         (first-day (next-weekday (date+ start -1) day-of-week))
         (last-day  (previous-weekday (date+ end 1) day-of-week))
         (total-weeks (1+ (weeks-between first-day last-day))))
    (and value
         (loop for (weekday . n) in value thereis
              (when (eq day-of-week weekday)
                (or (null n)
                    (let* ((weeks (1+ (weeks-between first-day datetime))))
                      (and (< 0 weeks)
                           (= (mod* n total-weeks) (mod* weeks total-weeks))))))))))


;;; Handle some very simple cases of `recur-instance-p'. In general, every
;;; recur without BYSETPOS either COUNT rules are handled here, because it is
;;; not needed to iterate.
(defun %simple-recur-instance-p (start recur datetime)
  (with-recur-slots recur
    ;; (assert (not bysetpos))
    ;; (assert (not count))
    (and
     ;; DATETIME is an instance of RECUR if and only if all the following
     ;; conditions are satisfied.
     (ecase freq
       (:secondly (zerop (mod (seconds-between start datetime) interval)))
       (:minutely (zerop (mod (minutes-between start datetime) interval)))
       (:hourly   (zerop (mod (hours-between   start datetime) interval)))
       (:daily    (zerop (mod (days-between    start datetime) interval)))
       (:weekly   (zerop (mod (weeks-between   start datetime) interval)))
       (:monthly  (zerop (mod (months-between  start datetime) interval)))
       (:yearly   (zerop (mod (years-between   start datetime) interval))))
     ;; Before UNTIL
     (or (null until) (<= start datetime))
     ;; Other rules
     (multiple-value-bind (second minute hour date month year)
         (decode-universal-time datetime)
       (let ((byyearday (yearday-list byyearday year))
             (bymonthday (monthday-list bymonthday month year)))
         (and
          (belong byhour hour)
          (belong byminute minute)
          (belong bysecond second)
          (belong bymonthday date)
          (belong bymonth month)
          (belong byweekno (week-of-year datetime wkst))
          (belong byyearday (day-of-year datetime))
          (implyp byday
                  (multiple-value-bind (start end)
                      (interval-limits datetime recur)
                    (byday-compatible-p byday datetime start end)))))))))


(defun %recur-list-instances-in-second (dt recur)
  (declare (ignorable recur))
  (list dt))

(defun %recur-next-second (dt recur)
  (with-recur-slots recur
    (until-satisfy-conditions (datetime (forward-second dt interval))
      ((belong bymonth (date-month datetime))
       (adjust-datetime (forward-month datetime) :day 1 :hour 00 :minute 00 :second 00))
      ((belong byyearday (day-of-year datetime)
               :key (lambda (yday) (yearday yday (date-year datetime))))
       (adjust-time (forward-day datetime) :hour 00 :minute 00 :second 00))
      ((belong bymonthday (date-day datetime)
               :key (lambda (mday)
                      (let ((month (date-month datetime))
                            (year  (date-year datetime)))
                        (monthday mday month year))))
       (adjust-time (forward-day datetime) :hour 00 :minute 00 :second 00))
      ((belong byday (day-of-week datetime) :key #'car)
       (adjust-time (forward-day datetime) :hour 00 :minute 00 :second 00))
      ((belong byhour (time-hour datetime))
       (adjust-time (forward-hour datetime) :minute 00 :second 00))
      ((belong byminute (time-minute datetime))
       (adjust-time (forward-minute datetime) :second 00))
      ((belong bysecond (time-second datetime))
       (forward-second datetime interval)))))

(defun %recur-list-instances-in-minute (dt recur)
  (with-collect
    (do-cartesian ((second (recur-bysecond recur)))
      (collect (adjust-time dt :second second)))))

(defun %recur-next-minute (dt recur)
  (with-recur-slots recur
    (until-satisfy-conditions (datetime (forward-minute dt interval))
      ((belong bymonth (date-month datetime))
       (adjust-datetime (forward-month datetime) :day 01 :hour 00 :minute 00))
      ((belong byyearday (day-of-year datetime)
               :key (lambda (yday)
                      (yearday yday (date-year datetime))))
       (adjust-time (forward-day datetime) :hour 00 :minute 00))
      ((belong bymonthday (date-day datetime)
               :key (lambda (mday)
                      (let ((month (date-month datetime))
                            (year  (date-year datetime)))
                        (monthday mday month year))))
       (adjust-time (forward-day datetime) :hour 00 :minute 00))
      ((belong byday (day-of-week datetime) :key #'car)
       (adjust-time (forward-day datetime) :hour 00 :minute 00))
      ((belong byhour (time-hour datetime))
       (adjust-time (forward-hour datetime) :minute 00))
      ((belong byminute (time-minute datetime))
       (forward-minute datetime interval)))))

(defun %recur-list-instances-in-hour (dt recur)
  (with-collect
    (do-cartesian ((minute (recur-byminute recur))
                   (second (recur-bysecond recur)))
      (collect (adjust-time dt :minute minute :second second)))))

(defun %recur-next-hour (dt recur)
  (with-recur-slots recur
    (until-satisfy-conditions (datetime (forward-hour dt interval))
      ((belong bymonth (date-month datetime))
       (adjust-datetime (forward-month datetime) :day 01 :hour 00))
      ((belong byyearday (day-of-year datetime)
               :key (lambda (yday)
                      (yearday yday (date-year datetime))))
       (adjust-time (forward-day datetime) :hour 00))
      ((belong bymonthday (date-day datetime)
               :key (lambda (mday)
                      (let ((month (date-month datetime))
                            (year  (date-year datetime)))
                        (monthday mday month year))))
       (adjust-time (forward-day datetime) :hour 00))
      ((belong byday (day-of-week datetime) :key #'car)
       (adjust-time (forward-day datetime) :hour 00))
      ((belong byhour (time-hour datetime))
       (forward-hour datetime interval)))))

(defun %recur-list-instances-in-day (dt recur)
  (with-collect
    (do-cartesian ((h (recur-byhour recur))
                   (m (recur-byminute recur))
                   (s (recur-bysecond recur)))
      (collect (adjust-time dt :hour h :minute m :second s)))))

(defun %recur-next-day (dt recur)
  (with-recur-slots recur
    (until-satisfy-conditions (datetime (forward-day dt interval))
      ((belong bymonth (date-month datetime))
       (adjust-date (forward-month datetime) :day 01))
      ((belong bymonthday (date-day datetime)
               :key (lambda (mday)
                      (let ((month (date-month datetime))
                            (year (date-year datetime)))
                        (monthday mday month year))))
       (forward-day datetime interval))
      ((belong byday (day-of-week datetime) :key #'car)
       (forward-day datetime interval)))))

(defun %recur-list-instances-in-week (dt recur)
  (with-collect
    (do-cartesian ((d (recur-byday recur))
                   (h (recur-byhour recur))
                   (m (recur-byminute recur))
                   (s (recur-bysecond recur)))
      (let ((dt* (adjust-time dt :hour h :minute m :second s)))
        (collect (next-weekday dt* (car d)))))))

(defun %recur-next-week (dt recur)
  (with-recur-slots recur
    (until-satisfy-conditions (datetime (forward-week dt interval))
      ((belong bymonth (date-month datetime)
               :key (lambda (m)
                      (let ((month (date-month datetime))
                            (year (date-year datetime)))
                        (monthday m month year))))
       (forward-month datetime interval)))))


(defun %recur-list-instances-in-month (dt recur)
  (with-recur-slots recur
    (cond
      ;; If BYMONTHDAY is given, BYDAY rule limits the recur. So, we iterate
      ;; in order to collect the datetimes compatible with the BYMONTHDAY,
      ;; BYHOUR, BYMINUTE and BYSECOND.
      (bymonthday
       (with-collect
         (do-cartesian ((d bymonthday)
                        (h byhour)
                        (m byminute)
                        (s bysecond))
           (let* ((mday (monthday d (date-month dt) (date-year dt)))
                  (dt* (adjust-datetime dt :day mday :hour h :minute m :second s)))
             (if (null byday)
                 (collect dt*)
                 (multiple-value-bind (start end)
                     (interval-limits dt* recur)
                   (when (byday-compatible-p byday dt* start end)
                     (collect dt*))))))))
      ;; If BYMONTHDAY is not present and byday does is, we collect
      ;; compatible datetimes without iterate.
      (byday
       (assert (not bymonthday))
       (with-collect
         (do-cartesian ((d byday)
                        (h byhour)
                        (m byminute)
                        (s bysecond))
           (multiple-value-bind (start end)
               (interval-limits dt recur)
             (let* ((weekday (car d))
                    (nweekday (cdr d))
                    (first-day (next-weekday start weekday))
                    (last-day (previous-weekday end weekday))
                    (total-weeks (1+ (weeks-between first-day last-day)))
                    (adjusted (adjust-time first-day :hour h :minute m :second s)))
               ;; We collect the computed datetime if NWEEKDAY is
               ;; non-nil. Otherwise, we collect datetimes which matches
               ;; with weekday.
               (if nweekday
                   (let ((days (* 7 (1- (mod* nweekday total-weeks)))))
                     (collect (forward-day adjusted days)))
                   (dotimes (i total-weeks)
                     (collect (forward-day adjusted (* i 7)))))))))))))

(defun %recur-next-month (dt recur)
  (with-recur-slots recur
    (do ((delta interval (+ delta interval))
         (datetime (forward-month dt interval)
                   (forward-month datetime interval)))
        ((or (null bymonth)
             (>= delta (lcm 12 interval))
             (find (date-month datetime) bymonth))
         (if (<= delta (lcm 12 interval))
             datetime
             nil)))))

(defun %recur-list-instances-in-year (datetime recur)
  (with-recur-slots recur
    ;; The local function compatible-p checks if a datetime DT is compatible
    ;; with some BY* rules. This does not check all BY* rules, because we can
    ;; make sure some rules will be verified.
    (flet ((compatible-p (dt)
             (and
              (belong bymonth (date-month dt))
              (belong byweekno (week-of-year dt (recur-wkst recur)))
              (belong byyearday (day-of-year dt)
                      :key (lambda (n) (yearday n (date-year dt))))
              (belong bymonthday (date-day dt)
                      :key (lambda (n)
                             (monthday n (date-month dt) (date-year dt))))
              (implyp byday
                      (if bymonth
                          (let ((start (beginning-of-month dt))
                                (end (end-of-month dt)))
                            (byday-compatible-p byday dt start end))
                          (multiple-value-bind (start end)
                              (interval-limits dt recur)
                            (byday-compatible-p byday dt start end)))))))
      (cond
        ;; If one of BYMONTH or BYMONTHDAY is given, then we iterate across
        ;; all dates which match with this description. We must check it is
        ;; compatible with the rest of the BY* rules.
        ((or bymonth bymonthday)
         (with-collect
           (do-cartesian ((month (or bymonth (range 1 12)))
                          (day (or bymonthday (range 1 (monthday -1 month (date-year datetime)))))
                          (hour byhour)
                          (minute byminute)
                          (second bysecond))
             (let ((dt* (encode-universal-time second minute hour day month (date-year datetime))))
               (when (compatible-p dt*)
                 (collect dt*))))))
        ;; In this point, not BYMONTH or BYMONTHDAY rule is present. If a
        ;; BYYEARDAY is present, then we can iterate across them.
        (byyearday
         (with-collect
             (let ((first (beginning-of-year datetime)))
               (dolist (yday byyearday)
                 (let ((dt* (forward-day first (1- (yearday yday (date-year first))))))
                   (when (compatible-p dt*)
                     (collect dt*)))))))
        ;; We have considered the BYMONTH rule previosly, so, the offset of
        ;; BYDAY rule here is considered relative to the year.
        (byday
         (assert (not bymonth))
         (with-collect
             (dolist (rule byday)
               (multiple-value-bind (start end)
                   (interval-limits datetime recur)
                 (let* ((weekday (car rule))
                        (n (cdr rule))
                        (first (next-weekday start weekday))
                        (last (previous-weekday end weekday)))
                   (cond
                     ((null n)
                      (dotimes (i (weeks-between first last))
                        (let ((dt* (forward-day first (* 7 (1+ i)))))
                          (when (compatible-p dt*)
                            (collect dt*)))))
                     ((< n 0)
                      (collect (backward-day last (* 7 (1+ (abs n))))))
                     ((> n 0)
                      (collect (forward-day first (* 7 (1- n)))))))))))
        (t
         ;; Note that some of BYDAY, BYYEARDAY or BYMONTHDAY/BYMONTH rules
         ;; should be specified. In other case, %complete-recur should add a
         ;; BYDAY or BYMONTHDAY/BYMONTH rule.
         nil)))))

(defun %recur-next-year (dt recur)
  ;; RECUR objects with FREQ set to YEARLY has not limitation rules, so we add
  ;; INTERVAL years to DT simply.
  (let ((year (date-year dt)))
    (adjust-date dt :year (+ year (recur-interval recur)))))


(defstruct recur-iterator
  dtstart
  recur
  (count 0)
  interval
  instances)

(defun filter-bysetpos (list bysetpos)
  (if (null bysetpos)
      list
      (loop with length = (length list)
            for index from 1
            for x in list
            when (belong bysetpos index :key (lambda (m) (mod* m length)))
            collect x)))

(defun clean-instances (list)
  (delete-duplicates (sort list #'<)))

(defun recur-iterator-new (recur datetime)
  (let ((recur (%complete-recur recur datetime)))
    (let* ((first-instances
            (case (recur-freq recur)
              (:secondly
               (%recur-list-instances-in-second datetime recur))
              (:minutely
               (%recur-list-instances-in-minute datetime recur))
              (:hourly
               (%recur-list-instances-in-hour datetime recur))
              (:daily
               (%recur-list-instances-in-day datetime recur))
              (:weekly
               (%recur-list-instances-in-week datetime recur))
              (:monthly
               (%recur-list-instances-in-month datetime recur))
              (:yearly
               (%recur-list-instances-in-year datetime recur))))
           (post-instances
            (remove-if (curry #'> datetime) first-instances))
           (final-instances
            (filter-bysetpos (clean-instances post-instances)
                             (recur-bysetpos recur))))
      ;; Return the iterator
      (make-recur-iterator :dtstart datetime :interval datetime
                           :recur recur :instances final-instances))))


(defun recur-iterator-next (iter)
  (let ((datetime (recur-iterator-interval iter))
        (recur (recur-iterator-recur iter)))
    (cond
      ;; If COUNT rule is not verified, return NIL.
      ((and (recur-count recur)
            (>= (recur-iterator-count iter) (recur-count recur)))
       nil)
      ;; If UNTIL rule is not verified
      ((and (recur-until recur)
            (recur-iterator-instances iter)
            (< (recur-until recur)
               (first (recur-iterator-instances iter))))
       nil)
      ;; If there is pending instances, return and increment the counter.
      ((recur-iterator-instances iter)
       (incf (recur-iterator-count iter))
       (pop (recur-iterator-instances iter)))
      (t
       ;; Otherwise, we request more instances.
       (case (recur-freq recur)
         (:secondly
          (setf datetime (%recur-next-second datetime recur))
          (setf (recur-iterator-instances iter)
                (%recur-list-instances-in-second datetime recur)))
         (:minutely
          (setf datetime (%recur-next-minute datetime recur))
          (setf (recur-iterator-instances iter)
                (%recur-list-instances-in-minute datetime recur)))
         (:hourly
          (setf datetime (%recur-next-hour datetime recur))
          (setf (recur-iterator-instances iter)
                (%recur-list-instances-in-hour datetime recur)))
         (:daily
          (setf datetime (%recur-next-day datetime recur))
          (setf (recur-iterator-instances iter)
                (%recur-list-instances-in-day datetime recur)))
         (:weekly
          (setf datetime (%recur-next-week datetime recur))
          (setf (recur-iterator-instances iter)
                (%recur-list-instances-in-week datetime recur)))
         (:monthly
          (setf datetime (%recur-next-month datetime recur))
          (setf (recur-iterator-instances iter)
                (%recur-list-instances-in-month datetime recur)))
         (:yearly
          (setf datetime (%recur-next-year datetime recur))
          (setf (recur-iterator-instances iter)
                (%recur-list-instances-in-year datetime recur))))

       ;; ...and apply the BYSETPOS rule finally!
       (setf (recur-iterator-interval iter) datetime)
       (setf (recur-iterator-instances iter)
             (filter-bysetpos (clean-instances (recur-iterator-instances iter))
                              (recur-bysetpos recur)))

       (when (recur-iterator-instances iter)
         (recur-iterator-next iter))))))

(defmacro do-recur-instances ((variable recur dtstart &optional result) &body code)
  (check-type variable symbol)
  (with-gensyms (iterator)
    `(let ((,iterator (recur-iterator-new ,recur ,dtstart)))
       (do ((,variable (recur-iterator-next ,iterator)
                       (recur-iterator-next ,iterator)))
           ((null ,variable)
            ,result)
         ,@code))))

;; Check if DATETIME is a valid ocurrence in RECUR.
(defun recur-instance-p (start recur datetime)
  (unless (%simple-recur-instance-p start recur start)
    (error "The recur and DTSTART must be synchronized."))
  (let ((complete-recur (%complete-recur recur start)))
    (with-recur-slots complete-recur
        (cond
          ((and (null count) (null bysetpos))
           (%simple-recur-instance-p start complete-recur datetime))
          (t
           (do-recur-instances (dt recur start nil)
             (cond
               ((= dt datetime) (return t))
               ((> dt datetime) (return nil)))))))))

;; List the instances of a bound RECUR.
(defun list-recur-instances (start recur)
  (unless (%simple-recur-instance-p start recur start)
    (error "The recur and DTSTART must be synchronized."))
  (let ((complete-recur (%complete-recur recur start)))
    (with-recur-slots complete-recur
      (when (and (not count) (not until))
        (error "This recur is not an unbound recur."))
      (with-collect
        (do-recur-instances (dt recur start nil)
          (collect dt))))))


;;; Parsing and formatting

(defun parse-byday-value (string)
  (multiple-value-bind (n end)
      (parse-integer string :junk-allowed t)
    (if (and (null n) (< 0 end))
        (%parse-error "~a is not a weekday." string)
        (let* ((str (subseq string end)))
          (aif (position str #("MO" "TU" "WE" "TH" "FR" "SA" "SU") :test #'string-ci=)
               (cons (svref *weekday* it) n)
               (%parse-error "~a is not a weekday." str))))))

(defun parse-rule-part (string)
  (declare (string string))
  (let ((eqpos (position #\= string)))
    (when (null eqpos)
      (%parse-error "Bad rule part ~a" string))
    (cons (subseq string 0 eqpos)
          (subseq string (1+ eqpos)))))

(defun parse-rules (string)
  (declare (string string))
  (let ((parts (split-string string ";" nil)))
    (when (some #'null parts)
      (%parse-error "Empty rule part in the recurrence '~a'." string))
    (mapcar #'parse-rule-part parts)))

(defmethod parse-value (string (type (eql 'recur)) &optional params)
  (declare (string string) (ignore params))
  (let ((rules (parse-rules string))
        (recur (make-instance 'recur)))
    (when (duplicatep rules :key #'car :test #'string-ci=)
      (%parse-error "Duplicate key in recurrence."))
    (flet ((parse-integer-list (x)
             (mapcar #'parse-integer (split-string x ",")))
           (parse-unsigned-integer-list (x)
             (mapcar #'parse-unsigned-integer (split-string x ","))))

      (dolist (rule rules)
        (destructuring-bind (key . value)
            rule
          (cond
            ((string-ci= key "FREQ")
             (setf (slot-value recur 'freq)
                   (or (cdr (assoc value *frequency-table* :test #'string-ci=))
                       (%parse-error "'~a' is not a valid value for the FREQ rule." value))))

            ((string-ci= key "UNTIL")
             (setf (slot-value recur 'until)
                   (handler-case
                       (parse-value value 'datetime)
                     (icalendar-parse-error ()
                       (parse-value value 'date)))))

            ((string-ci= key "COUNT")
             (setf (slot-value recur 'count)
                   (parse-unsigned-integer value)))

            ((string-ci= key "INTERVAL")
             (setf (slot-value recur 'interval)
                   (parse-unsigned-integer value)))

            ((string-ci= key "BYSECOND")
             (setf (slot-value recur 'bysecond)
                   (sort (parse-unsigned-integer-list value) #'<)))

            ((string-ci= key "BYMINUTE")
             (setf (slot-value recur 'byminute)
                   (sort (parse-unsigned-integer-list value) #'<)))

            ((string-ci= key "BYHOUR")
             (setf (slot-value recur 'byhour)
                   (sort (parse-unsigned-integer-list value) #'<)))

            ((string-ci= key "BYDAY")
             (setf (slot-value recur 'byday)
                   (mapcar #'parse-byday-value (split-string value ","))))

            ((string-ci= key "BYMONTH")
             (setf (slot-value recur 'bymonth)
                   (sort (parse-integer-list value) #'<)))

            ((string-ci= key "BYMONTHDAY")
             (setf (slot-value recur 'bymonthday)
                   (parse-integer-list value)))

            ((string-ci= key "BYYEARDAY")
             (setf (slot-value recur 'byyearday)
                   (parse-integer-list value)))

            ((string-ci= key "BYWEEKNO")
             (setf (slot-value recur 'byweekno)
                   (parse-integer-list value)))

            ((string-ci= key "BYSETPOS")
             (setf (slot-value recur 'bysetpos)
                   (sort (parse-integer-list value) #'<)))

            ((string-ci= key "WKST")
             (setf (slot-value recur 'wkst)
                   (let ((nday (position value *weekday-names* :test #'string-ci=)))
                     (when (null nday)
                       (%parse-error "~a is not a weekday." value))
                     (svref *weekday* nday))))
            (t
             (%parse-error "Unknown recurrence component ~a" key)))))

      ;; Return the recur instance
      (check-recur-consistency recur)
      recur)))


(defmethod format-value ((recur recur) (type (eql 'recur)) &optional params)
  (declare (ignore params))
  (with-recur-slots recur
    (with-output-to-string (s)
      (format s "FREQ=~a" (car (rassoc freq *frequency-table*)))
      ;; Print optional recur slots.
      (format s "~[~;~;~:;;INTERVAL=~:*~d~]" interval)
      (format s "~@[;COUNT=~a~]" count)
      (format s "~:[~;;UNTIL=~:*~a~]" (and until (format-value until 'datetime)))
      (format s "~@[;BYSECOND=~{~A~^,~}~]" bysecond)
      (format s "~@[;BYMINUTE=~{~A~^,~}~]" byminute)
      (format s "~@[;BYHOUR=~{~A~^,~}~]" byhour)
      (format s "~@[;BYDAY=~{~@[~d~]~a~^,~}~]"
              (with-collect
                (dolist (day byday)
                  (destructuring-bind (wday . n) day
                    (collect n)
                    (collect (svref *weekday-names* (position wday *weekday*)))))))
      (format s "~@[;BYMONTH=~{~A~^,~}~]" bymonth)
      (format s "~@[;BYMONTHDAY=~{~A~^,~}~]" bymonthday)
      (format s "~@[;BYYEARDAY=~{~A~^,~}~]" byyearday)
      (format s "~@[;BYWEEKNO=~{~A~^,~}~]" byweekno)
      (format s "~@[;BYSETPOS=~{~A~^,~}~]" bysetpos)
      (unless (eq wkst :monday)
        (let ((nwkst (position (recur-wkst recur) *weekday*)))
          (format s ";WKST=~a" (svref *weekday-names* nwkst)))))))


;;; Local variables:
;;; fill-column: 78
;;; indent-tabs-mode: nil
;;; End:

;;; types-recur.lisp ends here

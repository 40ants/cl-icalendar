;;                                                               -*- Lisp -*-
;; cl-icalendar-tests.asd --
;;
;; Copyright (C) 2010 David Vazquez
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
;;

(defclass test-file (static-file)
  nil)

(defsystem :cl-icalendar-tests
  :name "iCalendar library tests"
  :license "GPLv3+"
  :depends-on (:cl-icalendar :fiveam)
  :serial t
  :components
  ((:module "tests"
            :serial t
            :components
            ((:test-file "test-types.001")
             (:test-file "test-icalendar.001")
             (:test-file "test-icalendar.002")
             (:test-file "test-icalendar.003")
             (:test-file "test-icalendar.004")
             (:test-file "test-icalendar.005")
             (:test-file "test-icalendar.006")
             (:file "package")
             (:file "tsuite")
             (:file "test-types")
             (:file "test-types-date")
             (:file "test-types-recur")))))


(defmethod perform ((op test-op) (c (eql (find-system :cl-icalendar-tests))))
  (funcall (intern "RUN-TESTS" (find-package :cl-icalendar-tests))))


;;; cl-icalendar-tests.asd ends here
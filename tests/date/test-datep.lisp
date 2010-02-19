;; test-make-date.lisp
;;
;; Copyrigth (C) 2010 David Vázquez
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

(in-package :cl-icalendar-tests)

(in-suite icalendar-types)

(test datep-001
  "Check `make-date' returns a date type."
  (is (datep (make-date 26 07 1989)))
  (is (datep (make-date 01 01 1970)))
  (is (datep (make-date 01 01 1900))))

(test datep-002
  "Check others objects are not date type."
  (is (not (datep 0)))
  (is (not (datep 'today)))
  (is (not (datep "yesterday")))
  (is (not (datep '(1 . 2))))
  (is (not (datep #(0 1 2 3 4)))))

;;; test-make-date.lisp ends here

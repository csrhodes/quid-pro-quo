(defpackage dbc-test
  (:use #:dbc #:cl #:fiveam)
  (:export #:test-dbc))

(in-package #:dbc-test)

(def-suite tests)

(in-suite tests)

(defgeneric test-dbc (arg1 arg2)
  (:method-combination contract :invariant-check nil)

  (:method :precondition "first arg > 123" ((m fixnum) (n integer))
    (> m 123))
  (:method :precondition "second arg < 100" ((m integer) (n fixnum))
    (< n 100))
  (:method :precondition "first arg = 12345678900987654321"
           ((m integer) (n integer))
    (= m 12345678900987654321))

  (:method :around ((m integer) (n integer))
    (call-next-method))
  (:method :before ((m integer) (n integer))
    (list (- m 1) (- n 1)))
  (:method ((m integer) (n integer))
    (list m n))
  (:method :after ((m integer) (n integer))
    (list (+ m 1) (+ n 1)))

  (:method :postcondition "999" ((m integer) (n fixnum))
    999)
  (:method :postcondition "always true" ((m integer) (n integer))
    t))

(test should-warn-overly-strict-precondition
  (signals overly-strict-precondition-warning
    (test-dbc 12345678900987654321 100)))

(test should-succeed-with-integers
  (is (equal (list 124 2) (test-dbc 124 2))))

(test should-fail-n-<-100-precondition
  (signals precondition-error
    (test-dbc 1 12345678900987654321)))

(defclass foo () 
  ((my-slot :accessor my-slot :initform nil)
   (your-slot :accessor your-slot :initform t))
  (:metaclass contracted-class)
  (:invariants (lambda (instance) 
                 (declare (ignore instance))
                 t)))

(defclass bar (foo) 
  ((yet-another-slot :accessor yet-another-slot :initform 'yas))
  (:metaclass contracted-class)
  (:invariants (lambda (instance)
                 (declare (ignore instance))
                 t)))

(defmethod my-slot :precondition ((bar bar))
  t)

(defmethod my-slot :postcondition ((bar bar))
  t)

(defclass bar-2 (foo)
  ()
  (:metaclass contracted-class)
  (:invariants (lambda (instance)
                 (declare (ignore instance))
                 t)))

#| Example:

(let* ((my-foo (make-instance 'foo))
       (a-slot (progn (format t " !! Accessing my-slot.~%")
		      (my-slot my-foo))))
  (setf (my-slot my-foo) (progn (format t " !! Setting my-slot.~%")
				9999))
  (list (my-slot my-foo) a-slot (your-slot my-foo)))

(let* ((my-bar (make-instance 'bar))
       (a-slot (progn (format t " !! Accessing my-slot.~%")
		      (my-slot my-bar))))
  (setf (my-slot my-bar) (progn (format t " !! Setting my-slot.~%")
				9999))
  (list (my-slot my-bar) a-slot (your-slot my-bar)))

(let* ((my-bar-2 (make-instance 'bar-2))
       (a-slot (progn (format t " !! Accessing my-slot.~%")
		      (my-slot my-bar-2))))
  (setf (my-slot my-bar-2) (progn (format t " !! Setting my-slot.~%")
				9999))
  (list (my-slot my-bar-2) a-slot (your-slot my-bar-2)))

(my-slot (make-instance 'bar))
(yet-another-slot (make-instance 'bar))

(my-slot (make-instance 'bar-2))

|#

(defclass test-1 () 
  ((my-slot :accessor my-slot :initarg :my-slot :initform 0))
  (:metaclass contracted-class)
  (:invariants (lambda (instance)
                 "Invariant of test"
                 (numberp (slot-value instance 'my-slot)))))

(defclass test-2 (test-1)
  ((another-slot :accessor another-slot :initarg :another-slot
		 :initform nil))
  (:metaclass contracted-class)
  (:invariants (lambda (instance)
                 "Test-2 invariant"
                 (< (length (slot-value instance 'another-slot))
                    4))))

(test should-fail-on-invariant-of-superclass
  (signals after-invariant-error
    (setf (my-slot (make-instance 'test-2)) nil)))

(defmethod test-dbc :precondition "first arg < 123" ((m test-2) (n test-1))
  (< (my-slot m) 123))
(defmethod test-dbc :precondition "second arg needs null another-slot"
                    ((m test-1) (n test-2))
  (null (another-slot n)))
(defmethod test-dbc :precondition "first arg needs non-zero my-slot"
                    ((m test-1) (n test-1))
  (not (zerop (my-slot m))))

(defmethod test-dbc :around ((m test-1) (n test-1))
  (call-next-method))
(defmethod test-dbc :before ((m test-1) (n test-1))
  (list m n 'before))
(defmethod test-dbc ((m test-1) (n test-1))
  (list m n))
(defmethod test-dbc :after ((m test-1) (n test-1))
  (list m n 'after))

(defmethod test-dbc :postcondition ((m test-1) (n test-2))
  (null (another-slot n)))
(defmethod test-dbc :postcondition ((m test-1) (n test-1))
  (or (zerop (my-slot m)) (zerop (my-slot n))))

(defmethod fail-invariant ((m test-1))
  (setf (my-slot m) nil))

(test should-succeed-with-test-objects
  (let ((first (make-instance 'test-1 :my-slot 1))
        (second (make-instance 'test-1)))
    (is (equal (list first second) (test-dbc first second)))))

(test should-fail-not-zerop-my-slot-precondition
  (let ((first (make-instance 'test-1))
        (second (make-instance 'test-1)))
    (signals precondition-error
      (test-dbc first second))))

(test should-pass-with-weakened-precondition
  (let ((first (make-instance 'test-2))
        (second (make-instance 'test-1)))
    ;; This succeeds because the method TEST-DBC has a weakened precondition for
    ;; first arguments of type TEST-2.
    (is (equal (list first second) (test-dbc first second)))))

(test should-fail-zerop-my-slot-postcondition
  (let ((first (make-instance 'test-1 :my-slot 1))
        (second (make-instance 'test-1 :my-slot 1)))
    (signals postcondition-error
      (test-dbc first second))))

(test should-fail-with-weakened-postcondition
  (let ((first (make-instance 'test-1 :my-slot 1))
        (second (make-instance 'test-2 :my-slot 1)))
    ;; The weakened postcondition for second argument of class TEST-2 does not
    ;; cause the method to succeed.
    (signals postcondition-error
      (test-dbc first second))))

(test should-create-successfully
  (is (typep (make-instance 'test-1 :my-slot -1)
             'test-1)))

(test should-fail-invariant-at-creation
  (signals creation-invariant-error
    (make-instance 'test-1 :my-slot nil)))

(test should-fail-invariant-after-method-call
  (signals after-invariant-error
    (fail-invariant (make-instance 'test-1))))

;; FIXME: this is an expected failure
(test should-fail-invariant-after-setting-slot-value
  (signals after-invariant-error
    (setf (slot-value (make-instance 'test-1) 'my-slot) nil)))

(defclass non-dbc-superclass ()
  ((foo :initform 10 :initarg :foo :accessor foo)))

(defclass dbc-subclass (non-dbc-superclass)
  ()
  (:metaclass contracted-class)
  (:invariants (lambda (instance)
                 (> (slot-value instance 'foo) 5))))

(test should-fail-invariant-on-subclass-creation
  (signals creation-invariant-error
    (make-instance 'dbc-subclass :foo 5)))

(test should-fail-invariant-on-superclass-writer
  (let ((instance (make-instance 'dbc-subclass)))
    (signals after-invariant-error
      (setf (foo instance) 5))))

#| FIXME: currently this results in a stack overflow
(defclass inv-class ()
  ((foo :initform 10 :initarg :foo :accessor foo))
  (:metaclass contracted-class)
  (:invariants (lambda (instance)
                 (> (foo instance) 5))))

(test should-not-recurse-on-reader-in-invariant
  (is (typep (make-instance 'inv-class) 'inv-class)))
|#

;;; This next section uses a bunch of features without much rigor, just to make
;;; sure everything seems to work.

(defclass feature-test ()
  ((slot1 :accessor slot1 :initarg :slot1 :initform 0))
  (:metaclass contracted-class)
  (:invariants (lambda (instance) 
                 (numberp (slot-value instance 'slot1)))))

(defgeneric test-dbc-/ (arg1 arg2)
  (:method-combination contract :invariant-check nil)
  (:method :precondition "first arg zero" ((m feature-test) (n feature-test))
    (not (zerop (slot1 m))))
  (:method ((m feature-test) (n feature-test))
    (/ (slot1 n) (slot1 m))))

(test should-fail-not-zerop-precondition
  (signals precondition-error
    (test-dbc-/ (make-instance 'feature-test) (make-instance 'feature-test))))

(test should-succeed-and-divide
  (is (= 4
         (test-dbc-/ (make-instance 'feature-test :slot1 2)
                     (make-instance 'feature-test :slot1 8)))))

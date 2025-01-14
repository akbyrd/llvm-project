; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 2
; RUN: llc -mtriple=x86_64-- < %s | FileCheck %s

; FIXME: This is a miscompile.
; It's not possible to directly or the two loads together, because this might
; propagate a poison value from the second load (which has !range but not
; !noundef).
define i8 @test(ptr %p) {
; CHECK-LABEL: test:
; CHECK:       # %bb.0:
; CHECK-NEXT:    movzbl (%rdi), %eax
; CHECK-NEXT:    orb 1(%rdi), %al
; CHECK-NEXT:    addb %al, %al
; CHECK-NEXT:    retq
  %v1 = load i8, ptr %p, align 4, !range !0, !noundef !{}
  %cmp1 = icmp ne i8 %v1, 0
  %p2 = getelementptr inbounds i8, ptr %p, i64 1
  %v2 = load i8, ptr %p2, align 1, !range !0
  %cmp2 = icmp ne i8 %v2, 0
  %or = select i1 %cmp1, i1 true, i1 %cmp2
  %res = select i1 %or, i8 2, i8 0
  ret i8 %res
}

!0 = !{i8 0, i8 2}

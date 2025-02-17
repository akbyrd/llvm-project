// RUN: %clang_cc1 -fexperimental-new-constant-interpreter %s -verify
// RUN: %clang_cc1 -verify=ref %s -Wno-constant-evaluated
// RUN: %clang_cc1 -std=c++20 -fexperimental-new-constant-interpreter %s -verify
// RUN: %clang_cc1 -std=c++20 -verify=ref %s -Wno-constant-evaluated


namespace strcmp {
  constexpr char kFoobar[6] = {'f','o','o','b','a','r'};
  constexpr char kFoobazfoobar[12] = {'f','o','o','b','a','z','f','o','o','b','a','r'};

  static_assert(__builtin_strcmp("", "") == 0, "");
  static_assert(__builtin_strcmp("abab", "abab") == 0, "");
  static_assert(__builtin_strcmp("abab", "abba") == -1, "");
  static_assert(__builtin_strcmp("abab", "abaa") == 1, "");
  static_assert(__builtin_strcmp("ababa", "abab") == 1, "");
  static_assert(__builtin_strcmp("abab", "ababa") == -1, "");
  static_assert(__builtin_strcmp("a\203", "a") == 1, "");
  static_assert(__builtin_strcmp("a\203", "a\003") == 1, "");
  static_assert(__builtin_strcmp("abab\0banana", "abab") == 0, "");
  static_assert(__builtin_strcmp("abab", "abab\0banana") == 0, "");
  static_assert(__builtin_strcmp("abab\0banana", "abab\0canada") == 0, "");
  static_assert(__builtin_strcmp(0, "abab") == 0, ""); // expected-error {{not an integral constant}} \
                                                       // expected-note {{dereferenced null}} \
                                                       // expected-note {{in call to}} \
                                                       // ref-error {{not an integral constant}} \
                                                       // ref-note {{dereferenced null}}
  static_assert(__builtin_strcmp("abab", 0) == 0, ""); // expected-error {{not an integral constant}} \
                                                       // expected-note {{dereferenced null}} \
                                                       // expected-note {{in call to}} \
                                                       // ref-error {{not an integral constant}} \
                                                       // ref-note {{dereferenced null}}

  static_assert(__builtin_strcmp(kFoobar, kFoobazfoobar) == -1, "");
  static_assert(__builtin_strcmp(kFoobar, kFoobazfoobar + 6) == 0, ""); // expected-error {{not an integral constant}} \
                                                                        // expected-note {{dereferenced one-past-the-end}} \
                                                                        // expected-note {{in call to}} \
                                                                        // ref-error {{not an integral constant}} \
                                                                        // ref-note {{dereferenced one-past-the-end}}
}

namespace nan {
  constexpr double NaN1 = __builtin_nan("");

  /// The current interpreter does not accept this, but it should.
  constexpr float NaN2 = __builtin_nans([](){return "0xAE98";}()); // ref-error {{must be initialized by a constant expression}}
#if __cplusplus < 201703L
  // expected-error@-2 {{must be initialized by a constant expression}}
#endif

  constexpr double NaN3 = __builtin_nan("foo"); // expected-error {{must be initialized by a constant expression}} \
                                                // ref-error {{must be initialized by a constant expression}}
  constexpr float NaN4 = __builtin_nanf("");
  //constexpr long double NaN5 = __builtin_nanf128("");

  /// FIXME: This should be accepted by the current interpreter as well.
  constexpr char f[] = {'0', 'x', 'A', 'E', '\0'};
  constexpr double NaN6 = __builtin_nan(f); // ref-error {{must be initialized by a constant expression}}

  /// FIXME: Current interpreter misses diagnostics.
  constexpr char f2[] = {'0', 'x', 'A', 'E'}; /// No trailing 0 byte.
  constexpr double NaN7 = __builtin_nan(f2); // ref-error {{must be initialized by a constant expression}} \
                                             // expected-error {{must be initialized by a constant expression}} \
                                             // expected-note {{read of dereferenced one-past-the-end pointer}} \
                                             // expected-note {{in call to}}
}

namespace fmin {
  constexpr float f1 = __builtin_fmin(1.0, 2.0f);
  static_assert(f1 == 1.0f, "");

  constexpr float min = __builtin_fmin(__builtin_nan(""), 1);
  static_assert(min == 1, "");
  constexpr float min2 = __builtin_fmin(1, __builtin_nan(""));
  static_assert(min2 == 1, "");
  constexpr float min3 = __builtin_fmin(__builtin_inf(), __builtin_nan(""));
  static_assert(min3 == __builtin_inf(), "");
}

namespace inf {
  static_assert(__builtin_isinf(__builtin_inf()), "");
  static_assert(!__builtin_isinf(1.0), "");

  static_assert(__builtin_isfinite(1.0), "");
  static_assert(!__builtin_isfinite(__builtin_inf()), "");

  static_assert(__builtin_isnormal(1.0), "");
  static_assert(!__builtin_isnormal(__builtin_inf()), "");
}

namespace isfpclass {
  char isfpclass_inf_pos_0[__builtin_isfpclass(__builtin_inf(), 0x0200) ? 1 : -1]; // fcPosInf
  char isfpclass_inf_pos_1[!__builtin_isfpclass(__builtin_inff(), 0x0004) ? 1 : -1]; // fcNegInf
  char isfpclass_inf_pos_2[__builtin_isfpclass(__builtin_infl(), 0x0207) ? 1 : -1]; // fcSNan|fcQNan|fcNegInf|fcPosInf
  char isfpclass_inf_pos_3[!__builtin_isfpclass(__builtin_inf(), 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_pos_0    [__builtin_isfpclass(1.0, 0x0100) ? 1 : -1]; // fcPosNormal
  char isfpclass_pos_1    [!__builtin_isfpclass(1.0f, 0x0008) ? 1 : -1]; // fcNegNormal
  char isfpclass_pos_2    [__builtin_isfpclass(1.0L, 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_pos_3    [!__builtin_isfpclass(1.0, 0x0003) ? 1 : -1]; // fcSNan|fcQNan
  char isfpclass_pdenorm_0[__builtin_isfpclass(1.0e-40f, 0x0080) ? 1 : -1]; // fcPosSubnormal
  char isfpclass_pdenorm_1[__builtin_isfpclass(1.0e-310, 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_pdenorm_2[!__builtin_isfpclass(1.0e-40f, 0x003C) ? 1 : -1]; // fcNegative
  char isfpclass_pdenorm_3[!__builtin_isfpclass(1.0e-310, 0x0207) ? 1 : -1]; // ~fcFinite
  char isfpclass_pzero_0  [__builtin_isfpclass(0.0f, 0x0060) ? 1 : -1]; // fcZero
  char isfpclass_pzero_1  [__builtin_isfpclass(0.0, 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_pzero_2  [!__builtin_isfpclass(0.0L, 0x0020) ? 1 : -1]; // fcNegZero
  char isfpclass_pzero_3  [!__builtin_isfpclass(0.0, 0x0003) ? 1 : -1]; // fcNan
  char isfpclass_nzero_0  [__builtin_isfpclass(-0.0f, 0x0060) ? 1 : -1]; // fcZero
  char isfpclass_nzero_1  [__builtin_isfpclass(-0.0, 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_nzero_2  [!__builtin_isfpclass(-0.0L, 0x0040) ? 1 : -1]; // fcPosZero
  char isfpclass_nzero_3  [!__builtin_isfpclass(-0.0, 0x0003) ? 1 : -1]; // fcNan
  char isfpclass_ndenorm_0[__builtin_isfpclass(-1.0e-40f, 0x0010) ? 1 : -1]; // fcNegSubnormal
  char isfpclass_ndenorm_1[__builtin_isfpclass(-1.0e-310, 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_ndenorm_2[!__builtin_isfpclass(-1.0e-40f, 0x03C0) ? 1 : -1]; // fcPositive
  char isfpclass_ndenorm_3[!__builtin_isfpclass(-1.0e-310, 0x0207) ? 1 : -1]; // ~fcFinite
  char isfpclass_neg_0    [__builtin_isfpclass(-1.0, 0x0008) ? 1 : -1]; // fcNegNormal
  char isfpclass_neg_1    [!__builtin_isfpclass(-1.0f, 0x00100) ? 1 : -1]; // fcPosNormal
  char isfpclass_neg_2    [__builtin_isfpclass(-1.0L, 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_neg_3    [!__builtin_isfpclass(-1.0, 0x0003) ? 1 : -1]; // fcSNan|fcQNan
  char isfpclass_inf_neg_0[__builtin_isfpclass(-__builtin_inf(), 0x0004) ? 1 : -1]; // fcNegInf
  char isfpclass_inf_neg_1[!__builtin_isfpclass(-__builtin_inff(), 0x0200) ? 1 : -1]; // fcPosInf
  char isfpclass_inf_neg_2[__builtin_isfpclass(-__builtin_infl(), 0x0207) ? 1 : -1]; // ~fcFinite
  char isfpclass_inf_neg_3[!__builtin_isfpclass(-__builtin_inf(), 0x03C0) ? 1 : -1]; // fcPositive
  char isfpclass_qnan_0   [__builtin_isfpclass(__builtin_nan(""), 0x0002) ? 1 : -1]; // fcQNan
  char isfpclass_qnan_1   [!__builtin_isfpclass(__builtin_nanf(""), 0x0001) ? 1 : -1]; // fcSNan
  char isfpclass_qnan_2   [__builtin_isfpclass(__builtin_nanl(""), 0x0207) ? 1 : -1]; // ~fcFinite
  char isfpclass_qnan_3   [!__builtin_isfpclass(__builtin_nan(""), 0x01F8) ? 1 : -1]; // fcFinite
  char isfpclass_snan_0   [__builtin_isfpclass(__builtin_nansf(""), 0x0001) ? 1 : -1]; // fcSNan
  char isfpclass_snan_1   [!__builtin_isfpclass(__builtin_nans(""), 0x0002) ? 1 : -1]; // fcQNan
  char isfpclass_snan_2   [__builtin_isfpclass(__builtin_nansl(""), 0x0207) ? 1 : -1]; // ~fcFinite
  char isfpclass_snan_3   [!__builtin_isfpclass(__builtin_nans(""), 0x01F8) ? 1 : -1]; // fcFinite
}

namespace fpclassify {
  char classify_nan     [__builtin_fpclassify(+1, -1, -1, -1, -1, __builtin_nan(""))];
  char classify_snan    [__builtin_fpclassify(+1, -1, -1, -1, -1, __builtin_nans(""))];
  char classify_inf     [__builtin_fpclassify(-1, +1, -1, -1, -1, __builtin_inf())];
  char classify_neg_inf [__builtin_fpclassify(-1, +1, -1, -1, -1, -__builtin_inf())];
  char classify_normal  [__builtin_fpclassify(-1, -1, +1, -1, -1, 1.539)];
  char classify_normal2 [__builtin_fpclassify(-1, -1, +1, -1, -1, 1e-307)];
  char classify_denorm  [__builtin_fpclassify(-1, -1, -1, +1, -1, 1e-308)];
  char classify_denorm2 [__builtin_fpclassify(-1, -1, -1, +1, -1, -1e-308)];
  char classify_zero    [__builtin_fpclassify(-1, -1, -1, -1, +1, 0.0)];
  char classify_neg_zero[__builtin_fpclassify(-1, -1, -1, -1, +1, -0.0)];
  char classify_subnorm [__builtin_fpclassify(-1, -1, -1, +1, -1, 1.0e-38f)];
}

namespace fabs {
  static_assert(__builtin_fabs(-14.0) == 14.0, "");
}

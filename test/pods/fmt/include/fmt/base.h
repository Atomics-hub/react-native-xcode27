// The consteval switch from fmt 11.0.2's include/fmt/base.h (MIT license, Copyright (c) 2012 -
// present, Victor Zverovich and {fmt} contributors), with the macros it reads defined for clang.
#pragma once
#include <type_traits>

#define FMT_CPLUSPLUS __cplusplus
#define FMT_GLIBCXX_RELEASE 0
#define FMT_LIBCPP_VERSION _LIBCPP_VERSION
#define FMT_MSC_VERSION 0
#define FMT_GCC_VERSION 0
#define FMT_CLANG_VERSION (__clang_major__ * 100 + __clang_minor__)

// Detect consteval, C++20 constexpr extensions and std::is_constant_evaluated.
#if !defined(__cpp_lib_is_constant_evaluated)
#  define FMT_USE_CONSTEVAL 0
#elif FMT_CPLUSPLUS < 201709L
#  define FMT_USE_CONSTEVAL 0
#elif FMT_GLIBCXX_RELEASE && FMT_GLIBCXX_RELEASE < 10
#  define FMT_USE_CONSTEVAL 0
#elif FMT_LIBCPP_VERSION && FMT_LIBCPP_VERSION < 10000
#  define FMT_USE_CONSTEVAL 0
#elif defined(__apple_build_version__) && __apple_build_version__ < 14000029L
#  define FMT_USE_CONSTEVAL 0  // consteval is broken in Apple clang < 14.
#elif FMT_MSC_VERSION && FMT_MSC_VERSION < 1929
#  define FMT_USE_CONSTEVAL 0  // consteval is broken in MSVC VS2019 < 16.10.
#elif defined(__cpp_consteval)
#  define FMT_USE_CONSTEVAL 1
#elif FMT_GCC_VERSION >= 1002 || FMT_CLANG_VERSION >= 1101
#  define FMT_USE_CONSTEVAL 1
#else
#  define FMT_USE_CONSTEVAL 0
#endif

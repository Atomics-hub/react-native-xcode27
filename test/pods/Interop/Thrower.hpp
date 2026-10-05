#pragma once
#include <exception>
#include <stdexcept>
#include <string>

namespace interop {
// The same shape as react-native-nitro-modules' makeException in ios/utils/RuntimeError.hpp.
static inline std::exception_ptr makeError(const std::string& message) {
  return std::make_exception_ptr(std::runtime_error(message));
}
}

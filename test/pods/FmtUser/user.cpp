#include <fmt/base.h>

// fmt 11's consteval format strings fail to compile with the Apple Clang in Xcode 26.4 and later.
#if FMT_USE_CONSTEVAL
#error "fmt 11 uses consteval here"
#endif

int fmt_user() { return 0; }

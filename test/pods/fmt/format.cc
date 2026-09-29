// A u8 literal is a const char array in C++17 and a const char8_t array in C++20, so this line
// compiles only below C++20, the way fmt 11's consteval format strings fail in Xcode 26.4 and later.
const char *fmt_stand_in = u8"fmt";

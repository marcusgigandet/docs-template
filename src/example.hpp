// Example module. Replace src/ with your project's sources: Doxygen
// (INPUT in Doxyfile) consumes them, and Exhale regenerates the C++
// reference under docs/api/ from the resulting XML on every build.

namespace example {

/// Adds two integers.
///
/// Sample documented function: shows up in the generated C++ reference
/// once Doxygen runs over src/ (`make pages` does this automatically).
int add(int a, int b);

}  // namespace example

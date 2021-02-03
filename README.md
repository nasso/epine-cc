# epine-cc

[Epine] module for C/C++ projects using the GNU Compiler Collection or
compatible compilers.

## Example usage

```lua
local cc = require "@nasso/epine-cc/v0.2.0-alpha"

return {
    -- supported target types: cc.binary, cc.static
    -- planned: cc.shared
    cc.binary "MyGKrellm" {
        -- target prerequisites
        prerequisites = {"./lib/libjzon.a"},
        -- language ("C" (default) or "C++")
        lang = "C++",
        -- source files
        srcs = {find "./src/*.cpp"},
        -- preprocessor flags (include dirs)
        cppflags = {"-I./include", "-I./lib/libjzon/include"},
        -- compiler flags
        cxxflags = {"-Wall", "-Wextra"},
        -- libraries
        ldlibs = {
            "-lsfml-graphics",
            "-lsfml-window",
            "-lsfml-system",
            "-ljzon"
        },
        -- lib dirs and other linker flags
        ldflags = {"-L./lib"}
    },

    -- [...]

    action "clean" {
        -- cc.cleanlist represents all the files generated during compilation
        -- it does NOT contain the final executable or library
        rm(cc.cleanlist)
    }
}
```

[Epine]: https://github.com/nasso/epine

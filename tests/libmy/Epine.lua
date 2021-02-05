local cc = require "../../init"

cc.quiet = true

function cc.oncompile(dst, src, lang)
    return echo("[" .. lang .. "] " .. src .. " '->' " .. dst)
end

function cc.onlink(dst, src, type)
    return echo("[" .. type .. "] " .. src .. " '->' " .. dst)
end

local libmy_cfg = {
    srcs = {"./src/my_putstr.c", "./src/my_printf.c"},
    cppflags = {
        "-Iinclude",
        {
            "-DMY_ALLOW_MALLOC",
            "-DMY_ALLOW_FREE",
            "-DMY_FAKE_MALLOC_FAILURE=16"
        }
    },
    cflags = {
        "-Wall",
        "-Wextra",
        "-pedantic"
    },
    ldlibs = {{}, {}}
}

return {
    epine.var("CFLAGS", "-g3"),
    epine.br,
    action "all" {
        prerequisites = {"libmy.a"}
    },
    epine.br,
    cc.static("libmy.a")(libmy_cfg),
    epine.br,
    cc.shared("libmy.so")(libmy_cfg),
    epine.br,
    cc.binary "unit_tests" {
        prerequisites = {"libmy.a"},
        srcs = {"tests/test.c"},
        cppflags = {"-Iinclude", "-DMY_TESTS"},
        ldlibs = {"-lmy", "-lcriterion"},
        ldflags = {"-L."}
    },
    epine.br,
    cc.override_implicits(),
    epine.br,
    action "tests_run" {
        prerequisites = {"unit_tests"},
        "./unit_tests"
    },
    epine.br,
    action "clean" {
        quiet(rm(cc.cleanlist))
    },
    epine.br,
    action "fclean" {
        quiet(rm(cc.cleanlist)),
        quiet(rm("libmy.a", "libmy.so", "unit_tests"))
    },
    epine.br,
    action "re" {
        prerequisites = {"fclean", "all"}
    }
}

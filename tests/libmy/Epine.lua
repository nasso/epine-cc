local cc = require "../../init"

local libmy_cfg = {
    srcs = {"./src/my_putstr.c", "./src/my_printf.c"},
    cppflags = {
        "-Iinclude",
        "-DMY_ALLOW_MALLOC",
        "-DMY_ALLOW_FREE",
        "-DMY_FAKE_MALLOC_FAILURE=16"
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
        cppflags = {"-Iinclude"},
        ldlibs = {"-lmy", "-lcriterion"},
        ldflags = {"-L."}
    },
    epine.br,
    action "tests_run" {
        prerequisites = {"unit_tests"},
        "./unit_tests"
    },
    epine.br,
    action "clean" {
        rm(cc.cleanlist)
    },
    epine.br,
    action "fclean" {
        rm(cc.cleanlist),
        rm("libmy.a", "unit_tests")
    },
    epine.br,
    action "re" {
        prerequisites = {"fclean", "all"}
    }
}

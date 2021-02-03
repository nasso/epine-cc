local function ns(tl, ...)
    local varname = string.gsub(tl, "[^%w]", "_")

    for _, v in ipairs({...}) do
        varname = varname .. "_" .. string.gsub(v, "[^%w]", "_")
    end

    return varname
end

local function multivar(def, varname, ...)
    local mk = {}
    local first = true

    for _, v in ipairs({...}) do
        for _, vv in ipairs(v) do
            if first then
                first = false
                mk[#mk + 1] = def(varname, vv)
            else
                mk[#mk + 1] = epine.append(varname, vv)
            end
        end
    end

    return mk
end

local function nop()
end

---

local CC = {}
CC.__index = CC

CC.mt = {}
CC.mt.__index = CC.mt
setmetatable(CC, CC.mt)

function CC.mt.__call(_)
    local self = setmetatable({}, CC)

    self.quiet = false
    self.oncompile = nop
    self.onlink = nop
    self.cleanlist = {}

    return self
end

function CC:target(name)
    return function(cfg)
        assert(cfg.srcs and #cfg.srcs > 0, '"srcs" must be an array')
        cfg.lang = cfg.lang or "C"
        cfg.cppflags = cfg.cppflags or {}
        cfg.cflags = cfg.cflags or {}
        cfg.cxxflags = cfg.cxxflags or {}
        cfg.ldlibs = cfg.ldlibs or {}
        cfg.ldflags = cfg.ldflags or {}
        cfg.gendeps = cfg.gendeps ~= false

        local vcppflags = ns(name, "CPPFLAGS") -- preprocessor flags
        local vcflags = ns(name, "CFLAGS") -- c compiler flags
        local vcxxflags = ns(name, "CXXFLAGS") -- c++ compiler flags
        local vldlibs = ns(name, "LDLIBS") -- linker libs
        local vldflags = ns(name, "LDFLAGS") -- linker flags
        local vsrcs = ns(name, "SRCS") -- source files
        local vobjs = ns(name, "OBJS") -- object files
        local vdeps = ns(name, "DEPS") -- make dependencies files (*.d)

        -- makefile
        local mk = {}

        if cfg.gendeps then
            mk[#mk + 1] =
                multivar(epine.svar, vcppflags, {"-MD -MP"}, cfg.cppflags)
        else
            mk[#mk + 1] = multivar(epine.svar, vcppflags, cfg.cppflags)
        end

        -- initial variables
        mk[#mk + 1] = {
            multivar(epine.svar, vldlibs, cfg.ldlibs),
            multivar(epine.svar, vldflags, cfg.ldflags),
            epine.svar(vsrcs, fconcat(cfg.srcs))
        }

        -- object files depend on the language!
        if cfg.lang == "C" then
            mk[#mk + 1] = {
                multivar(epine.svar, vcflags, cfg.cflags),
                epine.svar(vobjs, "$(filter %.c," .. vref(vsrcs) .. ")"),
                epine.svar(vobjs, "$(" .. vobjs .. ":.c=.o)")
            }
        elseif cfg.lang == "C++" then
            mk[#mk + 1] = {
                multivar(epine.svar, vcxxflags, cfg.cxxflags),
                epine.svar(vobjs, "$(filter %.cpp," .. vref(vsrcs) .. ")"),
                epine.svar(vobjs, "$(" .. vobjs .. ":.cpp=.o)")
            }
        else
            error("unknown language: " .. cfg.lang)
        end

        if cfg.gendeps then
            mk[#mk + 1] = epine.svar(vdeps, "$(" .. vobjs .. ":.o=.d)")
        end

        -- prerequisites (maybe a library?)
        if cfg.prerequisites then
            mk[#mk + 1] = {
                epine.erule {
                    targets = {name, vref(vobjs)},
                    prerequisites = cfg.prerequisites
                }
            }
        end

        -- maybe quiet
        local function mq(...)
            if self.quiet then
                return quiet(...)
            else
                return ...
            end
        end

        -- rules
        local ld

        if cfg.lang == "C" then
            ld = "$(CC)"
        elseif cfg.lang == "C++" then
            ld = "$(CXX)"
        end

        local link_cmd = {
            ["binary"] = mq(ld .. " -o $@ " .. vref(vobjs, vldflags, vldlibs)),
            ["static-lib"] = mq("$(AR) rc $@ " .. vref(vobjs))
        }

        link_cmd["static"] = link_cmd["static-lib"]
        link_cmd["shared"] = link_cmd["shared-lib"]

        -- the final target
        mk[#mk + 1] = {
            epine.erule {
                targets = {name},
                prerequisites = {vref(vobjs)},
                recipe = {
                    self.onlink("$@"),
                    link_cmd[cfg.type or "binary"]
                }
            }
        }

        -- static pattern rule to make object files
        if cfg.lang == "C" then
            mk[#mk + 1] = {
                epine.sprule {
                    targets = {vref(vobjs)},
                    target_pattern = "%.o",
                    prereq_patterns = {"%.c"},
                    recipe = {
                        self.oncompile("$<", "$@"),
                        mq(
                            "$(CC) " ..
                                vref(vcppflags, vcflags) .. " -c -o $@ $<"
                        )
                    }
                }
            }
        elseif cfg.lang == "C++" then
            mk[#mk + 1] = {
                epine.sprule {
                    targets = {vref(vobjs)},
                    target_pattern = "%.o",
                    prereq_patterns = {"%.cpp"},
                    recipe = {
                        self.oncompile("$<", "$@"),
                        mq(
                            "$(CXX) " ..
                                vref(vcppflags, vcxxflags) .. " -c -o $@ $<"
                        )
                    }
                }
            }
        end

        if cfg.gendeps then
            mk[#mk + 1] = {
                epine.sinclude {vref(vdeps)}
            }

            self.cleanlist[#self.cleanlist + 1] = vref(vdeps)
        end

        self.cleanlist[#self.cleanlist + 1] = vref(vobjs)

        return mk
    end
end

--< shortcut for static library targets >--
function CC:static(name)
    return function(cfg)
        cfg.type = "static-lib"
        return self:target(name)(cfg)
    end
end

--< shortcut for binary targets >--
function CC:binary(name)
    return function(cfg)
        cfg.type = "binary"
        return self:target(name)(cfg)
    end
end

--< a global instance >--
local cc = CC()

--< forward CC:binary >--
function cc.binary(...)
    return CC.binary(cc, ...)
end

--< forward CC:static >--
function cc.static(...)
    return CC.static(cc, ...)
end

--< give a way to create new instances! >--
function cc.new()
    return CC()
end

return cc

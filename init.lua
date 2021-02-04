local function ns(tl, ...)
    local varname = string.gsub(tl, "[^%w]", "_")

    for _, v in ipairs({...}) do
        varname = varname .. "_" .. string.gsub(v, "[^%w]", "_")
    end

    return varname
end

local function targetvars(targets, def, varname, ...)
    local mk = {}
    local first = false

    for _, v in ipairs({...}) do
        for _, vv in ipairs(v) do
            if first then
                first = false
                mk[#mk + 1] = def(varname, vv):targets(targets)
            else
                mk[#mk + 1] = epine.append(varname, vv):targets(targets)
            end
        end
    end

    return mk
end

local function nop()
end

local normalized_types = {
    ["binary"] = "binary",
    ["static"] = "static",
    ["static-lib"] = "static",
    ["shared"] = "shared",
    ["shared-lib"] = "shared"
}

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
        cfg.lang = cfg.lang or "C"
        cfg.cppflags = cfg.cppflags or {}
        cfg.cflags = cfg.cflags or {}
        cfg.cxxflags = cfg.cxxflags or {}
        cfg.ldlibs = cfg.ldlibs or {}
        cfg.ldflags = cfg.ldflags or {}
        cfg.gendeps = cfg.gendeps ~= false
        cfg.type = normalized_types[cfg.type]

        assert(cfg.srcs and #cfg.srcs > 0, '"srcs" must be an array')
        assert(cfg.type, "invalid target type")

        local isshared = cfg.type == "shared"

        local vsrcs = ns(name, "SRCS") -- source files
        local vobjs = ns(name, "OBJS") -- object files
        local vdeps = ns(name, "DEPS") -- make dependencies files (*.d)

        -- makefile
        local mk = {
            -- TARGET_SRCS := ...
            epine.svar(vsrcs, fconcat(cfg.srcs))
        }

        -- object files depend on the language!
        -- TARGET_OBJS := ...
        if cfg.lang == "C" then
            mk[#mk + 1] = {
                epine.svar(vobjs, "$(filter %.c," .. vref(vsrcs) .. ")"),
                epine.svar(vobjs, "$(" .. vobjs .. ":.c=.o)")
            }
        elseif cfg.lang == "C++" then
            mk[#mk + 1] = {
                epine.svar(vobjs, "$(filter %.cpp," .. vref(vsrcs) .. ")"),
                epine.svar(vobjs, "$(" .. vobjs .. ":.cpp=.o)")
            }
        else
            error("unknown language: " .. cfg.lang)
        end

        -- TARGET_DEPS := ...
        if cfg.gendeps then
            mk[#mk + 1] = epine.svar(vdeps, "$(" .. vobjs .. ":.o=.d)")
        end

        -- target specific variables
        local vcppflags = "CPPFLAGS" -- preprocessor flags
        local vcflags = "CFLAGS" -- c compiler flags
        local vcxxflags = "CXXFLAGS" -- c++ compiler flags
        local vldlibs = "LDLIBS" -- linker libs
        local vldflags = "LDFLAGS" -- linker flags

        -- CPPFLAGS
        if cfg.gendeps then
            mk[#mk + 1] =
                targetvars(
                name,
                epine.svar,
                vcppflags,
                {"-MD -MP"},
                cfg.cppflags
            )
        else
            mk[#mk + 1] = targetvars(name, epine.svar, vcppflags, cfg.cppflags)
        end

        -- CFLAGS / CXXFLAGS
        if cfg.lang == "C" then
            mk[#mk + 1] = {
                targetvars(
                    name,
                    epine.svar,
                    vcflags,
                    isshared and "-fPIC" or {},
                    cfg.cflags
                )
            }
        elseif cfg.lang == "C++" then
            mk[#mk + 1] = {
                targetvars(
                    name,
                    epine.svar,
                    vcxxflags,
                    isshared and "-fPIC" or {},
                    cfg.cxxflags
                )
            }
        end

        -- LDLIBS & LDFLAGS
        mk[#mk + 1] = {
            targetvars(name, epine.svar, vldlibs, cfg.ldlibs),
            targetvars(
                name,
                epine.svar,
                vldflags,
                cfg.ldflags,
                isshared and {"-shared"} or {}
            )
        }

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
            ["shared"] = mq(ld .. " -o $@ " .. vref(vobjs, vldflags, vldlibs)),
            ["static"] = mq("$(AR) rc $@ " .. vref(vobjs))
        }

        -- the final target
        mk[#mk + 1] = {
            epine.erule {
                targets = {name},
                prerequisites = {vref(vobjs)},
                recipe = {
                    self.onlink("$@") or {},
                    link_cmd[cfg.type or "binary"]
                }
            }
        }

        -- include for header dependencies
        if cfg.gendeps then
            mk[#mk + 1] = {
                epine.sinclude {vref(vdeps)}
            }

            -- add *.d files to the cleanlist
            self.cleanlist[#self.cleanlist + 1] = vref(vdeps)
        end

        -- add object files (*.o) to the cleanlist
        self.cleanlist[#self.cleanlist + 1] = vref(vobjs)

        return mk
    end
end

--< shortcut for static library targets >--
function CC:static(name)
    return function(cfg)
        cfg.type = "static"
        return self:target(name)(cfg)
    end
end

--< shortcut for shared library targets >--
function CC:shared(name)
    return function(cfg)
        cfg.type = "shared"
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

--< forward CC:shared >--
function cc.shared(...)
    return CC.shared(cc, ...)
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

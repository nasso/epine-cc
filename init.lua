local function ns(tl, ...)
    local varname = string.gsub(tl, "[^%w]", "_")

    for _, v in ipairs({...}) do
        varname = varname .. "_" .. string.gsub(v, "[^%w]", "_")
    end

    return varname
end

local function targetvars(targets, varname, ...)
    local mk = {}

    for _, v in ipairs({...}) do
        if type(v) == "table" then
            mk[#mk + 1] = targetvars(targets, varname, table.unpack(v))
        else
            mk[#mk + 1] = epine.append(varname, v):targets(targets)
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
        local mk = {}

        -- TARGET_SRCS := ...
        mk[#mk + 1] = epine.svar(vsrcs, fconcat(cfg.srcs))

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

        -- prerequisites (maybe a library?)
        if cfg.prerequisites then
            mk[#mk + 1] = {
                epine.erule {
                    targets = {name, vref(vobjs)},
                    prerequisites = cfg.prerequisites
                }
            }
        end

        -- target specific variables
        local vcppflags = "CPPFLAGS" -- preprocessor flags
        local vcflags = "CFLAGS" -- c compiler flags
        local vcxxflags = "CXXFLAGS" -- c++ compiler flags
        local vldlibs = "LDLIBS" -- linker libs
        local vldflags = "LDFLAGS" -- linker flags

        -- force initialize them so we can be sure what their value is
        -- avoids issues where another target was made just before this one
        -- we don't wanna keep the values of the other target!
        mk[#mk + 1] = epine.svar(vcppflags):targets(name)

        -- CPPFLAGS
        if cfg.gendeps then
            mk[#mk + 1] = targetvars(name, vcppflags, {"-MD -MP"}, cfg.cppflags)
        else
            mk[#mk + 1] = targetvars(name, vcppflags, cfg.cppflags)
        end

        -- CFLAGS / CXXFLAGS
        if cfg.lang == "C" then
            mk[#mk + 1] = {
                epine.svar(vcflags):targets(name),
                targetvars(
                    name,
                    vcflags,
                    isshared and "-fPIC" or {},
                    cfg.cflags
                )
            }
        elseif cfg.lang == "C++" then
            mk[#mk + 1] = {
                epine.svar(vcxxflags):targets(name),
                targetvars(
                    name,
                    vcxxflags,
                    isshared and "-fPIC" or {},
                    cfg.cxxflags
                )
            }
        end

        -- static libraries don't link!
        if cfg.type ~= "static" then
            -- LDLIBS & LDFLAGS
            mk[#mk + 1] = {
                epine.svar(vldlibs):targets(name),
                targetvars(name, vldlibs, cfg.ldlibs),
                epine.svar(vldflags):targets(name),
                targetvars(
                    name,
                    vldflags,
                    isshared and "-shared" or {},
                    cfg.ldflags
                )
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
                    self.onlink("$@", "$^", cfg.type) or {},
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

function CC:override_implicits()
    local function mq(...)
        if self.quiet then
            return quiet(...)
        else
            return ...
        end
    end

    return {
        epine.prule {
            patterns = {"%.o"},
            prerequisites = {"%.c"},
            recipe = {
                self.oncompile("$@", "$<", "C") or {},
                mq("$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<")
            }
        },
        epine.prule {
            patterns = {"%.o"},
            prerequisites = {"%.cpp"},
            recipe = {
                self.oncompile("$@", "$<", "C++") or {},
                mq("$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<")
            }
        }
    }
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

--< give a way to create new instances! >--
function cc.new()
    return CC()
end

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

--< forward CC:override_implicits >--
function cc.override_implicits(...)
    return CC.override_implicits(cc, ...)
end

return cc

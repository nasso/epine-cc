local function ns(...)
    local varname = "EPINE_CC"

    for _, v in ipairs({...}) do
        varname = varname .. "_" .. string.gsub(v, "[^%w]", "_")
    end

    return varname
end

---

local CC = {}
CC.__index = CC

CC.mt = {}
CC.mt.__index = CC.mt
setmetatable(CC, CC.mt)

function CC.mt.__call(_)
    local self = setmetatable({}, CC)

    self.cleanlist = {}
    self.cflags = {}
    self.incdirs = {}
    self.libs = {}
    self.libdirs = {}

    return self
end

function CC:target(name)
    return function(cfg)
        assert(cfg.srcs and #cfg.srcs > 0, '"srcs" must be an array')

        -- variables used by the target
        local vsrcs = ns(name, "SRCS") --<< source files
        local vobjs = ns(name, "OBJS") --<< object files
        local vcflags = ns(name, "CFLAGS") --<< compiler flags
        local vldlibs = ns(name, "LDLIBS") --<< linker libs (-l..., not -L...)
        local vldflags = ns(name, "LDFLAGS") --<< linker flags (including -L...)

        -- add object files to the clean list
        self.cleanlist[#self.cleanlist + 1] = vref(vobjs)

        -- build the target configuration variables
        local srcs = fconcat(cfg.srcs)
        local cflags = fconcat(self.cflags) .. fconcat(self.incdirs, "-I")
        local ldlibs = fconcat(self.libs, "-l")
        local ldflags = fconcat(self.libdirs, "-L")

        return {
            -- base configuration
            epine.svar(vsrcs, srcs),
            epine.svar(vcflags, cflags),
            epine.svar(vldlibs, ldlibs),
            epine.svar(vldflags, ldflags),
            epine.svar(vobjs, "$(" .. vsrcs .. ":.c=.o)"),
            -- target-specific configuration
            epine.static_if(cfg.cflags) {
                epine.append(vcflags, fconcat(cfg.cflags))
            },
            epine.static_if(cfg.incdirs) {
                epine.append(vcflags, fconcat(cfg.incdirs, "-I"))
            },
            epine.static_if(cfg.defines) {
                epine.append(
                    vcflags,
                    fconcat(
                        rmap(
                            cfg.defines,
                            function(k, v)
                                if type(k) == "number" then
                                    return tostring(v)
                                else
                                    return tostring(k) .. "=" .. tostring(v)
                                end
                            end
                        ),
                        "-D"
                    )
                )
            },
            epine.static_if(cfg.libs) {
                epine.append(vldlibs, fconcat(cfg.libs, "-l"))
            },
            epine.static_if(cfg.libdirs) {
                epine.append(vldflags, fconcat(cfg.libdirs, "-L"))
            },
            -- target-specific prerequisites (maybe a static library?)
            epine.static_if(cfg.prerequisites) {
                epine.erule {
                    targets = {name, vref(vobjs)},
                    prerequisites = cfg.prerequisites
                }
            },
            -- how we build the target
            epine.static_switch(cfg.type or "binary") {
                -- binary (default)
                ["binary"] = {
                    epine.erule {
                        targets = {name},
                        prerequisites = {vref(vobjs)},
                        recipe = {
                            "$(CC) -o $@ " .. vref(vobjs, vldlibs, vldflags)
                        }
                    }
                },
                -- static library
                ["static"] = "static-lib",
                ["static-lib"] = {
                    epine.erule {
                        targets = {name},
                        prerequisites = {vref(vobjs)},
                        recipe = {"$(AR) rc $@ " .. vref(vobjs)}
                    }
                }
            },
            -- static pattern rule to make object files
            epine.sprule {
                targets = {vref(vobjs)},
                target_pattern = "%.o",
                prereq_patterns = {"%.c"},
                recipe = {
                    "$(CC) $(CFLAGS) " .. vref(vcflags) .. " -c -o $@ $<"
                }
            }
        }
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

----------------------------------------------------------------------
-- Animations: fast open/close, smooth move/resize
----------------------------------------------------------------------
-- Reaches its destination quickly, then gently settles
hl.curve("quickOut", { type = "bezier", points = { { 0.16, 1.0 }, { 0.30, 1.0 } } })
-- Accelerates into the closing transition
hl.curve("quickIn",  { type = "bezier", points = { { 0.40, 0.0 }, { 1.0, 1.0 } } })
-- Responsive movement without bounce
hl.curve("smoothMove", { type = "bezier", points = { { 0.22, 1.0 }, { 0.36, 1.0 } } })

local animations = {
    { leaf = "windowsIn",   speed = 1.2, bezier = "quickOut",   style = "popin 90%" },  -- open
    { leaf = "windowsOut",  speed = 0.8, bezier = "quickIn",    style = "popin 95%" },  -- close
    { leaf = "windowsMove", speed = 1.2, bezier = "smoothMove" },                       -- move/drag/resize/tiling
    { leaf = "fadeIn",      speed = 1.2, bezier = "quickOut" },
    { leaf = "fadeOut",     speed = 0.8, bezier = "quickIn" },
}
for _, a in ipairs(animations) do
    a.enabled = true
    hl.animation(a)
end

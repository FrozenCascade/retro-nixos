----------------------------------------------------------------------
-- Window rules for ordinary applications
----------------------------------------------------------------------
-- Nothing to edit here. app_rules is generated from home/frozen/apps/entries.nix: every app with a
-- `window` block there becomes one rule. `set` holds the same properties hl.window_rule takes
-- (float, size, move, workspace, pin, ...), copied across as they are.
for _, app in ipairs(app_rules) do
    local rule = { name = app.name, match = app.match }
    for key, value in pairs(app.set) do
        rule[key] = value
    end
    hl.window_rule(rule)
end

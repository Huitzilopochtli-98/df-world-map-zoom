-- Run from the repository root with Lua 5.3 or newer.
package.path = 'hack/lua/?.lua;' .. package.path
for _, name in ipairs{'camera', 'input', 'gestures', 'diagnostics'} do
    assert(loadfile('tests/test_' .. name .. '.lua'))()
end

dofile("drivers/tests/lua_harness/host_mock.lua")
-- A mid-session phase flip only takes effect when the charger restarts the
-- session. Resuming in the same command as the pause reached the charger
-- before the contactor opened, so the car stayed on one phase.
local driver = "drivers/lua/easee_cloud.lua"
host.reset()
host._millis_step = 0
host._http_responses["/accounts/login"] = '{"accessToken":"test","expiresIn":3600}'
host._http_responses["/config"] = '{}'
host._http_responses["/sessions/ongoing"] = '{}'
host._http_responses["/commands/"] = '{}'
host._http_responses["/settings"] = '{}'
dofile(driver)
driver_init({email="test@example.invalid",password="test",serial="TEST123"})

local function posts(path)
    local n = 0
    for _, call in ipairs(host._calls) do
        if call.func == "http_post" and string.find(call.args[1], path, 1, true) then
            n = n + 1
        end
    end
    return n
end
local function offer(w)
    local ok = driver_command("ev_set_current", w,
        {phase_mode="auto", voltage=230, max_amps_per_phase=16})
    assert(ok, "ev_set_current failed at " .. tostring(w) .. " W")
end
local function advance(ms) host._millis_counter = host._millis_counter + ms end

advance(1000)
offer(3000)
assert(posts("pause_charging") == 0, "first command of a session paused the charger")

advance(120000) -- past the 90 s phase hold
offer(9000)
assert(posts("pause_charging") == 1, "mid-session flip did not pause")
assert(posts("resume_charging") == 0, "resumed in the same command as the flip pause")

advance(5000)
offer(9000)
assert(posts("resume_charging") == 0, "resumed before the pause could reach the charger")

advance(10000)
offer(9000)
assert(posts("resume_charging") == 1, "did not resume once the flip delay passed")
advance(5000)
offer(9000)
assert(posts("resume_charging") == 1, "resumed again after the flip completed")

print("Easee phase flip: passed")

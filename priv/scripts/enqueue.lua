-- Atomically enqueue or schedule jobs while optionally enforcing uniqueness.
--
-- The returned status code indicates which action was taken:
--
-- 0 - The job was skipped due to a unique lock
-- 1 - The job was enqueued for immediate execution
-- 2 - The job was scheduled for future execution

local unique_key = KEYS[1]

local job = ARGV[1]
local queue = ARGV[2]
local enqueue_at = tonumber(ARGV[3])
local unlocks_in = tonumber(ARGV[4])

local is_unlocked = true
local status = 0

if unlocks_in then
  is_unlocked = redis.call("set", unique_key, unlocks_in, "px", unlocks_in, "nx")
end

if is_unlocked and enqueue_at then
  redis.call("zadd", "schedule", enqueue_at, job)

  status = 2
elseif is_unlocked then
  redis.call("sadd", "queues", queue)
  redis.call("lpush", "queue:" .. queue, job)

  status = 1
end

return status

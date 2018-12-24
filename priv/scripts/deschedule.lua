-- Find all jobs with a time "score" greater than the provided value and
-- enqueue then individually. Executing this atomically within a script
-- prevents any race conditions and avoids round-trip serialization of each
-- job.

local jobs = redis.call("zrangebyscore", KEYS[1], "0", ARGV[1])
local count = 0

for _idx, job in ipairs(jobs) do
  redis.call("zrem", KEYS[1], job)

  -- It is vastly faster to parse out the queue with a `match` than to decode
  -- the payload. Additionally, `cjson` will truncate large integers and
  -- doesn't maintain the exact job structure.
  local queue = string.match(job, '"queue":"(%w+)"')

  -- The queue set key and naming convention are hard coded here for the sake
  -- of simplicity.
  redis.call("sadd", "queues", queue)
  redis.call("lpush", "queue:" .. queue, job)

  count = count + 1
end

return count

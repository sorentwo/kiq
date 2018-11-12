local index = tonumber(ARGV[1])
local jobs = {}

repeat
  local job = redis.call("rpop", KEYS[1])

  if job then
    -- It is vastly faster to parse out the jid with `match` than to decode the
    -- job just for one value.
    local jid = string.match(job, '"jid":"(%w+)"')

    -- We store the backup in a hash, which allows us to quickly and accurately
    -- remove the backup after processing. Removing an element from a list
    -- requires an exact binary match, which isn't guaranteed when jobs are
    -- enqueued by Sidekiq.
    redis.call("hset", KEYS[2], jid, job)

    table.insert(jobs, job)

    index = index - 1
  else
    break
  end
until (index < 1)


return jobs

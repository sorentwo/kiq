local jobs = redis.call("zrangebyscore", KEYS[1], "0", ARGV[1])

for _idx, job in ipairs(jobs) do
  redis.call("zrem", KEYS[1], job)
end

return jobs

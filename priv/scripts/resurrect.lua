local jids = redis.call("hkeys", KEYS[1])

for _idx, jid in ipairs(jids) do
  local job = redis.call("hget", KEYS[1], jid)

  redis.call("lpush", KEYS[2], job)
  redis.call("hdel", KEYS[1], jid)
end

return #jids

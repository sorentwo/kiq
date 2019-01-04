# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixed

- [Kiq.Client.Resurrection] Correct usage of SCAN to ensure all backup queues
  will be found for re-enqueueing.

### Changed

- [Kiq.Job] Keys within job arguments are no longer converted to atoms. This is
  for safe execution and is in line with how Phoenix passes controller
  arguments.
- [Kiq.Client] Enqueue all jobs in a single pipelined command. This moves all of
  the unique, scheduling and enqueueing logic into a lua script. The script
  reduces the number of round trips to redis and enabled pipelining. Overall
  this improved job enqueue/execute performance from 1800 jobs/sec to slightly
  more than 3700 jobs/sec.

## [0.5.0] — 2018-12-14

### Added

- [Kiq.Periodic] Periodic jobs support! Periodic (AKA "Cron") jobs are
  registered with a schedule and enqueued automatically by Kiq accordingly.
  This is a fully fledged alternative to using a separate scheduler such as
  [Quantum][quantum].

[quantum]: https://github.com/quantum-elixir/quantum-core

### Changed

- [Kiq.Reporter.Logger] Job lifecycle logging uses the format `event:
  "job_status"` instead of `status: "status"`. For example, if you were checking
  logs for `"status":"finished"` you would now look for
  `"event":"job_finished"`.

### Fixed

- [Kiq.Client] Eliminate use of `MUTLI/EXEC` for stats and queuing. This caused
  a race condition that could prevent stats being recorded and jobs from being
  enqueued.

## [0.4.0] — 2018-12-03

### Added

- [Reporter.Retryer] Dead jobs support! Jobs with exhausted retries are moved
  into the `dead` set. Workers or jobs may be configured with `dead: false` to
  prevent being moved to the dead set.

- [Kiq] Quiet support! The `configure/1` function can be used to set runtime
  configuration. Calling `MyKiq.configure(quiet: true)` will stop all queues
  from starting new jobs while allowing currently running jobs to finish. This
  can be used for graceful shutdown and smooth blue/green deployment.

- [Reporter.Instrumenter] A new reporter that provides instrumentation data
  through [Telemetry](https://hexdocs.pm/telemetry). Reporting job execution
  metrics only requires attaching to `[:kiq, :job, event]` events.

- [mix kiq.gen.supervisor] A new generator to create an initial Kiq supervisor
  module.

- [mix kiq.gen.reporter] A new generator to create custom reporters with all of
  the callbacks defined.

- [mix kiq.gen.worker] A new generator to create workers with `retries`, `queue`
  and `dead` specified.

### Changed

- [Script] More functionality, including dequeueing and descheduling, has been
  moved into Lua scripts. To reduce bandwidth and io overhead all `EVAL` usage
  has been replaced with `EVALSHA`.

- [Identity] For purely aesthetic reasons the nonce value is now lower case.

- [Logger] Consistently format logs as JSON. Previously some ad-hoc logs were
  unstructured, which made parsing difficult. Additionally, logs now contain
  `"source":"kiq"` for easier identification.

### Fixed

- [Kiq] In progress backup queues, AKA "Private Queues", are now implemented
  with a hash rather than a list. This ensures that a job can _always_ be
  removed from the backup, regardless of how it is encoded. Previously, when a
  job was enqueued by Sidekiq the serialized version wouldn't match the
  version serialized by Kiq. The `LREM` command requires an exact binary match
  or list elements won't be removed, which caused jobs to linger in the backup
  queue.

## [0.3.0] — 2018-10-28

### Added

- [Kiq] Expiring Job support. Expiring jobs won't be ran after a configurable
  amount of time. The expiration period is set with the `expires_in` option,
  which accepts millisecond values identically to the `unique_for` option.

- [Kiq.Pool] Connection pooling. Recently added benchmarks quickly identified a
  bottleneck in the single Client/Redis connection. A simple random-order pool
  was introduced that allowed the client, queues and reporters to rotate through
  a set of connections. This change alone doubled the enqueue/dequeue
  throughput.

- [Kiq.Client] Reliable push support. Enqueued jobs are now buffered in memory
  and periodically flushed to Redis. If there are any connection errors or Redis
  is down the jobs are retained and flushing is retried with backoff.

- [Kiq.Testing] Sandbox test mode. When `test_mode` is set to `:sandbox` jobs
  will never be flushed to Redis. Each locally buffered job is associated with
  the process that enqueued it, enabling concurrent testing with isolation
  between test runs.

- [Kiq] Leadership election. Useful when coordinating work that should only
  happen on a single node. Internally used to prevent duplicate job
  resurrection, and in the future will be used for periodic jobs.

- [Kiq] Private queues. Ensure terminated jobs are resurrected when the
  application starts up. Unlike the previous job backup mechanism this
  guarantees that only jobs from dead processors are resurrected; in-process
  jobs will never be duplicated.

### Changed

- [Redix] Upgrade from Redix 0.7.X to 0.8.X, which introduced the `noreply_` variant of
  commands.

- [Kiq.Config] Renamed `poll_interval` option to `flush_interval`, and the
  default changed from `1000` to `500`.

### Fixed

- [Kiq] Failing unique jobs would never be retried.

## [0.2.0] — 2018-09-17

### Added

- [Kiq] Unique Job support! Workers, and their corresponding jobs, can now be
  made unique within for a period of time. Until the initial job has succeeded
  it is considered "locked" and all subsequent attempts to enqueue a job with
  the same class, queue and args will be ignored. The unique period is specified
  with the `unique_for` option, which accepts millisecond values for easy
  interaction with the `:timer` module's `minutes/1` and `seconds/1` functions.

### Fixed

- [Kiq.Runner] Correctly convert nested modules binaries into the correct
  worker, i.e.  convert `"Kiq.Workers.Business"` into the module
  `Kiq.Workers.Business`.

- [Kiq.Job] Correctly serialize pid and job payloads when recording a worker's
  running jobs for heartbeats. Incorrectly formatted hashes in Redis will cause
  the Sidekiq "busy" dashboard to crash.

- [Kiq.Heartbeat] Retain the original `ran_at` value for reported jobs. Running
  jobs are now encoded when they are started, preventing repeated JSON encodings
  and allowing the initial `ran_at` value to be used when reporting. Prior to
  this change the job was always reported as being started "Just Now".

- [Kiq.Job] Skip serializing `retry_count` when the value is 0. Sidekiq doesn't
  include a `retry_count` when there hasn't been a retry, which prevents the job
  serialized by Kiq from matching up. If the serialized job doesn't match up
  then the job can't be removed from the backup queue, leading to a buildup of
  duplicate jobs.

## [0.1.0] - 2018-07-31

### Added

Initial release, everything was added!

- Job creation
- Worker definition
- Running and configuring queues
- Retries
- Scheduled jobs
- Statistics
- Custom reporters
- Testing support
- Heartbeat reporting

[Unreleased]: https://github.com/sorentwo/kiq/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sorentwo/kiq/compare/e6106af2506...v0.1.0
[0.2.0]: https://github.com/sorentwo/kiq/compare/v0.1.0...v0.2.0
[0.3.0]: https://github.com/sorentwo/kiq/compare/v0.2.0...v0.3.0
[0.4.0]: https://github.com/sorentwo/kiq/compare/v0.3.0...v0.4.0
[0.5.0]: https://github.com/sorentwo/kiq/compare/v0.4.0...v0.5.0

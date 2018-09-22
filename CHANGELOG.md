# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Expiring Job support. Expiring jobs won't be ran after a configurable amount
  of time. The expiration period is set with the `expires_in` option, which
  accepts millisecond values identically to the `unique_for` option.

### Fixed

- Failing unique jobs would never be retried.

## [0.2.0] — 2018-09-17

### Added

- Unique Job support. Workers, and their corresponding jobs, can now be made
  unique within for a period of time. Until the initial job has succeeded it is
  considered "locked" and all subsequent attempts to enqueue a job with the same
  class, queue and args will be ignored. The unique period is specified with the
  `unique_for` option, which accepts millisecond values for easy interaction
  with the `:timer` module's `minutes/1` and `seconds/1` functions.

### Fixed

- Correctly convert nested modules binaries into the correct worker, i.e.
  convert `"Kiq.Workers.Business"` into the module `Kiq.Workers.Business`.
- Correctly serialize pid and job payloads when recording a worker's running
  jobs for heartbeats. Incorrectly formatted hashes in Redis will cause the
  Sidekiq "busy" dashboard to crash.
- Retain the original `ran_at` value for reported jobs. Running jobs are now
  encoded when they are started, preventing repeated JSON encodings and allowing
  the initial `ran_at` value to be used when reporting. Prior to this change
  the job was always reported as being started "Just Now".
- Skip serializing `retry_count` when the value is 0. Sidekiq doesn't include a
  `retry_count` when there hasn't been a retry, which prevents the job
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

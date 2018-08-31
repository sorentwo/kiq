# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

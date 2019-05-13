# Kiq

[![Build Status](https://travis-ci.org/sorentwo/kiq.svg?branch=master)](https://travis-ci.org/sorentwo/kiq)
[![Hex.pm Version](http://img.shields.io/hexpm/v/kiq.svg)](https://hex.pm/packages/kiq)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/kiq.svg)](https://hex.pm/packages/kiq)
[![Hex Docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/kiq)

Kiq is a robust and extensible job processing queue that aims for compatibility
with [Sidekiq][sk], [Sidekiq Pro][skp] and [Sidekiq Enterprise][ske].

Job queuing, processing and reporting are all built on [GenStage][genst]. That means
maximum parallelism with the safety of backpressure as jobs are processed.

[genst]: https://github.com/elixir-lang/gen_stage

### Why Kiq?

Many features and architectural choices in Kiq were drawn from existing Elixir
job processing packages like [Exq][exq], [Verk][verk] and [EctoJob][ej]. Each
of those packages are great and have varying strenghts, but they lacked seamless
interop with Sidekiq Pro or Sidekiq Enterprise jobs.

Sidekiq Pro and Enterprise are amazing pieces of commercial software and worth
every cent—your organization should buy them! Kiq is intended as a _bridge_ for
your team to _interop_ between Ruby and Elixir. As an organization embraces
Elixir it becomes necessary to run some background jobs in Elixir, and it must
be just as reliable as when jobs were ran through Sidekiq.

[sk]: https://sidekiq.org/
[skp]: https://sidekiq.org/products/pro.html
[ske]: https://sidekiq.org/products/enterprise.html
[exq]: https://github.com/akira/exq
[verk]: https://github.com/edgurgel/verk
[ej]: https://github.com/mbuhot/ecto_job

### Sidekiq Pro & Enterprise Comaptible Feature Set

Kiq's feature set includes many marquee offerings from Sidekiq, Sidekiq Pro and
Sidekiq Enterprise—plus some additional niceties made possible by running on the
BEAM. Here is a table highlighting the Kiq's features compared to the various
Sidekiq versions:

| Feature            | Kiq         | Sidekiq    | Sidekiq Pro | Sidekiq Ent |
| ------------------ | ----------- | ---------- | ----------- | ----------- |
| Max Size Queues    | ✅          | ❌         | ❌          | ❌          |
| Structured Logging | ✅          | ❌         | ❌          | ❌          |
| Scheduled Jobs     | ✅          | ✅         | ✅          | ✅          |
| Error Handling     | ✅          | ✅         | ✅          | ✅          |
| Expiring Jobs      | ✅          | ❌         | ✅          | ✅          |
| Worker Metrics     | ✅          | ❌         | ✅          | ✅          |
| Reliable Client    | ✅          | ❌         | ✅          | ✅          |
| Reliable Server    | ✅          | ❌         | ✅          | ✅          |
| Rolling Restarts   | ✅          | ❌         | ❌          | ✅          |
| Periodic Jobs      | ✅          | ❌         | ❌          | ✅          |
| Unique Jobs        | ✅          | ❌         | ❌          | ✅          |
| Leader Election    | ✅          | ❌         | ❌          | ✅          |
| Multi Process      | ✅          | ❌         | ❌          | ✅          |
| Web UI †           | ❌          | ✅         | ✅          | ✅          |
| Batch Jobs ‡       | ❌          | ❌         | ✅          | ✅          |
| Encryption ‡       | ❌          | ❌         | ❌          | ✅          |
| Rate Limiting ‡    | ❌          | ❌         | ❌          | ✅          |

* † Kiq relies on Sidekiq's Web UI
* ‡ Planned, but not implemented yet

If a feature isn't supported or planned it is _probably_ for one of these
reasons:

1. We get it for free on the BEAM and it isn't necessary, i.e. (safe shutdown,
   multi-process, rolling restarts)
3. We enable developers to use custom reporters to do it themselves (stats,
   error reporting)

### Design Decisions

* Avoid global and compile time configuration. All configuration can be defined
  programatically, eliminating the need for hacks like `{:system, "REDIS_URL"}`.
* Not an application, it is included in your application's supervision tree
* Testing focused, provide helpers and modes to aid testing
* Extensible job handling via GenStage consumers
* Simplified worker definitions to ease job definition and pipelining

[ent]: https://sidekiq.org/products/enterprise.html

## Installation

Add `kiq` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kiq, "~> 0.7"}
  ]
end
```

Then run `mix deps.get` to install the dependency.


Finally, add the supervisor to your application's supervision tree:

```elixir
{MyApp.Kiq, []}
```

Kiq itself is not an application and must be started within your application's
supervision tree. All of your application's configuration and custom methods
should be put into the supervisor.

## Usage

Kiq isn't an application that must be started. Similarly to Ecto, you define
one or more Kiq modules within your application. This allows multiple
supervision trees with entirely different configurations.

Run the generator to define a Kiq supervisor for your application:

```bash
mix kiq.gen.supervisor MyApp.Kiq
```

Include the module in your application's supervision tree:

```elixir
defmodule MyApp.Application do
  @moduledoc false

  use Application

  alias MyApp.{Endpoint, Kiq, Repo}

  def start(_type, _args) do
    children = [
      {Repo, []},
      {Endpoint, []},
      {Kiq, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

With the supervision tree in place you are ready to start creating workers! The
simplest way to create a worker is through the generator:

```bash
mix kiq.gen.worker MyApp.Workers.Business
```

That will define a worker with a `perform/1` function where all the magic will
happen.

See `mix help kiq.gen.worker` for additional options.

Check the [hexdocs][hd] for additional details, configuration options, how to
test, defining workers and custom reporters.

[hd]: https://hexdocs.pm/kiq

## Benchmarks

Kiq has a set of benchmarks to track the performance of important operations.
Benchmarks are ran using the [Benchee][benchee] library and require Redis to be
running.

To run all benchmarks:

```bash
mix run bench/bench_helper.exs
```

[benchee]: https://github.com/PragTob/benchee

## Contributing

Clone the repository and run `$ mix test` to make sure everything is working. For
tests to pass, you must have a Redis server running on `localhost`, port `6379`,
database `3`. You can configure a different host, port and database by setting
the `REDIS_URL` environment variable before testing.

Note that tests will wipe the the configured database on the Redis server
multiple times while testing. By default database 3 is used for testing.

## License

Kiq is released under the MIT license. See the [LICENSE](LICENSE.txt).

Toniq
=======

Simple and reliable background job processing library for [Elixir](http://elixir-lang.org/).

[![asciicast](https://asciinema.org/a/4d81ntu7max782kgfslw4pbym.png)](https://asciinema.org/a/4d81ntu7max782kgfslw4pbym)

* Focuses on being easy to use and handling errors well.
* Will automatically retry failing jobs a few times.
* It has practically no limits on concurrent jobs.
* Can limit concurrency using a max concurrency option.
* Passes arguments to the worker exactly as they where enqueued, no JSON conversion.
* Fails on the side of running a job too many times rather than not at all. See more on this below.
* Works well on limited environments like Heroku where you can't connect multiple Erlang nodes directly or do hot code updates.
* Uses redis to persist jobs but is **not** resque/sidekiq compatible.
  - If you need that then I'd recommend you look at [Exq](https://github.com/akira/exq).
  - You can run both Exq and Toniq in the same app for different workers.

If anything is unclear about how this library works or what an error message means **that's considered a bug**, please file an issue (or a pull request)!

--

**Status**: Relatively new. Used quite a lot of apps since 1.0 (nov, 2015). If you like, ping [@joakimk](https://twitter.com/joakimk) about how you use toniq and for what size/type of app.

## Installation

Add as a dependency in your mix.exs file:

```elixir
defp deps do
  [
    {:exredis, ">= 0.2.4"},
    {:toniq, "~> 1.0"}
  ]
end
```

And run:

    mix deps.get

Then add `:toniq` to the list of applications in mix.exs.

And configure toniq in different environments:

```elixir
config :toniq, redis_url: "redis://localhost:6379/0"
# config :toniq, redis_url: System.get_env("REDIS_PROVIDER")
```

If you have multiple apps using the same redis server, then don't forget to also configure `redis_key_prefix`.

### Dynamic redis url

If you need to configure redis dynamically after the application starts, you can use `redis_url_provider` to block until a redis_url is available.

```elixir
config :toniq, redis_url_provider: fn -> wait_for_redis_url_to_be_available end
```

## Adapters

The default persistence is Toniq.RedisJobPersistence. To swap the adapter:

```
config :toniq, persistence: Toniq.SkipJobPersistence
```

## Usage

Define a worker:

```elixir
defmodule SendEmailWorker do
  use Toniq.Worker

  def perform(to: to, subject: subject, body: body) do
    # do work
  end
end
```

Enqueue jobs somewhere in your app code:

```elixir
Toniq.enqueue(SendEmailWorker, to: "info@example.com", subject: "Hello", body: "Hello, there!")
```

## Pipelines

You can also enqueue jobs using |> like this:


```elixir
email = [to: "info@example.com", subject: "Hello", body: "Hello, there!"]

email
|> Toniq.enqueue_to(SendEmailWorker)
```

## Delayed jobs

And delay jobs.

```elixir
email = [to: "info@example.com", subject: "Hello", body: "Hello, there!"]

# Using enqueue_to:
email
|> Toniq.enqueue_to(SendEmailWorker, delay_for: 1000)

# Using enqueue_with_delay:
Toniq.enqueue_with_delay(SendEmailWorker, email, delay_for: 1000)
```

## Pattern matching

You can pattern match in workers. This can be used to clean up the code, or to handle data from previous versions of the same worker!

```elixir
defmodule SendMessageWorker do
  use Toniq.Worker

  def perform(message: "", receipient: _receipient) do
    # don't send empty messages
  end

  def perform(message: message, receipient: receipient) do
    SomeMessageService.send(message, receipient)
  end
end
```

## Limiting concurrency

For some workers you might want to limit the number of jobs that run at the same time. For example, if you call out to a API, you most likely don't want more than 3-10 connections at once.

You can set this by specifying the `max_concurrency` option on a worker.

```elixir
defmodule RegisterInvoiceWorker do
  use Toniq.Worker, max_concurrency: 10

  def perform(attributes) do
    # do work
  end
end
```

## Retrying failed jobs

An admin web UI is planned, but until then (and after that) you can use the console.

Retrying all failed jobs:

```elixir
iex -S mix
iex> Toniq.failed_jobs |> Enum.each &Toniq.retry/1
```

Retrying one at a time:

```elixir
iex> job = Toniq.failed_jobs |> hd
iex> Toniq.retry(job)
```

Or delete the failed job:

```elixir
iex> job = Toniq.failed_jobs |> hd
iex> Toniq.delete(job)
```

## Automatic retries

Jobs will be retried automatically when they fail. This can be customized, or even disabled by configuring a retry strategy for toniq (keep in mind that a system crash will still cause a job to be run more than once in some cases even if retries are disabled).

The default strategy is [Toniq.RetryWithIncreasingDelayStrategy](lib/toniq/retry_with_increasing_delay_strategy.ex), which will retry a job 5 times after the initial run with increasing delay between each. Delays are approximately: 250 ms, 1 second, 20 seconds, 1 minute and 2.5 minutes. In total about 4 minutes (+ 6 x job run time) before the job is marked as failed.

An alternative is [Toniq.RetryWithoutDelayStrategy](lib/toniq/retry_without_delay_strategy.ex) which just retries twice without delay (this is used in toniq tests).

```elixir
config :toniq, retry_strategy: Toniq.RetryWithoutDelayStrategy
# config :toniq, retry_strategy: YourCustomStrategy
```

## Load balancing

As toniq only runs jobs within the VM that enqueued them, it's up to you to enqueue jobs in different VMs if you want to run more of them concurrently than a single Erlang VM can handle.

This could be as simple as web requests to load balanced web servers enqueuing jobs within each web server, or as complex as a custom redis pub-sub system.

Alternatively you can use [Toniq.JobImporter](lib/toniq/job_importer.ex) to pass jobs to a random VM. It has a little delay due to being a polling system.

```elixir
identifier = Toniq.KeepalivePersistence.registered_vms |> Enum.shuffle |> hd
Toniq.JobPersistence.store_incoming_job(Toniq.TestWorker, [], identifier)
```

## Designed to avoid complexity

Instead of using redis as a messaging queue, toniq uses it for backup.

Jobs are run within the VM where they are enqueued. If a VM is stopped or crashes, unprocessed jobs are recovered from redis once another VM is running.

By running jobs within the same VM that enqueues them we avoid having to use any locks in redis. Locking is a complex subject and very hard to get right. Toniq should be simple and reliable, so let's avoid locking!

## Request for feedback

I would like to know how using this tool works out for you. Any problems? Anything that was hard to understand from the docs? What scale do you run jobs on? Works great? Better than something you've used before? Missing some feature you're used to?

Ping [@joakimk](https://twitter.com/joakimk) or open an issue.

## FAQ

### Why have a job queue at all?

* You don't have to run the code synchronously. E.g. don't delay a web response while sending email.
* You don't have to write custom code for the things a job queue can handle for you.
* You get persistence, retries, failover, concurrency limits, etc.

### Will jobs be run in order?

This is a first-in-first-out queue but due to retries and concurrency, ordering can not be guaranteed.

### How are jobs serialized when stored in redis?

Jobs are serialized using [erlang serialization](http://www.erlang.org/doc/apps/erts/erl_ext_dist.html). It's the same format that is used when distributed nodes communicate. This means you can pass almost anything to jobs.

### What happens if the serialization format changes?

There is code in place to automatically [migrate](lib/toniq/job.ex) old versions of jobs.

### If an Erlang VM stops with unprocessed jobs in its queue, how are those jobs handled?

As soon as another Erlang VM is running it will find the jobs in redis, move them into it's own queue and run them. It may take a little while before this happens (10-15 seconds or so), so that the original VM has a chance to report in and retain it's jobs.

### Why will jobs be run more than once in rare cases?

If something really unexpected happens and a job can't be marked as finished after being run, this library prefers to run it twice (or more) rather than not at all.

Unexpected things include something killing the erlang VM, an unexpected crash within the job runner, or problems with the redis connection at the wrong time.

You can solve this in two ways:
* Go with the flow: make your jobs runnable more than once without any bad sideeffects. Also known as [Reentrancy](https://en.wikipedia.org/wiki/Reentrancy_(computing)).
* Implement your own locking, or contribute some such thing to this library.

I tend to prefer the first alternative in whenever possible.

### How do I run scheduled or recurring jobs?

There is no built-in support yet, but you can use tools like <https://github.com/c-rack/quantum-elixir> to schedule toniq jobs.

```elixir
config :quantum, cron: [
  # Every 15 minutes
  "*/15 * * * *": fn -> Toniq.enqueue(SomeWorker) end
]
```

## Notes

This project uses `mix format` to format the code. Ensure that you run that when you make changes. One easy way is to have an editor plugin run it for you when you save.

## Versioning

This library uses [semver](http://semver.org/) for versioning. The API won't change in incompatible ways within the same major version, etc. The version is specified in [mix.exs](mix.exs).

## Credits

- The name toniq was thought up by [Henrik Nyh](https://github.com/henrik). The idea was synonym of elixir with a q for queue.
- [Lennart Fridén](https://github.com/devl) helped out with building the failover system during his [journeyman-tour](http://codecoupled.org/journeyman-tour/) [visit to our office](https://codecoupled.org/2015/10/14/journeyman-auctionet/).
- [Safwan Kamarrudin](https://github.com/safwank) contributed the delayed jobs feature.

## Presentations featuring toniq

- 2015
  - Presentation at Stockholm Elixir "October talkfest": [slides](https://dl.dropboxusercontent.com/u/136929/elixir_oct2015_toniq/index.html#1)

## Contributing

* Pull requests:
  - Are very welcome :)
  - Should have tests
  - Should have refactored code that conforms to the style of the project (as best you can)
  - Should have updated documentation
  - Should implement or fix something that makes sense for this library (feel free to ask if you are unsure)
  - Will only be merged if all the above is fulfilled. I will generally not fix your code, but I will try and give feedback.
* If this project ever becomes too inactive, feel free to ask about taking over as maintainer.

## Development

    mix deps.get
    mix test

While developing you can use `mix test.watch --stale` to run tests as you save files.

You can also try toniq in dev using [Toniq.TestWorker](lib/toniq/test_worker.ex).

    iex -S mix
    iex> Toniq.enqueue(Toniq.TestWorker)
    iex> Toniq.enqueue(Toniq.TestWorker, :fail_once)

## TODO and ideas for after 1.0

* [ ] Work on and/or help others work on github issues
* [ ] See if delayed jobs could use incomming jobs for importing so it does not need `reload_job_list`.
* [ ] Report errors in a more standard way, see discussion on [honeybadger-elixir#30](https://github.com/honeybadger-io/honeybadger-elixir/issues/30)
* [ ] Document how to test an app using Toniq. E.g. use Toniq.JobEvent.subscribe, etc.
* [ ] Admin UI (idle, was being worked on by [kimfransman](https://twitter.com/kimfransman/status/661126637061332992))
  - [ ] That shows waiting and failed jobs
  - [ ] Make data easiliy available for display in the app that uses toniq
  - [ ] Store/show time of creation
  - [ ] Store/show retry count
  - [ ] MAYBE: JSON API for current job stats
  - [ ] MAYBE: Webhook to push job stats updates
* [ ] A tiny web page instead of just a redirect at <http://toniq.elixir.pm>.
  - A phoenix app using toniq with regularly scheduled jobs, and ways to trigger jobs would be fun. Especially if the Admin UI exists so you can see them run, retry, etc.
* [ ] Document JobEvent in readme
* [ ] Add CI
  - Run tests in R17 as people still use that
* [ ] Log an error when a job takes "too long" to run, set a sensible default
  - Not detecting this has led to production issues in other apps. A warning is easy to do and can help a lot.
* [ ] Better error for arity bugs on `perform` since that will be common. Lists need to be ordered, if it's a list, make the user aware of that, etc.
* [x] Be able to skip persistence
* [ ] Simple benchmark to see if it behaves as expected in different modes
   - [ ] write job times in microseconds?
   - [ ] benchmark unpersisted jobs
   - [ ] benchmark persisting many jobs (100k+)
   - [ ] benchmark many long running jobs
   - [ ] optimize a bit
   - [ ] comparative benchmark for sidekiq and/or exq?
* [ ] Test that RedisConnection shows the nice error message
* [ ] More logging
* [ ] Consider starting toniq differently in tests to better isolate unit tests
* [ ] Custom retry stategies per worker
* [ ] Support different enqueue strategies on a per-worker or per-enqueue basis
  - [ ] Delayed persistence: faster. Run the job right away, and persist the job at the same time. You're likely going to have a list of jobs to resume later if the VM is stopped.
  - [ ] No persistence: fastest. Run the job right away. If the VM is stopped jobs may be lost.
* [ ] Add timeouts for jobs (if anyone needs it). Should be fairly easy.
* [ ] Look into cleaning up code using [exactor](https://github.com/sasa1977/exactor)
* [ ] Look into using [redix](https://github.com/whatyouhide/redix). A native elixir redis client. Explore error handling and usabillity. Benchmark.

## License

Copyright (c) 2015-2017 [Joakim Kolsjö](https://twitter.com/joakimk)

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

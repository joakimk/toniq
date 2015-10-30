# NOTE: Readme driven development below, this means this tool does not necessarily do what it says below yet.

**Status**: The core parts are there, failover works, error handling works and jobs are run. See the 1.0 todo list.

Toniq
=======

Simple and reliable background job library for [Elixir](http://elixir-lang.org/).

Designed to:

* Be very easy to use. Just define a worker and enqueue jobs!
* Pass arguments to the worker exactly as they where enqueued, no JSON conversion
* Automatically retry jobs that fail
* Be able to limit concurrency and skip persistence when requested
* Play to Erlang's strengths by using processes well
  - Practically no limits on concurrent jobs
  - Uses all available CPU cores
* Fail on the side of running a job too many times rather than not at all. See more on this below.
* Work well on limited environments like Heroku where you can't connect multiple Erlang nodes directly or do hot code updates
* Have helpful error messages

Uses redis to persist jobs but is **not** resque/sidekiq compatible. If you need that then I'd recommend you look at [Exq](https://github.com/akira/exq). You can run both Exq and Toniq in the same app for different workers.

If **anything is unclear** about how this library works or what an error message means **that's considered a bug**, please file an issue (or a pull request)!

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

  def perform(invoice_attributes) do
    # do work
  end
end
```

## Skipping persistence

For jobs where speed is important and it does not matter if it's lost on app server restart.

As an example, say you wanted to record page hits in redis. By doing so in a background job, you would not only respond quicker to the web request, but also handle temporary connection errors.

You can set this by specifying the `persist` option on a worker.

```elixir
defmodule RecordPageHitWorker do
  use Toniq.Worker, persist: false

  def perform do
    # do work
  end
end
```

And in the web request run:

```elixir
Toniq.enqueue(RecordPageHitWorker)
```

Or you could specify it for induvidual enqueue's:

```elixir
Toniq.enqueue(SendEmailWorker, [subject: "5 minute reminder!", to: "..."], persist: false)
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

## Designed to avoid complexity

Instead of using redis as a messaging queue, toniq uses it for backup.

Jobs are run within the VM where they are enqueued. If a VM is stopped or crashes, unprocessed jobs are recovered from redis once another VM is running.

By running jobs within the same VM that enqueues them we avoid having to use any locks in redis. Locking is a complex subject and very hard to get right. Toniq should be simple and reliable, so let's avoid locking!

## Load balancing

As toniq only runs jobs within the VM that enqueued them, it's up to you to enqueue jobs in different VMs if you want to run more of them concurrently than a single Erlang VM can handle.

This could be as simple as web requests to load balanced web servers enqueuing jobs within each web server, or as complex as a custom redis pub-sub system.

Alternatively you can use [Toniq.JobImporter](lib/toniq/job_importer.ex) to pass jobs to a random VM. It has a little delay due to being a polling system.

```elixir
identifier = Toniq.KeepalivePersistence.registered_vms |> Enum.shuffle |> hd
Toniq.JobPersistence.store_incoming_job(Toniq.TestWorker, [], identifier)
```

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

### If an Erlang VM stops with unprocessed jobs in its queue, how are those jobs handled?

As soon as another Erlang VM is running it will find the jobs in redis, move them into it's own queue and run them. It may take a little while before this happens (10-15 seconds or so), so that the original VM has a chance to report in and retain it's jobs.

### Why will jobs be run more than once in rare cases?

If something really unexpected happens and a job can't be marked as finished after being run, this library prefers to run it twice (or more) rather than not at all.

Unexpected things include something killing the erlang VM, an unexpected crash within the job runner, or problems with the redis connection at the wrong time.

You can solve this in two ways:
* Go with the flow: make your jobs runnable more than once without any bad sideeffects. Also known as [Reentrancy](https://en.wikipedia.org/wiki/Reentrancy_(computing)).
* Implement your own locking, or contribute some such thing to this library.

I tend to prefer the first alternative in whenever possible.

## TODO

### Speed

* [x] Infinite concurrency

### 1.0

- [ ] A failed job will be automatically retried with a delay between each.
* [ ] See if it makes sense to store the reason for a failed job before 1.0 (e.g. changes in persistence format)
* [ ] Review persistence format. Will have to write migrations after 1.0.
* [ ] Custom max\_concurrency
  - Probably only enforced on a VM-level. Two VMs of max\_concurrency 10 can run 20 concurrent jobs. Document how it works.
  - Idea: use GenEvent of finished/failed to drive it?
* [ ] Log an error when a job takes "too long" to run, set a sensible default
  - Not detecting this has led to production issues in other apps. A warning is easy to do and can help a lot.
* [ ] Verify that errors are only reported to honeybadger when a job is moved into failed_jobs
* [ ] Add CI
* [ ] Update README to reflect what exists and remove readme-driven-development tag.
* [ ] Remove all old todos from the readme.
* [ ] Review the data available to the worker. Would it make sense to make the id available? Maybe to be able to do serial jobs? Would only exist for persisted jobs?
* [ ] Make a note about API stability and semver
* [ ] Hex package
* [ ] Add installation instructions
  - Make a note about multiple apps using the same redis server and the config for that.
* [ ] MAYBE: Better error for arity bugs on `perform` since that will be common. Lists need to be ordered, if it's a list, make the user aware of that, etc.

### Later

* [ ] Be able to skip persistence
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
* [ ] Be able to run without any persistence if none is needed?
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.
* [ ] Support different enqueue strategies on a per-worker or per-enqueue basis
  - [ ] Delayed persistence: faster. Run the job right away, and persist the job at the same time. You're likely going to have a list of jobs to resume later if the VM is stopped.
  - [ ] No persistence: fastest. Run the job right away. If the VM is stopped jobs may be lost.
* [ ] Add timeouts for jobs (if anyone needs it). Should be fairly easy.
* [ ] Admin UI
  - [ ] That shows waiting and failed jobs
  - [ ] Make data easiliy available for display in the app that uses toniq
  - [ ] Store/show time of creation
  - [ ] Store/show retry count
* [ ] Look into cleaning up code using [exactor](https://github.com/sasa1977/exactor)

### Notes

I'm trying to follow the default elixir style when writing elixir. That means less space between things, like `["foo"]` instead of `[ "foo" ]` like I write most other code. Because of this, spacing may be a bit inconsistent.

## Credits

- The name toniq was thought up by [Henrik Nyh](https://github.com/henrik). The idea was synonym of elixir with a q for queue.
- [Lennart Fridén](https://github.com/devl) helped out with building the failover system during his [journeyman-tour](http://codecoupled.org/journeyman-tour/) [visit to our office](https://codecoupled.org/2015/10/14/journeyman-auctionet/).

## Contributing

* Pull requests:
  - Are very welcome :)
  - Should have tests
  - Should have refactored code that conforms to the style of the project (as best you can)
  - Should have updated documentation
  - Should implement or fix something that makes sense for this library (feel free to ask if you are unsure)
  - Will only be merged if all the above is fulfilled. I won't fix your code, but I will try and give feedback.
* If this project ever becomes too inactive, feel free to ask about taking over as maintainer.

## License

Copyright (c) 2015 [Joakim Kolsjö](https://twitter.com/joakimk)

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

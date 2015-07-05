# NOTE: Readme driven development below, this means this tool does not nessesaraly do what it says below yet.

**Status**: The core parts are there and jobs are run, but there is major bugs and missing features. See the todo list.

Toniq
=======

Simple and reliable background job library for [Elixir](http://elixir-lang.org/).

Just like [Phoenix](http://www.phoenixframework.org/), this library does not make you choose between productivity and speed.

Designed to:

* Be very easy to use. Just define a worker and enqueue jobs!
* Pass arguments to the worker exactly as they where enqueued, no JSON conversion
* Play to Erlang's strengths
  - One job is one Erlang process
  - 100k concurrent processes on one computer is not unusual
* Automatically retry jobs that fail
* Limit concurrency when requested
* Skip persistance when requested
* Notify about errors through [Logger](http://elixir-lang.org/docs/v1.0/logger/Logger.html)
  - Can be passed on to services like [honeybadger](https://github.com/joakimk/honeybadger)
* Use redis sparingly
  - To handle Erlang VM restarts and crashes without loosing jobs
  - To record failed jobs and be able to do manual retries or deletion
  - To be able to see status (iex for now, possible UI in the future)
* Fail on the side of running a job too many times rather than not at all. See more on this below.

Uses redis to persist jobs but is **not** resque/sidekiq compatible. If you need that then I'd recommend you look at [Exq](https://github.com/akira/exq).

If **anything is unclear** about how this library works **that's considered a bug**, please file an issue (or a pull request)!

## Usage

Define a worker:

```elixir
defmodule SendEmailWorker do
  use Toniq.Worker

  def perform(to: to, subject: title, body: body)
    # do work
  end
end
```

Enqueue jobs somewhere in your app code:

```elixir
Toniq.enqueue(SendEmailWorker, to: "info@example.com", subject: "Hello", body: "Hello, there!")
```

## Limiting concurrency

For some workers you might want to limit the number of jobs that run at the same time. For example, if you call out to a API, you most likely don't want more than 3-10 connections at once.

You can set this by specifying the `max_concurrency` option on a worker.

```elixir
defmodule RegisterArtistWorker do
  use Toniq.Worker, max_concurrency: 10

  def perform(artist_attributes)
    # do work
  end
end
```

## Skipping persistance

For jobs where speed is important and it does not matter if it's lost on app server restart.

As an example, say you wanted to record page hits in redis. By doing so in a background job, you would not only respond quicker to the web request, but also handle temporary connection errors.

You can set this by specifying the `persist` option on a worker.

```elixir
defmodule RecordPageHitWorker do
  use Toniq.Worker, persist: false

  def perform
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

## Will jobs be run in order?

This is a first-in-first-out queue but due to retries and concurrency, ordering can not be guaranteed.

## How are jobs serialized when stored in redis?

Jobs are serialized using erlang serialization. This means you can pass almost anything to jobs, but just passing basic types is probably a good idea for compatibility with future code changes

## If an Erlang VM stops and not all jobs are processed, how are those jobs handled?

As soon as another Erlang VM is running it will find the jobs in redis, move them into it's own queue and run them. It may take a little while before this happens (10-15 seconds or so),
so that the original VM has a chance to report in and retain it's jobs.

This is the only place where locking is used in redis. It is used to ensure that only one Erlang VM picks up jobs from a stopped one.

## Why will jobs be run more than once in rare cases?

If something really unexpected happens and a job can't be marked as finished after being run, this library prefers to run it twice (or more) rather than not at all.

Unexpected things include something killing the erlang VM, an unexpected crash within the job runner, or problems with the redis connection at the wrong time.

You can solve this in two ways:
* Go with the flow: make your jobs runnable more than once without any bad sideeffects. Also known as [Reentrancy](https://en.wikipedia.org/wiki/Reentrancy_(computing)).
* Implement your own locking, or contribute some such thing to this library.

I tend to prefer the first alternative in whenever possible.

## TODO

### Enough to run jobs with no safety what so ever :)

* [x] Always store jobs in redis and have another process pull them out to support multiple erlang vms adding jobs, like when having multiple web servers
* [x] Implement pubsub
* [x] Implement job subscriber
* [x] Find out why killing any process kills the entire app even if the supervisor ought to restart that part.
* [x] Just run jobs in worker watcher

### Enough to replace what's currently in content\_translator

This library was initially built to support what was needed in [content_translator](https://github.com/barsoom/content_translator).

* [x] Implement job runner and monitor
* [x] Enqueue and run jobs for different workers
* [x] Will only mark a job as done if it exits successfully
* [x] Be able to mark jobs as failed
* [x] Limit concurrency to 1 by default
* [x] Errors are reported
* [ ] Rewrite the job handling according to the new design ideas (should be much simpler, no PubSub, etc)
* [ ] Avoid running duplicate jobs due to polling and current setup
* [ ] Review the code one more time
* [ ] Licence and pull request instructions

### 1.0

* [ ] Support takeover of jobs from a stopped VM.
* [ ] Make the tests reliable.
* [ ] Figure out if exredis can be supervised, maybe by wrapping it in a supervised worker
* [ ] Verify that enqueue worked, it may return a no connection error
* [ ] Custom and infinite max_concurrency
* Retries
  - [ ] A failed job will be automatically retried with a delay between each.
  - [ ] A failed job can be manually retried and/or deleted by running code in an iex prompt.
* [x] Re-queues jobs that exist in redis when it starts so that server crashes won't make you loose jobs.
  - [x] Make persistance abstract, don't assume redis
* [ ] Errors will only be reported if retries fail.
* [x] Consider renaming this since it's very hard to differentiate between exqueue and exq in spoken language
* [ ] Add CI
* [ ] Hex package
* [ ] Update README to reflect what exists and remove readme-driven-development tag.

### Later

* [ ] More complete testing of JobSubscriber
* [ ] See if the pubsub can be made cleaner. Also support database numbers.
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.
* [ ] Find out why :eredis_sub.controlling_process makes the entire app shutdown when killed (or any part of it's linked processes dies). "[info]  Application toniq exited: shutdown". Would allow us to keep it linked.
* [ ] Support different enqueue strategies on a per-worker or per-enqueue basis
  - [ ] Delayed persistance: faster. Run the job right away, and persist the job at the same time. You're likely going to have a list of jobs to resume later if the VM is stopped.
  - [ ] No persistance: fastest. Run the job right away. If the VM is stopped jobs may be lost.
* [ ] Add timeouts for jobs (if anyone needs it). Should be fairly easy.

### Notes

I'm trying to follow the default elixir style when writing elixir. That means less space between things, like `["foo"]` instead of `[ "foo" ]` like I write most other code. Because of this, spacing may be a bit inconsistent.

### Credits

- The name toniq was thought up by [Henrik Nyh](https://github.com/henrik). The idea was synonym of elixir with a q for queue.

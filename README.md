# NOTE: Readme driven development below, this means this tool does not nessesaraly do what it says below yet.

**Status**: The core parts are there and jobs are run, but there is major bugs and missing features. See the todo list.

Exqueue
=======

Simple and reliable background job library for [Elixir](http://elixir-lang.org/).

This job queue is designed to:

* Be very easy to use
* Automatically retry jobs a few times if they fail
* Limit concurrency when needed (for e.g. API calls)
* Notify about errors (by `Logger` errors, which can then be sent to services like [honeybadger](https://github.com/joakimk/honeybadger))
* Be able to retry or delete jobs manually
* Be able to see status by checking redis (iex for now, possible UI in the future)
* Handle app server restarts or crashes without loosing job data
* Fail on the side of running a job too many times rather than not at all. See more info below.

Currently limited to running jobs within a single erlang VM at a time for simplicity, though there is no reason it has to work that way in the future.

Uses redis to persist jobs but is **not** resque/sidekiq compatible. If you need that then I'd recommend you look at [Exq](https://github.com/akira/exq).

If **anything is unclear** about how this library works **that's considered a bug**, please file an issue (or a pull request)!

## Usage

Define a worker:

```elixir
    defmodule SendEmailWorker do
      # concurrency: infinite by default. For API calls it's often useful to limit it.
      use Exqueue.Worker, max_concurrency: 10

      def perform(to: to, title: title, text: text)
        # do work
      end
    end
```

Enqueue jobs somewhere in your app code:

```elixir
    Exqueue.enqueue(SendEmailWorker, to: "info@example.com", title: "Hello", text: "Hello, there!")
```

## Will jobs be run in order?

This is a first-in-first-out queue but due to retries and concurrency, ordering can not be guaranteed.

## How are jobs serialized?

Jobs are serialized using erlang serialization. This means you can pass almost anything to jobs, but just passing basic types is probably a good idea for compatibility with future code changes

## Can jobs be run on multiple computers at the same time?

No, but running multiple erlang vms on the same or different computers talking to the same redis server does not cause any unexpected behavior.

If the VM that runs jobs is killed, another one will try to take over.

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
* [ ] Avoid running duplicate jobs due to polling and current setup
* [ ] Review the code one more time
* [ ] Licence and pull request instructions

### 1.0

* [ ] Make the tests reliable.
* [ ] Keep a single-vm-lock in redis with a timeout, release it on exit. Support takeover for killed vms.
* [ ] Explore if a serialized erlang struct can be used by a codebase that does not have that module?
* [ ] Figure out if exredis can be supervised, maybe by wrapping it in a supervised worker
* [ ] Verify that enqueue worked, it may return a no connection error
* [ ] Custom and infinite max_concurrency
* Retries
  - [ ] A failed job will be automatically retried with a delay between each.
  - [ ] A failed job can be manually retried and/or deleted by running code in an iex prompt.
* [x] Re-queues jobs that exist in redis when it starts so that server crashes won't make you loose jobs.
  - [x] Make persistance abstract, don't assume redis
* [x] Errors will only be reported if retries fail.
* [ ] Consider renaming this since it's very hard to differentiate between exqueue and exq in spoken language
* [ ] Add CI
* [ ] Hex package

### Later

* [ ] More complete testing of JobSubscriber
* [ ] See if the pubsub can be made cleaner. Also support database numbers.
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.
* [ ] Find out why :eredis_sub.controlling_process makes the entire app shutdown when killed (or any part of it's linked processes dies). "[info]  Application exqueue exited: shutdown". Would allow us to keep it linked.

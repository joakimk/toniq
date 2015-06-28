# NOTE: Readme driven development below, this means this tool does not nessesaraly do what it says below yet. Using this to think though the design on a high level before coding.

Also, not sure if this idea will pan out, or if I find something that fullfills my goals somewhere else before then.

Exqueue
=======

Simple and reliable background job library for [Elixir](http://elixir-lang.org/).

This job queue is designed to:

* Be very easy to use
* Limit concurrency on jobs that need it (like when doing API calls to other apps)
* Retry jobs that fail automatically to avoid admin overhead
* Be notified if jobs fail too many times (by `Logger` errors, which can then be sent to services like [honeybadger](github.com/joakimk/honeybadger))
* Be able to retry or delete jobs that failed too many times manually
* Handle app server restarts or crashes without loosing job data
* Store just enough extra information in redis to make it possible to see status like currently running jobs (iex for now, possible UI in the future)
* Fail on the side of running a job too many times rather than not at all (jobs are assumed to be [reentrant](https://en.wikipedia.org/wiki/Reentrancy_(computing)))
* Gracefully handle failover if one of many erlang vms is killed

Currently limited to running jobs within a single erlang VM at a time for simplicity, though there is no reason it has to work that way in the future.

Uses redis to persist jobs but is **not** resque/sidekiq compatible. If you need that then I'd recommend you look at [Exq](https://github.com/akira/exq).

If **anything is unclear** about how this library works **that's considered a bug**, please file an issue (or a pull request)!

## Usage

Define a worker:

```elixir
    defmodule SendEmailWorker do
      def perform(to: to, title: title, text: text)
        # do work
      end
    end
```

When starting the app, start workers:

```elixir
    # One worker
    Exqueue.start_worker(SendEmailWorker)
    
    # Or 10 concurrent workers?
    # Exqueue.start_worker(SendEmailWorker, concurrency: 10)
```

Somewhere in your app code:

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

## TODO

### basic version

* [ ] Always store jobs in redis and have another process pull them out to support multiple erlang vms adding jobs, like when having multiple web servers
* [ ] Keep a single-vm-lock in redis with a timeout, release it on exit. Support takeover for killed vms.
* [ ] Enqueue and run jobs for different workers, but only one at a time for each.
* [ ] Re-queues jobs that exist in redis when it starts so that server crashes won't make you loose jobs.
  - [ ] Make persistance abstract, don't assume redis
  - [ ] Use in-memory persistance in tests?
* [ ] Will only mark a job as done if it exits successfully.
  - [ ] A failed job will be automatically retried with a delay between each.
  - [ ] A failed job can be manually retried and/or deleted by running code in an iex prompt.
* [ ] Errors will only be reported if retries fail.
* [ ] Licence and pull request instructions

### Later

* [ ] Explore if a serialized erlang struct can be used by a codebase that does not have that module?
* [ ] Can run multiple workers of the same type at the same time.
* [ ] If you only start one worker process for a job type, only one job will run at a time.
  - [ ] If configured to be serial it will not advance to the next job until the current one succeeds. This is useful when there are dependencies between jobs, like when registering an invoice, and then registering a payment on that invoice.
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.


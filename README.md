# NOTE: Readme driven development below, this means this tool does not nessesaraly do what it says below yet. Using this to think though the design on a high level before coding.

Also, not sure if this idea will pan out, or if I find something that fullfills my goals somewhere else before then.

Exqueue
=======

Simple, reliable and deterministic background job library for Elixir.

This job queue is designed to be able to:

* Limit concurrency on jobs doing API calls to other apps
* Retry jobs that fail automatically to avoid admin overhead
* Be notified if jobs fail too many times (by `Logger` errors), which can then be sent to services like [honeybadger](github.com/joakimk/honeybadger)
* Be able to retry or delete jobs that failed too many times manually
* Handle app server restarts or crashes without loosing job data
* Store just enough extra information in redis to make it possible to see the status like currently running jobs (iex for now, possible UI in the future)

Currently limited to running jobs within a single erlang VM for simplicity, though there is no reason it has to work that way in the future.

Uses redis to persist jobs but is **not** resque/sidekiq compatible. If you need that then I'd recommend you look at [Exq](https://github.com/akira/exq).

If **anything is unclear** about the lifecycle of a job or how to use this library **that's considered a bug**, please file an issue (or a pull request)!

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

## How it works

* When a job is enqueued
  - `Exqueue.enqueue` will only persist the job
* When a job is run
  - Jobs are always read from redis before they are run so that multiple erlang vms can enqueue jobs
  - It only runs as many jobs in parallel as specified with the `concurrent:` option per job type
    - A job type is defined by the worker name, ex. `SendEmailWorker`
* When a job succeeds
  - It's removed from persistance so that it won't be run again
* When a job fails the first 5 times it is retried, waiting 10 seconds between each time
* When a job still won't run after retrying
  - It's persisted in a way so that it won't be run again
  - It's reported as an error-level entry in the Elixir `Logger`
  - It can only be deleted by manual interaction, e.g. the queue will never automatically forget about a job
  - It can be manually re-queued as a new job
* When the app starts
  - It restores waiting jobs from redis if they exist

## The jobs are assumed to be reentrant!

You must ensure your jobs are [reentrant](https://en.wikipedia.org/wiki/Reentrancy_(computing)). This means they must be runnable more than once without any undesired sideeffects.

* Jobs will be run again if they fail as part of the retries feature
* The erlang process could be killed in the middle of running a job
* The redis connection could be lost when we need to report a job as finished
* etc...

In actual use most of the non-retry cases are very rare. It's probably okay if you send two emails if the redis connection was lost after the first time the job was run if that happens once a year.

## Will jobs be run in order?

* This is a first-in-first-out queue, so mostly yes, but not guaranteed
* If you have 5 as concurrency for a job type, then it will process the 5 oldest jobs at a time
  - If the jobs take different amounts of time to run (which they will), they will eventually be very much out of order
* If you have 1 as concurrency for a job type (the default), it will run in order as long as a job does not fail all retries
  - Keeping order would require stopping the queue and waiting for manual intervention. This is a potential future feature.
* Jobs of different types does not affect eachother, there is no ordering between them

## How are jobs serialized?

Jobs are serialized using erlang serialization. This means you can pass almost anything to jobs, but just passing basic types is probably a good idea for compatibility with future code changes

## Can jobs be run on multiple computers at the same time?

**Short answer:**

No, but running multiple erlang vms on the same or different computers talking to the same redis server does not cause any unexpected behavior.

**Long answer:**

For implementation simplicty and to guarantee the number of active workers per job type, only one erlang vm will run jobs at a time.

This is handled using locks in redis. If a vm goes missing, another running vm will take over as soon as possible.

Even if you think you only run one erlang VM at once, that is probably not true. During deploy you may have two versions of an app running for a short while, when debugging an issue you may have a iex prompt running in addition to a web server, etc.

One erlang VM can do a lot of work, and this basic implementation also supports failover. More advanced setups could be implemented in the future if needed.

## TODO: basic version

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

## TODO: Later

* [ ] Explore if a serialized erlang struct can be used by a codebase that does not have that module?
* [ ] Can run multiple workers of the same type at the same time.
* [ ] If you only start one worker process for a job type, only one job will run at a time.
  - [ ] If configured to be serial it will not advance to the next job until the current one succeeds. This is useful when there are dependencies between jobs, like when registering an invoice, and then registering a payment on that invoice.
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.


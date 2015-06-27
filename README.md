# NOTE: Readme driven development below, this means this tool does not nessesaraly do what it says below yet. Using this to think though the design on a high level before coding.

Also, not sure if this idea will pan out, or if I find something that fullfills my goals somewhere else before then.

Exqueue
=======

Simple, reliable and deterministic background job library for Elixir.

Based on years of experience working with background job queues and handling errors.

Uses redis to persist jobs.

If **anything is unclear** about the lifecycle of a job or how to use this library **that's considered a bug**, please file an issue (or a pull request)!

This is **not** a resque/sidekiq compatible queue, if you want something like that I'd recommend you look at [Exq](https://github.com/akira/exq).

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
    Exqueue.start_worker(SendEmailWorker)
    
    # if you want to process more than one job at a time, start more worker processes
    # Exqueue.start_worker(SendEmailWorker)
```    

Somewhere in your app code:

```elixir    
    Exqueue.enqueue(SendEmailWorker, to: "info@example.com", title: "Hello", text: "Hello, there!")
```

## How it works

* When a job is enqueued
  - It's persisted before anything is run
  - It will fail right away without persisting if there is no worker started for that job type
    - A job type is defined by the worker name, ex. `SyncToTranslationServiceWorker`
  - It only runs as many jobs in parallel as you have started worker processes for them
    - Ex: If you want max 5 outgoing requests to an API at one time, then you can start just 5 workers for that type of job
* When a job succeeds
  - It's removed from persistance so that it won't be run again
* When a job fails the first 5 times it is retried, waiting 30 seconds between each time
* When a job still won't run after retrying
  - It's persisted in a way so that it won't be run again
  - It's reported as an error-level entry in the Elixir `Logger`
  - It can only be deleted by manual interaction, e.g. the queue will never automatically forget about a job
  - It can be manually re-queued as a new job
* When the app starts
  - It restores waiting jobs from redis if they exist

## Will jobs be run in order?

* This is a first-in-first-out queue, so mostly yes but not guaranteed
* If you have 5 workers for a job type, then it will process the 5 oldest jobs at a time
  - if the jobs take different amounts of time to run (which they will), they will eventually be very much out of order
* If you have 1 worker for a job type, it will run in order as long as a job does not fail all retries
  - Keeping order would require stopping the queue and waiting for manual intervention. This is potential future feature.
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

## Gotchas

* If a job is running when the erlang process is killed, it will be run again when the app starts again. Ensure your jobs are [reentrant](https://en.wikipedia.org/wiki/Reentrancy_(computing)), or otherwise handles this.
  - You could in theory have some at\_exit hook to allow a job to finish, but that won't help you during a power outage or if the process is killed by a `KILL` signal, e.g. `kill -9`.
* A job can be retried more times than specified if the erlang process is stopped before it's done retying. Starting the app and re-queueing the job from redis will restart he retry count from 1 again.

## What I need now

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

## What I would want eventually

* [ ] Explore if a serialized erlang struct can be used by a codebase that does not have that module?
* [ ] Can run multiple workers of the same type at the same time.
* [ ] If you only start one worker process for a job type, only one job will run at a time.
  - [ ] If configured to be serial it will not advance to the next job until the current one succeeds. This is useful when there are dependencies between jobs, like when registering an invoice, and then registering a payment on that invoice.
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.


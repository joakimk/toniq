# NOTE: Readme driven development below, not sure if this idea will pan out, or if I find something that fullfills my goals somewhere else before then.

Exqueue
=======

Simple and reliable background job library for Elixir.

Uses redis to persist jobs. Jobs are serialized using erlang serialization so that you can pass almost anything to jobs.

Based on experience using other background job tools, I want a tool that is as simple as possible and designed for reliablity first. Less admin overhead that way.

## What I need now

* [ ] Enqueue and run jobs for different workers, but only one at a time for each.
* [ ] Re-queues jobs that exist in redis when it starts so that server crashes won't make you loose jobs.
  - [ ] Make persistance abstract, don't assume redis
  - [ ] Use in-memory persistance in tests?
* [ ] Will only mark a job as done if it exits successfully.
  - [ ] A failed job will be automatically retried with a delay between each.
  - [ ] A failed job can be manually retried and/or deleted by running code in an iex prompt.
* [ ] Errors will only be reported if retries fail.

## What I would want eventually

* [ ] Can run multiple workers of the same type at the same time.
* [ ] If you only start one worker process for a job type, only one job will run at a time.
  - [ ] If configured to be serial it will not advance to the next job until the current one succeeds. This is useful when there are dependencies between jobs, like when registering an invoice, and then registering a payment on that invoice.
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.

## Gotchas

* If a job is running when the erlang process is killed, it will be run again when the app starts again. Ensure your jobs are [reentrant](https://en.wikipedia.org/wiki/Reentrancy_(computing)), or otherwise handles this.
  - You could in theory have some at\_exit hook to allow a job to finish, but that won't help you during a power outage or if the process is killed by a `KILL` signal, e.g. `kill -9`.

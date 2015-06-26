# NOTE: Readme driven development below, not sure if this idea will pan out, or if I find something that fullfills my goals somewhere else before then.

Exqueue
=======

Simple and failsafe background job library for Elixir.

Based on experience using other background job tools, I want a tool that is as simple as possible and designed for safety first. Less admin overhead that way.

## What I need now

* [ ] Enqueue and run jobs using one worker for all jobs that can only run one job at a time.
* [ ] Re-queues jobs that exist in redis when it starts so that server crashes won't make you loose jobs.
* [ ] Will only mark a job as done if it exits successfully.
  - [ ] A failed job will be automatically retried with a delay between each.
  - [ ] A failed job can be manually retried and/or deleted by running code in an iex prompt.
* [ ] Errors will only be reported if retries fail.

## What I would want eventually

* [ ] Can run multiple jobs at the same time.
* [ ] If you only start one worker process for a job type, only one job will run at a time.
  - [ ] If configured to be serial it will not advance to the next job until the current one succeeds. This is useful when there are dependencies between jobs, like when registering an invoice, and then registering a payment on that invoice.
* [ ] A failed job can be automatically retried a configurable number of times with exponential backoff.

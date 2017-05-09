# sozu proxy

Modern techniques to write fast servers

# Intro

## Clever Cloud

## We built a reverse proxy

- hot reconfiguration
- should never ever stop
- can handle thousands of frontend configurations, and backend servers
- it's open source

## Technical details

- written in Rust
- uses the nom parser combinators library
- many to many relations between TLS certificates and frontend conf, between frontend conf and application, one to many between application and backend servers
- can upgrade TLS certificate while it's running
- you manage it through a Unix socket
- multiprocess architecture

## designed for speed and stability

## hot reconfiguration

- when you need a load balancer for a lot of backend servers
- with miroservices that change very often
- blue/green deployments
- you can know when to stop a backend server (ie, when the last active connection to that server closed)
- it takes configuration diffs as input, it does not reload the complete configuration (dropping the previous one) like most existing solutions

# what does it mean to be fast?

## latency, throughput and Little's law ( https://en.wikipedia.org/wiki/Little%27s_law#Finding_Response_Time )

- occupancy = latency * throughput (cf the water pipe example http://www.futurechips.org/chip-design-for-all/littles-law.html )
- the number of requests in flight is equal to the throughput (average request completion rate) multiplied by latency (average time a request stays in the system)
- augmenting throughput at same capacity => more requests handled concurrently => reduced latency
- reducing latency at same capacity => requests processed faster => augmenting throughput
- scaling horizontally => augmenting throughput but not latency: requests are processed as fast, but more of them are in flight
- if the system is at full capacity, what do you do with new requests?
  - start processing them with same throughput: augmenting latency for every request
  - enqueue them: trading more latency for those requests but keeping the others fast? No, latency in the queue will add up
  - drop them => back pressure

## users only care about the latency of their own request

- they don't care about how many requests are done concurrently on one or 100 machines
- they don't care about the latency of other requests

## latency, response time, service time

- service time: total time the system spends servicing the request (including data transfers)
- response time: service time + wait time (time spent waiting for various reasons)
- latency: sometimes seen as complete time between sending request and receiving response from the user's point of view, sometimes the time spent moving on the network

what we want when writing networking services: reducing service time and augmenting parallelism

why? wait time is when other requests are handled concurrently

- if the service time is 100 milliseconds, reducing it by 10 allows one more request per second
- if work is done in parallel queues, their wait time might not affect each other (assuming they're separated)
- wait time is also related to calls to other services, on which we won't have any effect

we can't improve network latency or wait time for third party services in the code (well, it depends), it's work left to the ops

=> add a graph for multiple requests showing network latency, time to start servicing request, task switching delay, wait time while another task is handled

## difference between averages and percentile

we don't want to only have a good average performance
we also want to have low variance (show examples of systemms with good average response time but awful outliers)
side note: in an adversarial setting (security, etc), people will exploit the worst case over and over, even if it's usually rare (example: slowloris attack, and hashmap attacks)

we want to put a bound on the worst case response time => a request that is refused quickly is better than a timeout

## How to measure? What do we measure?

- measuring one data point? how many requests per second with one server sending requests?
- measuring average latency?

=> show graphs of frequency response in signal processing

we're in engineering, we want to know the limits of the system, especially when it fails

Fix some parameters for one measurement set:
- machine size
- how many processes, threads, etc
- request size
- network latency (don't remove it completely by working on localhost, transfer times affect everything)

for each set of parameters do a serie of measurements:
- fix the number of concurrent requests, measure response time  (percentiles) and count timeouts
- augment the number of concurrent requests, measure again, and again, until the server starts failing (ie errors, timeouts, and response time increasing greatly)

going back to little's law:

here, nb of concurrent requests = nb of requests in flight in server + nb of refused requests (timeout and others)

=> as we augment the nb of concurrent requests, the throughput of the system should augment faster than latency, then at some point the latency will augment faster than throughput
(the higher percentile timings might increase first)

do that for different set of parameters

# Server architecture

## up to the C10k problem

historical techniques: forking model, prefork, multithread (one thread per request)
select, poll, epoll models

one process or one thread per request was easy to write: blocking IO model
but processes and threads are costly (in memory) and switching between them is costly (CPU, cache)

epoll became the fastest option: register a list of sockets to the OS, let the OS tell you when you can read or write on which sockets
epoll is for single threaded servers, but you can run epoll loops in multiple threads or processes
SO_REUSEPORT: available in Linux 3.9, since 2013

with this architecture, we only work when there's something to do with the sockets.
epoll will allow interleaving work: read from one socket, parse it, send to backend, read from another, now read from the first backend socket, send to frontend

## Why do we want to reduce switching between threads or process?

It's time for some CPU architecture \o/

show modern CPU architecture: cores, bus, caches

show timings for cache loading, reading from RAM, network, disk

switching between threads on a single core means loading the new thread's data in the cache if it's not there, and this takes time

moving a thread from one core to another takes even more time

multiple threads accessing the same data means the cores must synchronize their caches, and this takes a lot of time too

=> that's why you want the following:
- single thread architecture: everything happens in one thread, you can parallelize on multiple threads, but with no (or very low) interaction between them
- one thread per core, so threads don't fight for processing time (and switch contexts). keep one core for the kernel, though
- use core affinity: if the threads jumped from one core to another, you need to reload the caches
- for data shared between processes and thread, use message queues and immutable data. Immutable data does not need to be synchronized

program performance is dominated by cache misses (Cliff Click, Devoxx.be 2016)


## going further: multiqueue NICs

some network cards can have per core packet queues: every packet for one TCP connection go to the same core
with this single thread architecture, we can use those network cards efficiently

# making a stable and fast service

anything that augments service time will affect all the requests in flight, and will delay new requests

## garbage collection is garbage

that's why garbage collection is such a big issue. Your system can be quite responsive most of the time, but if it is stopping processing to do garbage collection,
then wait time increases for every request.

a lot has been invested to make GC faster, especially in Go. But it still has a cost: going through objects (ie, loading them into the cache).
warning: potential trolling point here, might get grilled in the Q&A

for a network service like a proxy, garbage collection makes no sense: we don't create a lot of objects per request, and it's very regular.
an object pool and/or buffer pool is much better for our use cases

Rust has no garbage collection, it handles memory allocation and deallocation where it's needed

## control plane VS data plane

in telecoms, they viewed separately the control plane (SW and HW that chooses how to route data) and the data plane (where data effectively moves)

in a reverse proxy, we're on the control plane, we should not see much of the data plane
ie, we should see the HTTP headers and the chunk headers, but not the rest of the content

what happens in most systems:
- read data from front socket into kernel buffer
- read headers from kernel buffer into front buffer
- parse headers from buffer to an object
- write object to back buffer
- write back buffer to back kernel buffer
- write back kernel buffer to back socket
- read body from front kernel buffer to buffer
- maybe copy body from front to back buffer
- write back buffer to back kernel buffer
- write back kernel buffer to back socket

what will happen in sozu (once splicing gets stable):
- read data from front socket into kernel buffer
- read headers from kernel buffer into front buffer
- parse headers from buffer to an object
- write header chunks from front buffer to back kernel buffer
- write back kernel buffer to back socket
- copy body from front kernel buffer to back kernel buffer
- write back kernel buffer to back socket

less copies, less context switching between kernel space and user space

currently, the proxy uses only one userspace buffer per request

## trying to guarantee stable behaviour: bounds on in flight requests

put a hard limit on the number of concurrent requests the server can handle

why? because resources are limited. If we use more than the available RAM, the server will start swapping to disk (or worse, the OOM killer will jump on us)
by specifying a hard limit, we can put a bound on the service time, and have low variance



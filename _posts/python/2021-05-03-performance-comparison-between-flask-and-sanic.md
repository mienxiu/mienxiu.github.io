---
title: Peformance Comparison between Flask and Sanic
category: python
toc: true
toc_sticky: true
post_no: 2
---
## Flask and Sanic
**[Flask](https://github.com/pallets/flask)** is one of the most popular micro web frameworks written in Python and I love using it for developing a wide range of web services because of its simplicity and flexibility.
And it's also amazingly extensible thanks to the various plugins.

**[Sanic](https://github.com/sanic-org/sanic)**, meanwhile, is relatively a new framework that allows Python's `async/await` syntax added in Python 3.5.
It's an asynchronous web framwork whereas Flask is synchronous.

I did some simple benchmarking of two frameworks to demonstrate how much asynchronous servers outperform synchronous servers in dealing with I/O-bound workloads.
But first,

## What is Asynchronous Programming?
Long story short, asynchronous programming is a style of programming that allows your code to run concurrently using a **cooperative(or non-preemptive) multitasking**.
This is achieved by having an **event loop** that schedules multiple tasks or **coroutines**.
As this topic requires its own in-depth understanding, I will leave it to [the other post](https://realpython.com/async-io-python/). (I enjoyed reading it though.)

Do not confuse between concurrency and parallelism.
While coroutines can be scheduled concurrently, they don't run in parallel.
{: .notice--warning}

In the context of web servers, using asynchronous approach can solves a problem of **blocking I/O** by thread-based approach (preemptive).
I'm going to focus on how much better Sanic can handle I/O requests then Flask.

## Performance Comparison
The benchmark here is to simply compare the performance in handling I/O-bound and CPU-bound requests in a fairly controlled environment.
In real world, there are many variables that can affect the results so developers should consider as many aspects as possible when making a design decision.
{: .notice--info}

### Test Environment
For a test machine:
* Core: 1
* Memory: 1 GB
* OS: Ubuntu 20.04 LTS
* Python: 3.9.4

For I/O-bound workloads, the server will simulate the image upload task with the following conditions:
* An upload takes from 100 to 200 milliseconds.
* The maximum number of connections is 5.

For CPU-bound workloads, the server will just do some heavy math calculation - hammering the CPU, so to speak.

For a client, I'm going to use `ab`, a single-threaded Apache HTTP server benchmarking tool.

The complete code for this test looks like this:
```python
"""Flask"""
from random import randint
from time import sleep
from threading import Semaphore

from flask import Flask
from flask import jsonify

class ImageUploader:
    """A singletone class of image uploader."""
    def __init__(self, maxconn: int = 5):
        self.lock = Semaphore(maxconn)

    def upload(self):
        with self.lock:
            sleep(randint(100, 200) / 1000)
            print("Image has been uploaded.")

app = Flask(__name__)

image_uploader = ImageUploader()

# I/O-bound endpoint.
@app.route("/upload", methods=["POST"])
def upload():
    image_uploader.upload()
    return jsonify({"success": True})

# CPU-bound endpoint.
@app.route("/calc", methods=["GET"])
def calc():
    result = sum([i ** 2 for i in range(1000000)])
    return jsonify({"result": result})

if __name__ == "__main__":
    app.run(threaded=False)  # Disable threaded mode.
```
Flask, by default, runs in threaded mode.
For fair competition, this mode is disabled by explicitly set `threaded=False`.
{: .notice--info}
```python
"""Sanic"""
from random import randint
from asyncio import sleep
from asyncio import Semaphore

from sanic import Sanic
from sanic.response import json

class ImageUploader:
    """A singletone class of image uploader."""
    def __init__(self, maxconn: int = 5):
        self.lock = Semaphore(maxconn)

    async def upload(self):
        async with self.lock:
            await sleep(randint(100, 200) / 1000)
            print("Image has been uploaded.")

app = Sanic(__name__)

@app.listener("after_server_start")
async def setup_image_uploader(app, loop):
    app.ctx.image_uploader = ImageUploader()

# I/O-bound endpoint.
@app.route("/upload", methods=["POST"])
async def upload(request):
    await app.ctx.image_uploader.upload()
    return json({"result": True})

# CPU-bound endpoint.
@app.route("/calc", methods=["GET"])
async def calc(request):
    result = sum([i ** 2 for i in range(1000000)])
    return json({"result": result})

if __name__ == "__main__":
    app.run()
```
Note that `upload()` method in Sanic looks different from that in Flask as it can benefit from `async/await` syntax.

Let's test both by using `ab` command. To send 10 concurrent POST requests to `/upload`, here's how to do:
```bash
$ ab -n 10 -c 10 -m POST http://127.0.0.1/upload
```

### Result 1 (I/O-bound)
<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
<script src="/assets/js/charts/2-chart0.js"></script>
<div id="chart0"></div>

We can see that the more concurrent requests, the remarkably better Sanic can perform.
For instance, with 50 concurrent requests, Flask took 7.33 seconds (6.8 RPS) and Sanic took 1.73 seconds (28.9 RPS) to complete.

This is because `sleep()` in Flask is **a blocking call** so that the thread is blocked from continuing to run while it waits for the `sleep()` call.
On the other hand, `await sleep()` in Sanic is **a non-blocking call**. It means that the execution context can be switched to the other task, allowing the thread can run the other request and continue working on the first `sleep()` call later.

In real world applications, the result differs depending on the network environment, the remote server's capacity and other things, but still, asynchronous servers can handle a lot more I/O requests in comparison to synchronous servers.

For Flask to concurrently handle multiple I/O-bound requests, spawning more threads could be an option. This can be done by `threaded=True`.
Let's benchmark with `threaded` mode.

<script src="/assets/js/charts/2-chart1.js"></script>
<div id="chart1"></div>

Now Flask seems to be competing with Sanic. But how about memory consumption?

<script src="/assets/js/charts/2-chart2.js"></script>
<div id="chart2"></div>

The vertical axis represents the total amount of virtual memory in MB used by the application.
The more threads Flask spawns, the more extra memory space those new threads require.
Again, single-threaded coroutines do not require these extra resources.

### Result 2 (CPU-bound)
<script src="/assets/js/charts/2-chart3.js"></script>
<div id="chart3"></div>

The result is pretty much the same as what I expected. As both applications run on limited computation power, there's no meaningful difference between them.
The number of threads and cores would really matter in this case. (Let's not discuss GIL here.)

## Use Cases of Sanic
I've used Sanic in production services with some libraries that support asynchronous features in Python. Here are some of them and the code snippets too.

### aioboto3
[aioboto3](https://github.com/terrycain/aioboto3) is mostly a wrapper combining [boto3](https://github.com/boto/boto3) and [aiobotocore](https://github.com/aio-libs/aiobotocore).
It allows Python programmers use AWS services in an asynchronous manner.
Look at the example code below:
```python
from sanic import Sanic
from sanic.response import json
import aioboto3

app = Sanic(__name__)

@app.route("/images", methods=["POST"])
async def upload_image(request):
    image = request.files["image"][0]
    async with aioboto3.resource("s3") as s3:
        bucket = await s3.Bucket("my-bucket")
        await bucket.put_object(Key="key", Body=image.body)
    return json({"success": True})

if __name__ == "__main__":
    app.run()
```

### aioredis
[aioredis](https://github.com/aio-libs/aioredis-py) provides an interface to [Redis](https://redis.io/) based on asyncio.
One of use cases for Redis is caching and here's the code snippet:
```python
from sanic import Sanic
from sanic.response import json
from aioredis import create_redis_pool

app = Sanic(__name__)

REDIS_URI = "redis://127.0.0.1"

async def setup_db(app, loop):
    app.ctx.db = await create_redis_pool(REDIS_URI, loop=loop)

async def close_db(app, loop):
    app.ctx.db.close()
    await app.db.wait_closed()

app.register_listener(setup_db, "before_server_start")
app.register_listener(close_db, "after_server_stop")

@app.route("/cache", methods=["GET"])
async def get_cache(request):
    key = request.args.get("key")
    cached_data = await app.ctx.db.get(key, encoding="UTF-8")
    return json({"data": cached_data})

if __name__ == "__main__":
    app.run()
```
A takeway from this example is that you create a pool of connections before the server starts.
This way, you don't create a new database connection for every request.
It also gracefully closes the database after the server stops by calling `close_db()`.

## Conclusion
With asynchronous web servers, you can achieve a better throughput in handling multiple I/O requests more efficiently by not having to wait the I/O task before handling the next request.

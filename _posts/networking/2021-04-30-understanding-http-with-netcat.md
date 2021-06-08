---
title: Understanding HTTP with netcat
category: networking
toc: true
toc_sticky: true
post_no: 1
---
Any web developer would know about HTTP buy may not be familiar with the exact syntax of it because it's abstracted by the network libraries.

HTTP is just a **protocol** which a client and a server use for data communication.
In order to comply with this protocol, every HTTP message should be formed in accordance with [a certain standard](https://tools.ietf.org/html/rfc7230).

In this post, I'm going to give a brief overview of **HTTP messages**, and build a simple web server with **netcat**.

## HTTP Messages
There are two types of HTTP messages, requests and responses. Each has its own format.
### Requests
An example HTTP request message:
```
GET / HTTP/1.1
Host: google.com
```
* `GET`: Method.
* `/`: Path.
* `HTTP/1.1`: The Protocol version.
* `Host: google.com`: Headers.
* Body. (optional for some methods like `POST` or `PUT`)

### Responses
An example HTTP response message:
```
HTTP/1.1 301 Moved Permanently
Location: http://www.google.com/

<HTML>301 Moved</HTML>
```
* `HTTP/1.1`: The Protocol version.
* `301`: Status code.
* `Moved Permanently`: Status message.
* `Location: http://www.google.com/`: Headers.
* `<HTML>301 Moved</HTML>`: Body.

## netcat
**netcat** is a networking utility for sending and listening packets using TCP or UDP connections.
The command is `nc`. For more information, run `man nc`.

To test the both server and client models, I'm going to use two terminals - term1 and term2.
### Server Model
On term1, start `nc` listening on port 80 which is a typical port number for HTTP.
```sh
# term1
$ nc -l 80
```
### Client Model
On term2, connect to the machine of term1.
```sh
# term2
$ nc 127.0.0.1 80
```
Now a connection between the port 80 has been made, you can send any text message from both terminals.
For example, send `hello world` from term1, then in term2, you will see the message received from term1.
```sh
# term1
$ nc -l 80
hello world
```
```sh
# term2
$ nc 127.0.0.1 80
hello world
```
### Sending HTTP request messages using netcat
Using netcat, you can actually send HTTP messages in pure text.
No browser, no library, no programming.
Let's send the same HTTP request in [the example above](#requests).
```sh
$ nc google.com 80
GET / HTTP/1.1
Host: google.com

HTTP/1.1 301 Moved Permanently
Location: http://www.google.com/
Content-Type: text/html; charset=UTF-8
Date: Sat, 01 May 2021 04:32:47 GMT
Expires: Mon, 31 May 2021 04:32:47 GMT
Cache-Control: public, max-age=2592000
Server: gws
Content-Length: 219
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN

<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="http://www.google.com/">here</A>.
</BODY></HTML>
```
You will get an HTTP response message with a bunch of headers and body from google server.
The other way of sending the same HTTP request is:
```sh
$ printf 'GET / HTTP/1.1\r\nHost: google.com\r\n\r\n' | nc google.com 80
```
Note that there is a blank line(`\r\n`) at the end of the message.
It indicates all information for the request has been sent.

## Buliding a web server using netcat
Let's run a simple web server using netcat and connect to it with a web browser.
The web server in this example will redirect any incomming request to `https://google.com`.
```sh
$ printf 'HTTP/1.1 302 Moved\r\nLocation: https://google.com/' | nc -l 80
```
Then open the web broswer and connect to `127.0.0.1` or `localhost`.
The browser will redirects to `https://google.com` and the HTTP request that the browser sent is printed on the console.
```sh
$ printf 'HTTP/1.1 302 Moved\r\nLocation: https://google.com/' | nc -l 80
GET / HTTP/1.1
Host: 127.0.0.1
Connection: keep-alive
...
```
The request messages may differ depending on which web browser you use.
{: .notice--info}

## Conclusion
An important takeaway here is that netcat doesn't know anything about HTTP layer.
It just opens a connection to a port and sends a sequence of characters - a string - over TCP layer.
It is the web server that decides whether the information is a valid HTTP request or not and responds to it, and that is the **protocol**.
This simple and intuitive demonstration gave me a clearer understanding of how HTTP works.

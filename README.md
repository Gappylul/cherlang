# Erlang OTP Chat Server

A simple TCP chat server written in **Erlang** using **OTP principles**.  
Each client is a supervised `gen_server` process, messages are broadcast to all clients, and join/leave events are announced.

---

## Features

- Username-based chat (clients choose a username on connect)  
- Broadcast messages to all connected clients  
- Join/leave notifications  
- OTP-compliant: `gen_server` for server & clients, supervised under `chat_sup`  
- Robust against client crashes  

---

## Project Structure

---

## Requirements

- Erlang/OTP 28+  
- `rebar3` for building and running  

---

## Installation

Clone the repo:

```sh
git clone https://github.com/Gappylul/cherlang.git
cd cherlang
```
Compile the project using `rebar3`:
```sh
rebar3 compile
```

---

## Running the Server

Start a shell with the project loaded:
```sh
rebar3 shell
```
You should see:
```nginx
Chat server listening on port 4040
```
If for some reason you don't:
```erlang
1> application:start(chat).
```

---

## Connecting as a Client

Use **telnet** or **netcat**:
```sh
telnet localhost 4040
# or
nc localhost 4040
```

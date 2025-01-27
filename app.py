#!/usr/bin/python

# app.py
import time
from flask import Flask

app = Flask(__name__)

START = time.time()
def elapsed():
    running = time.time() - START
    minutes, seconds = divmod(running, 60)
    hours, minutes = divmod(minutes, 60)
    return "%d:%02d:%02d" % (hours, minutes, seconds)

@app.route('/')
def home():
    return "Hello World (Python)! (up %s)\n" % elapsed()


if __name__ == "__main__":
    app.run()
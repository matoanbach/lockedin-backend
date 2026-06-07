import multiprocessing
import os


bind = os.getenv("BIND", "0.0.0.0:8000")

default_workers = multiprocessing.cpu_count() * 2 + 1
workers = int(os.getenv("WORKERS", default_workers))

worker_class = os.getenv("WORKER_CLASS", "uvicorn.workers.UvicornWorker")
timeout = int(os.getenv("TIMEOUT", "30"))

loglevel = os.getenv("LOGLEVEL", "info")
capture_output = True
accesslog = "-"
errorlog = "-"

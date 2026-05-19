from redis import Redis
from rq import Queue, Worker

from app.core.config import get_settings

QUEUE_NAME = "design_jobs"


def get_queue() -> Queue:
    return Queue(QUEUE_NAME, connection=Redis.from_url(get_settings().redis_url))


def main() -> None:
    worker = Worker([get_queue()], connection=Redis.from_url(get_settings().redis_url))
    worker.work()


if __name__ == "__main__":
    main()


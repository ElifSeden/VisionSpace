from redis import Redis
from rq import Queue, Worker

from app.core.config import get_settings
from app.storage.local_storage import LocalImageStorage

QUEUE_NAME = "design_jobs"


def get_queue() -> Queue:
    return Queue(QUEUE_NAME, connection=Redis.from_url(get_settings().redis_url))


def main() -> None:
    settings = get_settings()
    LocalImageStorage(settings)
    worker = Worker([get_queue()], connection=Redis.from_url(settings.redis_url))
    worker.work()


if __name__ == "__main__":
    main()


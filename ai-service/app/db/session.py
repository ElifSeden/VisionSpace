from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings


class Base(DeclarativeBase):
    pass


_engine: Engine | None = None


def get_engine() -> Engine:
    global _engine
    if _engine is None:
        _engine = create_engine(get_settings().database_url, pool_pre_ping=True)
    return _engine


SessionLocal = sessionmaker(autocommit=False, autoflush=False, expire_on_commit=False)


def new_session() -> Session:
    return SessionLocal(bind=get_engine())


def get_db() -> Generator[Session, None, None]:
    db = new_session()
    try:
        yield db
    finally:
        db.close()

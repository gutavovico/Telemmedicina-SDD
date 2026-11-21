"""Motores de base de datos de la plataforma.

CU29 incorpora el estándar asíncrono (`AsyncSession`) para código nuevo sin
retirar el motor síncrono legado: las rutas existentes siguen usando `get_db`
mientras el módulo `doctor_entity_links` usa `get_async_db`.
"""
from typing import AsyncGenerator, Generator

from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from app.core.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()


def _async_database_url(url: str) -> str:
    """Deriva la URL asíncrona desde `settings.DATABASE_URL`.

    No se duplican credenciales en configuración: solo se sustituye el driver.
    `psycopg` ya forma parte de `requirements.txt` y se conserva el motor
    síncrono legado durante la transición.
    """
    if url.startswith("postgresql+psycopg2://"):
        return "postgresql+psycopg://" + url[len("postgresql+psycopg2://"):]
    if url.startswith("postgresql://"):
        return "postgresql+psycopg://" + url[len("postgresql://"):]
    if url.startswith("sqlite://"):
        return "sqlite+aiosqlite://" + url[len("sqlite://"):]
    return url


async_engine = create_async_engine(
    _async_database_url(settings.DATABASE_URL),
    pool_pre_ping=True,
)

AsyncSessionLocal = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


def get_db() -> Generator[Session, None, None]:
    """Dependency for obtaining a database session in endpoints."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependencia asíncrona para el código nuevo (CU29)."""
    async with AsyncSessionLocal() as session:
        yield session

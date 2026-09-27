from fastapi import APIRouter

import db

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, str]:
    """Reports the database too — a server that is up but cannot reach
    MongoDB serves nothing useful, and this is what tells you which it is."""
    database_ok = await db.ping()
    return {
        "status": "ok" if database_ok else "degraded",
        "database": "ok" if database_ok else "unreachable",
    }

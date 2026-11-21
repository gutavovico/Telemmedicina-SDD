"""CU36 notices and cycle close worker; never invokes the CU31 cycle executor."""
import logging

from app.core.database import SessionLocal
from .service import close_due_cycles, evaluate_open_cycles, _cu36_env

logger = logging.getLogger(__name__)
scheduler = None


def run_once(session_factory=SessionLocal):
    with session_factory() as db:
        try:
            notices = evaluate_open_cycles(db)
            closed = close_due_cycles(db)
            return {"evaluated": notices, "closed": closed}
        except Exception:
            db.rollback()
            logger.exception("CU36 worker run failed")
            raise


def start():
    global scheduler
    enabled = _cu36_env("BILLING_CU36_WORKER_ENABLED", "true").lower() in ("1", "true", "yes", "on")
    if not enabled or scheduler is not None:
        return
    from apscheduler.schedulers.background import BackgroundScheduler
    scheduler = BackgroundScheduler(timezone="UTC")
    scheduler.add_job(run_once, "interval", seconds=300, id="billing-cu36",
                      max_instances=1, coalesce=True)
    scheduler.start()


def stop():
    global scheduler
    if scheduler is not None:
        scheduler.shutdown(wait=False)
        scheduler = None

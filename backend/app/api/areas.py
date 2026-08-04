from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.security import CurrentUser, get_current_user

router = APIRouter(prefix="/areas", tags=["areas"])
User = Annotated[CurrentUser, Depends(get_current_user)]

_PILOT_WARDS = [
    "Anifowoshe/Ikeja",
    "Ojodu/Agidingbi/Omole",
    "Alausa/Oregun/Olusosun",
    "Airport/Onipetesi/Inilekere",
    "Ipodo/Seriki Aro",
    "Adekunle Village/Adeniyi Jones/Ogba",
    "Oke-Ira/Aguda",
    "Onigbongbo",
    "GRA/Police Barracks",
    "Wasimi/Opebi/Allen",
]


@router.get("/states", response_model=list[str])
def states(_: User) -> list[str]:
    if get_settings().use_in_memory_store:
        return ["Lagos"]
    with get_session_factory()() as session:
        return list(
            session.execute(text("SELECT DISTINCT state FROM lga_wards ORDER BY state")).scalars()
        )


@router.get("/lgas", response_model=list[str])
def lgas(_: User, state: str = Query(min_length=2, max_length=50)) -> list[str]:
    if get_settings().use_in_memory_store:
        return ["Ikeja"] if state == "Lagos" else []
    with get_session_factory()() as session:
        return list(
            session.execute(
                text("SELECT DISTINCT lga FROM lga_wards WHERE state = :state ORDER BY lga"),
                {"state": state},
            ).scalars()
        )


@router.get("/wards", response_model=list[str])
def wards(
    _: User,
    state: str = Query(min_length=2, max_length=50),
    lga: str = Query(min_length=2, max_length=100),
) -> list[str]:
    if get_settings().use_in_memory_store:
        return _PILOT_WARDS if state == "Lagos" and lga == "Ikeja" else []
    with get_session_factory()() as session:
        return list(
            session.execute(
                text(
                    "SELECT ward FROM lga_wards "
                    "WHERE state = :state AND lga = :lga ORDER BY ward"
                ),
                {"state": state, "lga": lga},
            ).scalars()
        )

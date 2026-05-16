from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse

from models.exam_session import EndExamRequest, StartExamRequest
from services.exam_session_service import (
    end_exam_session,
    get_active_session,
    get_session_details,
    start_exam_session,
)

router = APIRouter(prefix="/exam", tags=["exam"])


@router.post("/start")
def start_exam(payload: StartExamRequest):
    if not payload.classroom_id.strip() or not payload.exam_name.strip() or not payload.started_by.strip():
        raise HTTPException(status_code=400, detail="classroom_id, exam_name and started_by are required.")
    try:
        session = start_exam_session(
            classroom_id=payload.classroom_id.strip(),
            exam_name=payload.exam_name.strip(),
            started_by=payload.started_by.strip(),
        )
        return {"message": "Monitoring session started", "session": session}
    except ValueError as exc:
        if str(exc) == "ACTIVE_SESSION_EXISTS":
            active = get_active_session(payload.classroom_id.strip())
            return JSONResponse(
                status_code=409,
                content={
                    "message": "An active exam session already exists.",
                    "session": active,
                },
            )
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/end")
def end_exam(payload: EndExamRequest):
    if not payload.session_id.strip() or not payload.ended_by.strip():
        raise HTTPException(status_code=400, detail="session_id and ended_by are required.")
    try:
        session = end_exam_session(
            session_id=payload.session_id.strip(),
            ended_by=payload.ended_by.strip(),
        )
        return {"message": "Monitoring session ended", "session": session}
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/active/{classroom_id}")
def get_active_exam(classroom_id: str):
    session = get_active_session(classroom_id)
    if not session:
        return {"session": None}
    return {"session": session}


@router.get("/session/{session_id}")
def get_exam_session(session_id: str):
    session = get_session_details(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"session": session}

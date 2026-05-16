from fastapi import APIRouter, HTTPException

from models.classroom import ClassroomCreateRequest, ClassroomJoinRequest
from services.classroom_service import (
    create_classroom,
    get_classroom_by_id,
    get_teacher_classrooms,
    join_classroom,
)

router = APIRouter(prefix="/classrooms", tags=["classrooms"])


@router.post("/create")
def create_classroom_route(payload: ClassroomCreateRequest):
    if not payload.classroom_name.strip():
        raise HTTPException(status_code=400, detail="classroom_name is required.")
    if not payload.created_by.strip():
        raise HTTPException(status_code=400, detail="created_by is required.")

    classroom = create_classroom(payload.classroom_name.strip(), payload.created_by.strip())
    return {"message": "Classroom created successfully", "classroom": classroom}


@router.post("/join")
def join_classroom_route(payload: ClassroomJoinRequest):
    if not payload.firebase_uid.strip():
        raise HTTPException(status_code=400, detail="firebase_uid is required.")
    if not payload.classroom_code.strip():
        raise HTTPException(status_code=400, detail="classroom_code is required.")

    try:
        classroom = join_classroom(payload.firebase_uid.strip(), payload.classroom_code.strip())
        return {"message": "Joined classroom as teacher", "classroom": classroom}
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/teacher/{firebase_uid}")
def get_teacher_classrooms_route(firebase_uid: str):
    classrooms = get_teacher_classrooms(firebase_uid)
    return {"classrooms": classrooms}


@router.get("/{classroom_id}")
def get_classroom_route(classroom_id: str):
    classroom = get_classroom_by_id(classroom_id)
    if not classroom:
        raise HTTPException(status_code=404, detail="Classroom not found")
    return {"classroom": classroom}

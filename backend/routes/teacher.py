from fastapi import APIRouter, HTTPException

from models.teacher import TeacherProfile
from services.teacher_service import create_teacher, get_teacher_by_uid

router = APIRouter(prefix="/teachers", tags=["teachers"])


@router.post("/create")
def create_teacher_profile(teacher_data: TeacherProfile):
    try:
        if not teacher_data.firebase_uid or not teacher_data.email or not teacher_data.name:
            raise HTTPException(
                status_code=400,
                detail="firebase_uid, email and name are required.",
            )

        result = create_teacher(teacher_data)
        if result["status"] == "exists":
            return {"message": "Teacher profile already exists"}
        return {"message": "Teacher profile created successfully"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/{firebase_uid}")
def get_teacher_profile(firebase_uid: str):
    teacher = get_teacher_by_uid(firebase_uid)
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    return {"success": True, "teacher": teacher}

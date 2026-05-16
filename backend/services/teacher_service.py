from datetime import datetime
from typing import Any, Dict, Optional

from db.database import teachers_collection
from models.teacher import TeacherProfile


def _serialize_teacher(teacher_doc: Dict[str, Any]) -> Dict[str, Any]:
    teacher_doc.pop("_id", None)
    created_at = teacher_doc.get("created_at")
    if isinstance(created_at, datetime):
        teacher_doc["created_at"] = created_at.isoformat()
    return teacher_doc


def get_teacher_by_uid(firebase_uid: str) -> Optional[Dict[str, Any]]:
    teacher_doc = teachers_collection.find_one({"firebase_uid": firebase_uid})
    if not teacher_doc:
        return None
    return _serialize_teacher(teacher_doc)


def create_teacher(teacher_data: TeacherProfile) -> Dict[str, Any]:
    existing = get_teacher_by_uid(teacher_data.firebase_uid)
    if existing:
        return {"status": "exists"}

    teacher_dict = teacher_data.model_dump()
    teacher_dict["created_at"] = datetime.utcnow()
    teachers_collection.insert_one(teacher_dict)
    return {"status": "created"}

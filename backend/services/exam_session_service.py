from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import uuid4

from db.database import classrooms_collection, exam_sessions_collection, notifications_collection
from models.exam_session import ExamSession
from services.student_service import get_student_ids_for_classroom


def _serialize_exam_session(session_doc: Dict[str, Any]) -> Dict[str, Any]:
    session_doc.pop("_id", None)
    for key in ("start_time", "end_time", "created_at"):
        value = session_doc.get(key)
        if isinstance(value, datetime):
            session_doc[key] = value.isoformat()
    return session_doc


def get_active_session(classroom_id: str) -> Optional[Dict[str, Any]]:
    session_doc = exam_sessions_collection.find_one(
        {"classroom_id": classroom_id, "status": "active"}
    )
    if not session_doc:
        return None
    return _serialize_exam_session(session_doc)


def start_exam_session(classroom_id: str, exam_name: str, started_by: str) -> Dict[str, Any]:
    active_session = get_active_session(classroom_id)
    if active_session:
        raise ValueError("ACTIVE_SESSION_EXISTS")

    classroom = classrooms_collection.find_one({"classroom_id": classroom_id})
    if not classroom:
        raise ValueError("Classroom not found.")

    if started_by not in classroom.get("teachers", []):
        raise ValueError("Only classroom teacher can start monitoring.")

    monitored_students = get_student_ids_for_classroom(classroom_id)

    session = ExamSession(
        session_id=str(uuid4()),
        classroom_id=classroom_id,
        exam_name=exam_name,
        started_by=started_by,
        start_time=datetime.utcnow(),
        monitored_students=monitored_students,
    )
    session_dict = session.model_dump()
    exam_sessions_collection.insert_one(session_dict)
    return _serialize_exam_session(session_dict)


def end_exam_session(session_id: str, ended_by: str) -> Dict[str, Any]:
    session_doc = exam_sessions_collection.find_one({"session_id": session_id})
    if not session_doc:
        raise ValueError("Session not found.")

    classroom = classrooms_collection.find_one({"classroom_id": session_doc.get("classroom_id")})
    if not classroom or ended_by not in classroom.get("teachers", []):
        raise ValueError("Only a classroom teacher can end this session.")

    if session_doc.get("status") != "active":
        raise ValueError("This session is not active.")

    exam_sessions_collection.update_one(
        {"session_id": session_id},
        {"$set": {"status": "completed", "end_time": datetime.utcnow()}},
    )
    updated_doc = exam_sessions_collection.find_one({"session_id": session_id})
    if not updated_doc:
        raise ValueError("Session not found after update.")
    return _serialize_exam_session(updated_doc)


def get_session_details(session_id: str) -> Optional[Dict[str, Any]]:
    session_doc = exam_sessions_collection.find_one({"session_id": session_id})
    if not session_doc:
        return None
    return _serialize_exam_session(session_doc)


def get_classroom_exam_history(classroom_id: str) -> List[Dict[str, Any]]:
    sessions = exam_sessions_collection.find({"classroom_id": classroom_id}).sort("start_time", -1)
    history: List[Dict[str, Any]] = []
    for session_doc in sessions:
        session = _serialize_exam_session(session_doc)
        alerts_count = notifications_collection.count_documents({"session_id": session["session_id"]})
        session["total_alerts_count"] = alerts_count
        session["suspicious_activity_count"] = alerts_count
        history.append(session)
    return history

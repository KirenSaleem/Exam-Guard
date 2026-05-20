from pymongo import MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

MONGO_URL = "mongodb+srv://bsai24030_db_user:k81mWGUrePwUemPN@cluster0.ihjyzsl.mongodb.net/examguard?retryWrites=true&w=majority&appName=Cluster0&tls=true"
DB_NAME = "examguard_db"
TEACHERS_COLLECTION = "teachers"
CLASSROOMS_COLLECTION = "classrooms"
STUDENTS_COLLECTION = "students"
EXAM_SESSIONS_COLLECTION = "exam_sessions"
NOTIFICATIONS_COLLECTION = "notifications"

try:
    client = MongoClient(MONGO_URL)
    client.server_info()
    print("MongoDB connected successfully")

    database: Database = client[DB_NAME]
    teachers_collection: Collection = database[TEACHERS_COLLECTION]
    classrooms_collection: Collection = database[CLASSROOMS_COLLECTION]
    students_collection: Collection = database[STUDENTS_COLLECTION]
    exam_sessions_collection: Collection = database[EXAM_SESSIONS_COLLECTION]
    notifications_collection: Collection = database[NOTIFICATIONS_COLLECTION]

    existing_collections = database.list_collection_names()
    if NOTIFICATIONS_COLLECTION not in existing_collections:
        database.create_collection(NOTIFICATIONS_COLLECTION)
        print("MongoDB notifications collection created")
    if STUDENTS_COLLECTION not in existing_collections:
        database.create_collection(STUDENTS_COLLECTION)
        print("MongoDB students collection created")

except Exception as e:
    print("MongoDB connection error:", e)

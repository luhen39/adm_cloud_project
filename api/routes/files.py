import uuid
import io
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from services.auth import verify_token
from services import minio as minio_service
from config import settings
from models import ShareRequest, ShareResponse

router = APIRouter()

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    username: str = Depends(verify_token)
):
    used = minio_service.get_user_quota_used(username)
    if used + file.size > settings.user_quota_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Quota excedida"
        )

    file_id = str(uuid.uuid4())
    content = await file.read()

    minio_service.upload_file(
        username=username,
        file_id=file_id,
        file_data=io.BytesIO(content),
        size=len(content),
        content_type=file.content_type or "application/octet-stream"
    )

    return {
        "file_id": file_id,
        "filename": file.filename,
        "size": len(content),
        "content_type": file.content_type
    }

@router.get("")
async def list_files(
    page: int = 1,
    page_size: int = 20,
    username: str = Depends(verify_token)
):
    files = minio_service.list_files(username)
    start = (page - 1) * page_size
    end = start + page_size
    return {
        "files": files[start:end],
        "page": page,
        "page_size": page_size,
        "total": len(files)
    }

@router.get("/{file_id}")
async def download_file(
    file_id: str,
    username: str = Depends(verify_token)
):
    data = minio_service.download_file(username, file_id)
    return StreamingResponse(
        data,
        media_type="application/octet-stream",
        headers={"Content-Disposition": f"attachment; filename={file_id}"}
    )

@router.delete("/{file_id}")
async def delete_file(
    file_id: str,
    username: str = Depends(verify_token)
):
    minio_service.delete_file(username, file_id)
    return {"message": f"Ficheiro {file_id} eliminado com sucesso"}

@router.post("/{file_id}/share", response_model=ShareResponse)
async def share_file(
    file_id: str,
    request: ShareRequest,
    username: str = Depends(verify_token)
):
    url = minio_service.generate_presigned_url(username, file_id, request.ttl_seconds)
    return ShareResponse(url=url, ttl_seconds=request.ttl_seconds)

@router.get("/{file_id}/meta")
async def get_file_meta(
    file_id: str,
    username: str = Depends(verify_token)
):
    return minio_service.get_file_meta(username, file_id)

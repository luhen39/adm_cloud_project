import uuid
import io
import time
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, Header
from fastapi.responses import StreamingResponse
from services import minio as minio_service
from services import auth as auth_service
from config import settings
from models import ShareRequest, ShareResponse
from prometheus_client import Counter, Histogram

router = APIRouter()

# Métricas
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint']
)

UPLOAD_SIZE = Histogram(
    'file_upload_size_bytes',
    'Size of uploaded files in bytes',
    buckets=[1024, 10240, 102400, 1048576, 10485760]
)

def get_current_user(
    authorization: str | None = Header(None),
    x_authenticated_user: str | None = Header(None),
    x_forwarded_user: str | None = Header(None)
) -> str:
    # 1. OAuth2-Proxy (prioridade máxima)
    if x_forwarded_user:
        return x_forwarded_user
    # 2. Outros métodos (Authorization, Basic Auth)
    return auth_service.get_username_from_headers(
        authorization,
        x_authenticated_user
    )

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    username: str = Depends(get_current_user)
):
    start = time.time()
    try:
        file_id = str(uuid.uuid4())
        content = await file.read()
        size = len(content)

        used = minio_service.get_user_quota_used(username)
        if used + size > settings.user_quota_bytes:
            REQUEST_COUNT.labels(method="POST", endpoint="/files/upload", status=413).inc()
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Quota excedida"
            )

        content_type = file.content_type or "application/octet-stream"
        minio_service.upload_file(
            username=username,
            file_id=file_id,
            file_data=io.BytesIO(content),
            size=size,
            content_type=content_type,
            metadata={"original-filename": file.filename or file_id}
        )

        UPLOAD_SIZE.observe(size)
        REQUEST_COUNT.labels(method="POST", endpoint="/files/upload", status=200).inc()
        return {
            "file_id": file_id,
            "filename": file.filename or file_id,
            "size": size,
            "content_type": content_type
        }
    except HTTPException:
        raise
    except Exception:
        REQUEST_COUNT.labels(method="POST", endpoint="/files/upload", status=500).inc()
        raise
    finally:
        REQUEST_LATENCY.labels(method="POST", endpoint="/files/upload").observe(time.time() - start)


@router.get("")
async def list_files(
    page: int = 1,
    page_size: int = 20,
    username: str = Depends(get_current_user)
):
    start = time.time()
    try:
        files = minio_service.list_files(username)
        start_idx = (page - 1) * page_size
        end = start_idx + page_size
        REQUEST_COUNT.labels(method="GET", endpoint="/files", status=200).inc()
        return {
            "files": files[start_idx:end],
            "page": page,
            "page_size": page_size,
            "total": len(files)
        }
    except Exception:
        REQUEST_COUNT.labels(method="GET", endpoint="/files", status=500).inc()
        raise
    finally:
        REQUEST_LATENCY.labels(method="GET", endpoint="/files").observe(time.time() - start)


@router.get("/{file_id}")
async def download_file(
    file_id: str,
    username: str = Depends(get_current_user)
):
    start = time.time()
    try:
        data = minio_service.download_file(username, file_id)
        REQUEST_COUNT.labels(method="GET", endpoint="/files/{file_id}", status=200).inc()

        def iterfile():
            try:
                for chunk in data.iter_chunks(32 * 1024):
                    yield chunk
            finally:
                data.close()

        return StreamingResponse(
            iterfile(),
            media_type="application/octet-stream",
            headers={"Content-Disposition": f"attachment; filename={file_id}"}
        )
    except Exception:
        REQUEST_COUNT.labels(method="GET", endpoint="/files/{file_id}", status=500).inc()
        raise
    finally:
        REQUEST_LATENCY.labels(method="GET", endpoint="/files/{file_id}").observe(time.time() - start)


@router.delete("/{file_id}")
async def delete_file(
    file_id: str,
    username: str = Depends(get_current_user)
):
    start = time.time()
    try:
        minio_service.delete_file(username, file_id)
        REQUEST_COUNT.labels(method="DELETE", endpoint="/files/{file_id}", status=200).inc()
        return {"message": f"Ficheiro {file_id} eliminado com sucesso"}
    except Exception:
        REQUEST_COUNT.labels(method="DELETE", endpoint="/files/{file_id}", status=500).inc()
        raise
    finally:
        REQUEST_LATENCY.labels(method="DELETE", endpoint="/files/{file_id}").observe(time.time() - start)


@router.post("/{file_id}/share", response_model=ShareResponse)
async def share_file(
    file_id: str,
    request: ShareRequest,
    username: str = Depends(get_current_user)
):
    start = time.time()
    try:
        url = minio_service.generate_presigned_url(username, file_id, request.ttl_seconds)
        REQUEST_COUNT.labels(method="POST", endpoint="/files/{file_id}/share", status=200).inc()
        return ShareResponse(url=url, ttl_seconds=request.ttl_seconds)
    except Exception:
        REQUEST_COUNT.labels(method="POST", endpoint="/files/{file_id}/share", status=500).inc()
        raise
    finally:
        REQUEST_LATENCY.labels(method="POST", endpoint="/files/{file_id}/share").observe(time.time() - start)


@router.get("/{file_id}/meta")
async def get_file_meta(
    file_id: str,
    username: str = Depends(get_current_user)
):
    start = time.time()
    try:
        result = minio_service.get_file_meta(username, file_id)
        REQUEST_COUNT.labels(method="GET", endpoint="/files/{file_id}/meta", status=200).inc()
        return result
    except Exception:
        REQUEST_COUNT.labels(method="GET", endpoint="/files/{file_id}/meta", status=500).inc()
        raise
    finally:
        REQUEST_LATENCY.labels(method="GET", endpoint="/files/{file_id}/meta").observe(time.time() - start)
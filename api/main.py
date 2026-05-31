from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from prometheus_client import make_asgi_app
from prometheus_fastapi_instrumentator import Instrumentator 
from routes import auth, files, health
from fastapi.exceptions import RequestValidationError

app = FastAPI(
    title="Project Dropbox API",
    description="Cloud File Storage System",
    version="1.0.0"
)

Instrumentator().instrument(app).expose(app, include_in_schema=False)   # ← NOVO

metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(files.router, prefix="/files", tags=["files"])
app.include_router(health.router, tags=["health"])

@app.exception_handler(401)
async def unauthorized_handler(request: Request, exc):
    return JSONResponse(
        status_code=401,
        content={
            "type": "about:blank",
            "title": "Unauthorized",
            "status": 401,
            "detail": "Authentication required",
            "instance": str(request.url)
        }
    )

@app.exception_handler(403)
async def forbidden_handler(request: Request, exc):
    return JSONResponse(
        status_code=403,
        content={
            "type": "about:blank",
            "title": "Forbidden",
            "status": 403,
            "detail": "Access denied",
            "instance": str(request.url)
        }
    )

@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    return JSONResponse(
        status_code=404,
        content={
            "type": "about:blank",
            "title": "Not Found",
            "status": 404,
            "detail": "Resource not found",
            "instance": str(request.url)
        }
    )

@app.exception_handler(413)
async def too_large_handler(request: Request, exc):
    return JSONResponse(
        status_code=413,
        content={
            "type": "about:blank",
            "title": "Payload Too Large",
            "status": 413,
            "detail": "Quota excedida",
            "instance": str(request.url)
        }
    )

@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={
            "type": "about:blank",
            "title": "Unprocessable Entity",
            "status": 422,
            "detail": "Validation error",
            "instance": str(request.url),
            "errors": jsonable_encoder(exc.errors())
        }
    )

from fastapi import FastAPI
from prometheus_client import make_asgi_app
from routes import auth, files, health

app = FastAPI(
    title="Project Dropbox API",
    description="Cloud File Storage System",
    version="1.0.0"
)

# Rotas
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(files.router, prefix="/files", tags=["files"])
app.include_router(health.router, tags=["health"])

# Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(403)
async def forbidden_handler(request: Request, exc):
    return JSONResponse(
        status_code=401,
        content={"detail": "Not authenticated"}
    )

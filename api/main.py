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

"""Ruta de FastAPI que rechaza por ``Content-Length`` antes de leer el cuerpo.

FastAPI lee y decodifica el cuerpo (``multipart/form-data``) ANTES de resolver las dependencias, por lo que un
``Depends`` no puede cortar una petición enorme: hay que envolver el manejador de la ruta. Está en ``app/core``
porque el envoltorio debe ser ``async`` (los módulos de CU11 no pueden declarar ``async def``) y es genérico:
cada ruta concreta fija el tope y el error en una subclase.
"""
from typing import Callable

from fastapi import Request, Response
from fastapi.routing import APIRoute


class ContentLengthLimitedRoute(APIRoute):
    """Subclasificar fijando ``max_content_length`` (bytes) y ``exceeded_error``."""

    max_content_length: int = 0

    def exceeded_error(self, content_length: int) -> Exception:
        raise NotImplementedError

    def get_route_handler(self) -> Callable:
        original = super().get_route_handler()
        limite = self.max_content_length

        async def handler(request: Request) -> Response:
            declarado = request.headers.get("content-length", "")
            if limite and declarado.isdigit() and int(declarado) > limite:
                raise self.exceeded_error(int(declarado))
            return await original(request)

        return handler

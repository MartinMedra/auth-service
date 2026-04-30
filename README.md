# Pieces Service — Prueba Técnica Cotecmar

Microservicio de gestión de producción construido con **Laravel 11**. Administra la jerarquía **Proyecto → Bloque → Pieza** y lleva el registro de fabricación de cada pieza con control de pesos y estados. Todas sus rutas están protegidas por JWT validado localmente, sin depender del Auth Service en tiempo de ejecución.

---

## Stack técnico

| Capa | Tecnología |
|------|-----------|
| Framework | Laravel 11 |
| Lenguaje | PHP 8.4 |
| Autenticación | JWT (validación local con `php-open-source-saver/jwt-auth`) |
| Base de datos | PostgreSQL |
| ORM | Eloquent + Migraciones + SoftDeletes |

---

## Modelo de datos

```
proyectos
    └── bloques          (proyecto_id → proyectos.id)
            └── piezas   (bloque_id → bloques.id)
                    └── registros_fabricacion  (pieza_id → piezas.id)
```

El campo `diferencia_peso` en `registros_fabricacion` es una **columna generada por PostgreSQL** (`storedAs`), calculada como `peso_real - peso_teorico`. No puede ser modificada manualmente — la integridad del dato la garantiza la base de datos, no la aplicación.

---

## Variables de entorno

```env
APP_NAME=PiecesService
APP_URL=http://localhost:8002

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=pieces_db
DB_USERNAME=postgres
DB_PASSWORD=tu_password

JWT_SECRET=   # debe ser el mismo valor que en el Auth Service
JWT_TTL=60
```

> ⚠️ `JWT_SECRET` tiene que coincidir exactamente con el del Auth Service. Es lo que permite que este servicio valide tokens sin hacer ninguna llamada HTTP al Auth Service.

---

## Pasos de ejecución

**Requisitos previos:** PHP 8.4, Composer, PostgreSQL con la base de datos `pieces_db` creada.

```bash
# 1. Instalar dependencias
composer install

# 2. Copiar variables de entorno
cp .env.example .env

# 3. Generar clave de aplicación
php artisan key:generate

# 4. Publicar configuración JWT y pegar el mismo JWT_SECRET del Auth Service en .env
php artisan vendor:publish --provider="PHPOpenSourceSaver\JWTAuth\Providers\LaravelServiceProvider"

# 5. Ejecutar migraciones
php artisan migrate

# 6. Levantar el servicio
php artisan serve --port=8002
```

---

## Autenticación

Todas las rutas requieren el header:

```
Authorization: Bearer <token>
Accept: application/json
```

El token se obtiene desde el Auth Service (`POST http://localhost:8001/api/login`). Este servicio lo valida con la misma clave secreta compartida, sin red ni base de datos adicional.

Errores posibles:

| Código | Causa |
|--------|-------|
| 401 | Token no enviado, inválido o expirado |
| 403 | Token válido pero sin permisos para el recurso |

---

## Endpoints principales — `/api/v1`

### Proyectos

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/proyectos` | Listar proyectos (filtros: `estado`, `buscar`; paginación: `por_pagina`) |
| POST | `/api/v1/proyectos` | Crear proyecto |
| GET | `/api/v1/proyectos/{id}` | Ver proyecto con sus bloques y piezas |
| PUT | `/api/v1/proyectos/{id}` | Actualizar proyecto |
| DELETE | `/api/v1/proyectos/{id}` | Eliminar proyecto (soft delete) |

**Ejemplo — Crear proyecto:**
```json
POST /api/v1/proyectos
{
  "nombre": "Buque ARC Simón Bolívar",
  "codigo_proyecto": "COTECMAR-2024-001",
  "descripcion": "Construcción casco principal",
  "estado": "activo"
}
```

---

### Bloques

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/proyectos/{proyecto}/bloques` | Listar bloques del proyecto |
| POST | `/api/v1/proyectos/{proyecto}/bloques` | Crear bloque en el proyecto |
| GET | `/api/v1/proyectos/{proyecto}/bloques/{bloque}` | Ver bloque con sus piezas |
| PUT | `/api/v1/proyectos/{proyecto}/bloques/{bloque}` | Actualizar bloque |
| DELETE | `/api/v1/proyectos/{proyecto}/bloques/{bloque}` | Eliminar bloque (soft delete) |

---

### Piezas

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/bloques/{bloque}/piezas` | Listar piezas del bloque |
| POST | `/api/v1/bloques/{bloque}/piezas` | Crear pieza en el bloque |
| GET | `/api/v1/bloques/{bloque}/piezas/{pieza}` | Ver pieza con su historial de fabricación |
| PUT | `/api/v1/bloques/{bloque}/piezas/{pieza}` | Actualizar pieza |
| DELETE | `/api/v1/bloques/{bloque}/piezas/{pieza}` | Eliminar pieza (soft delete) |

**Ejemplo — Crear pieza:**
```json
POST /api/v1/bloques/1/piezas
{
  "nombre": "Cuaderna maestra",
  "codigo_pieza": "PZA-001",
  "peso_teorico": 125.500
}
```

---

### Registros de Fabricación

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/piezas/{pieza}/registros` | Listar registros (filtros: `estado`, `fecha_desde`, `fecha_hasta`) |
| POST | `/api/v1/piezas/{pieza}/registros` | Crear registro de fabricación |
| GET | `/api/v1/piezas/{pieza}/registros/{registro}` | Ver registro con trazabilidad completa |
| PUT | `/api/v1/piezas/{pieza}/registros/{registro}` | Actualizar registro |

> Los registros de fabricación **no se eliminan**. Son la trazabilidad del proceso productivo.

**Ejemplo — Registrar fabricación:**
```json
POST /api/v1/piezas/1/registros
{
  "peso_real": 127.300,
  "estado": "fabricada",
  "observaciones": "Leve exceso por soldadura de refuerzo"
}
```

**Respuesta:**
```json
{
  "mensaje": "Registro de fabricación creado correctamente.",
  "registro": {
    "id": 1,
    "pieza_id": 1,
    "fecha_fabricacion": "2024-06-01T14:35:00",
    "peso_teorico": 125.500,
    "peso_real": 127.300,
    "diferencia_peso": 1.800,
    "estado": "fabricada",
    "usuario_id": 1
  }
}
```

---

### Reportes

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/reportes/piezas-pendientes` | Piezas pendientes agrupadas por proyecto |
| GET | `/api/v1/reportes/totales-por-estado` | Totales globales con porcentajes por estado |

---

## Decisiones técnicas

- **Rutas anidadas (`proyectos.bloques`, `bloques.piezas`)**: reflejan fielmente la jerarquía del modelo de datos y evitan que un bloque de otro proyecto sea accedido por error.
- **Columna generada `diferencia_peso`**: calculada por PostgreSQL con `storedAs`, garantizando que el dato nunca pueda ser manipulado desde la aplicación.
- **`usuario_id` desde el JWT**: el middleware extrae el ID del usuario directamente del payload del token y lo inyecta en la petición, sin consultar la BD del Auth Service.
- **SoftDeletes en proyectos, bloques y piezas**: los datos no se eliminan físicamente para preservar la trazabilidad histórica de producción.
- **Registros de fabricación sin DELETE**: un registro de producción es un hecho histórico. Solo puede actualizarse su estado u observaciones.
- **`peso_teorico` copiado al registro**: se guarda el peso teórico vigente al momento del registro. Si la pieza se modifica después, el registro histórico conserva el valor original.
- **Versionado `/api/v1`**: permite evolucionar la API sin romper integraciones existentes.

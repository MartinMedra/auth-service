# Auth Service — Prueba Técnica Cotecmar

Microservicio de autenticación construido con **Laravel 11** y **JWT**. Su única responsabilidad es validar credenciales y emitir tokens que los demás servicios de la arquitectura pueden verificar de forma independiente, sin consultar este servicio en cada petición.

---

## Stack técnico

| Capa | Tecnología |
|------|-----------|
| Framework | Laravel 11 |
| Lenguaje | PHP 8.4 |
| Autenticación | `php-open-source-saver/jwt-auth` |
| Base de datos | PostgreSQL 16 |
| ORM | Eloquent + Migraciones |
| Contenedores | Docker |

---

## ¿Por qué JWT y no Sanctum?

Sanctum almacena las sesiones en base de datos, lo que obligaría al Pieces Service a consultar la BD del Auth Service en cada petición — eso acopla los servicios. Con JWT el token es **stateless**: cualquier servicio que comparta el mismo `JWT_SECRET` puede validarlo localmente sin red ni BD extra. Eso sí es arquitectura de microservicios real.

---

## Levantar con Docker (recomendado)

Este servicio forma parte de una arquitectura orquestada desde el repositorio del Frontend. Para correr el proyecto completo con un solo comando:

```bash
# 1. Clonar el repositorio del frontend (contiene el docker-compose.yml)
git clone https://github.com/MartinMedra/gestion-frontend.git
cd gestion-frontend

# 2. Levantar todos los servicios
docker compose up --build
```

El Auth Service quedará disponible en `http://localhost:8001`.

> El `docker-compose.yml` levanta automáticamente: Auth Service, Pieces Service, Frontend y las dos bases de datos PostgreSQL. No se requiere instalar PHP, Composer ni PostgreSQL de forma local.

**Credenciales de prueba creadas automáticamente:**

| Campo | Valor |
|-------|-------|
| Email | admin@cotecmar.com |
| Contraseña | password123 |

---

## Ejecución local (sin Docker)

**Requisitos previos:** PHP 8.4, Composer, PostgreSQL con la base de datos `auth_db` creada.

```bash
# 1. Instalar dependencias
composer install

# 2. Copiar variables de entorno
cp .env.example .env

# 3. Generar clave de aplicación
php artisan key:generate

# 4. Generar clave JWT (escribe JWT_SECRET en .env automáticamente)
php artisan jwt:secret

# 5. Ejecutar migraciones y seeder
php artisan migrate --seed

# 6. Levantar el servicio
php artisan serve --port=8001
```

---

## Variables de entorno

```env
APP_NAME=AuthService
APP_URL=http://localhost:8001

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=auth_db
DB_USERNAME=postgres
DB_PASSWORD=tu_password

JWT_SECRET=        # generado con: php artisan jwt:secret
JWT_TTL=60         # minutos de validez del token
JWT_REFRESH_TTL=20160
JWT_BLACKLIST_ENABLED=true
```

> ⚠️ El valor de `JWT_SECRET` debe ser **idéntico** al configurado en el Pieces Service.

---

## Endpoints

Base URL local: `http://localhost:8001`

### `POST /api/login` — público

Recibe credenciales y devuelve un token JWT válido.

**Body JSON:**
```json
{
  "email": "admin@cotecmar.com",
  "password": "password123"
}
```

**Respuesta 200:**
```json
{
  "access_token": "<jwt>",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": 1,
    "name": "Admin",
    "email": "admin@cotecmar.com"
  }
}
```

**Respuesta 401 (credenciales incorrectas):**
```json
{
  "message": "Credenciales incorrectas."
}
```

---

### `GET /api/me` — protegido

Retorna los datos del usuario dueño del token.

**Headers requeridos:**
```
Authorization: Bearer <token>
Accept: application/json
```

**Respuesta 200:**
```json
{
  "id": 1,
  "name": "Admin",
  "email": "admin@cotecmar.com",
  "created_at": "2024-01-01T00:00:00.000000Z"
}
```

---

### `POST /api/logout` — protegido

Invalida el token activo (revocación mediante blacklist JWT).

**Headers requeridos:**
```
Authorization: Bearer <token>
Accept: application/json
```

**Respuesta 200:**
```json
{
  "message": "Sesión cerrada correctamente."
}
```

---

## Prueba rápida con curl

```bash
# Login
curl -X POST http://localhost:8001/api/login \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"email":"admin@cotecmar.com","password":"password123"}'

# Ver usuario autenticado (reemplaza TOKEN)
curl http://localhost:8001/api/me \
  -H "Authorization: Bearer TOKEN" \
  -H "Accept: application/json"

# Cerrar sesión
curl -X POST http://localhost:8001/api/logout \
  -H "Authorization: Bearer TOKEN" \
  -H "Accept: application/json"
```

---

## Decisiones técnicas

- **Guard `api` con driver `jwt`**: se reemplaza el driver por defecto para que todas las rutas protegidas con `auth:api` usen JWT automáticamente.
- **Claims personalizados en el token**: el payload incluye `email` y `name` además del `sub` (ID), para que el Pieces Service pueda identificar al usuario sin consultar esta BD.
- **Blacklist de tokens**: al hacer logout el token queda registrado como inválido hasta su expiración natural. Configurable con `JWT_BLACKLIST_ENABLED=true`.
- **Códigos HTTP explícitos**: 401 para credenciales inválidas, 403 cuando el token es válido pero el acceso está denegado.
- **CORS configurado en `bootstrap/app.php`**: Laravel 11 eliminó el archivo `config/cors.php` — la configuración vive directamente en el pipeline de middleware de la aplicación.
- **Seeder de usuario de prueba**: el comando `migrate --seed` crea automáticamente el usuario `admin@cotecmar.com` usando `firstOrCreate`, lo que evita duplicados si se corre más de una vez.

# Rubípticos

Sitio web para jugar a crípticos en castellano: acertijos en los que una frase esconde una palabra detrás de un juego de palabras. Trabajo Final Integrador de Taller de Tecnologías de Producción de Software, opción Ruby (Facultad de Informática, UNLP), cursada 2026.

La aplicación tiene dos partes dentro del mismo proyecto Rails:

- **Sitio público** (`/`): el juego, las rachas y la tabla de posiciones. Los jugadores entran solo con un nombre.
- **Backend de administración** (`/admin`): login con email y contraseña para mantener el catálogo y la configuración del juego.

El catálogo de crípticos se sincroniza desde una API JSON.

## Requisitos

- Ruby 3.4.12
- Node.js 26.13.0 y Yarn 1.22
- Git

En Windows, todo se instala y se corre dentro de Ubuntu con WSL2, y el proyecto se clona en la carpeta de Linux (no en `/mnt/c`).

## Clonar y levantar el proyecto

```bash
git clone git@github.com:santiisamudio/tfi_ruby.git
cd tfi_ruby
bin/setup
```

`bin/setup` instala las gemas (Rails incluido) y los paquetes de Yarn, prepara la base de datos y levanta la aplicación en http://localhost:3000. Se detiene con `Ctrl+C`.

## Uso diario

```bash
bin/dev
```

Levanta la aplicación y recompila el CSS cada vez que cambia un `.scss`.

Después de bajar cambios del repositorio:

```bash
git pull
bin/setup --skip-server
```

Instala las gemas y paquetes nuevos y aplica las migraciones pendientes.

## Comandos útiles

| Comando | Para qué |
|---|---|
| `bin/dev` | Levanta la aplicación en http://localhost:3000 |
| `bin/rails console` | Consola para probar modelos y consultas |
| `bin/rails db:migrate` | Aplica las migraciones pendientes |
| `bin/rails db:seed` | Carga los datos de `db/seeds.rb` |
| `bin/rails db:setup` | Crea la base, carga el esquema y los seeds |
| `bin/rails routes` | Lista las rutas de la aplicación |
| `bin/rails test` | Corre los tests |
| `bin/rubocop` | Revisa el estilo del código |

## Usuario administrador

Al preparar la base se crea un administrador para entrar al backend en http://localhost:3000/admin:

- Email: `admin@rubipticos.com`
- Contraseña: `password`

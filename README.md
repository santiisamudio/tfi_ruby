# Rubípticos

Sitio web para jugar a crípticos en castellano: acertijos en los que una frase esconde una palabra detrás de un juego de palabras. Trabajo Final Integrador de Taller de Tecnologías de Producción de Software, opción Ruby (Facultad de Informática, UNLP), cursada 2026.

La aplicación tiene dos partes dentro del mismo proyecto Rails:

- **Sitio público** (`/`): el juego, las rachas y la tabla de posiciones. Los jugadores entran solo con un nombre.
- **Backend de administración** (`/admin`): login con email y contraseña para mantener el catálogo y la configuración del juego.

El catálogo de crípticos se sincroniza desde la [API de la cátedra](https://github.com/ecorrons/cryptics-api).

## Requisitos

| Herramienta | Versión | Dónde está fijada |
|---|---|---|
| Ruby | 3.4.12 | `.ruby-version` |
| Ruby on Rails | 8.1.4 | `Gemfile.lock` |
| Node.js | 26.13.0 | `.node-version` y `.nvmrc` |
| Yarn | 1.22 | — |
| SQLite | 3 | incluido en la gema `sqlite3` |
| Git | reciente | — |

Node.js y Yarn hacen falta para compilar Bootstrap (ver [Decisiones de diseño](#decisiones-de-diseño)).

El proyecto se desarrolla en sistemas tipo *nix (Linux o macOS). En Windows se usa WSL2 con Ubuntu.

## Preparar el entorno (una vez por máquina)

### Linux (Ubuntu o Debian)

1. Dependencias para compilar Ruby:

   ```bash
   sudo apt update
   sudo apt install -y git curl build-essential libssl-dev libyaml-dev libffi-dev \
     zlib1g-dev libreadline-dev libgmp-dev autoconf bison patch sqlite3 libsqlite3-dev
   ```

2. rbenv y ruby-build, para manejar la versión de Ruby:

   ```bash
   git clone https://github.com/rbenv/rbenv.git ~/.rbenv
   git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
   echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
   echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
   exec $SHELL
   ```

   Si ya tenías ruby-build, actualizalo para que conozca la versión del proyecto:

   ```bash
   git -C ~/.rbenv/plugins/ruby-build pull
   ```

3. nvm, para manejar la versión de Node.js:

   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
   exec $SHELL
   ```

4. Una clave SSH cargada en GitHub, para poder clonar el repositorio ([guía de GitHub](https://docs.github.com/es/authentication/connecting-to-github-with-ssh)).

### Windows

La cátedra da soporte solo en sistemas *nix, así que en Windows se trabaja dentro de Ubuntu con WSL2:

1. En PowerShell como administrador:

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

2. Reiniciar, abrir **Ubuntu 24.04** desde el menú Inicio y crear el usuario de Linux.
3. Dentro de Ubuntu, seguir los pasos de [Linux](#linux-ubuntu-o-debian).

**Importante:** clonar el proyecto dentro de Linux (por ejemplo, en `~/`), no en `/mnt/c/...`. En las carpetas de Windows, Rails anda mucho más lento y Git pierde los permisos de ejecución de los scripts de `bin/`.

Para editar, VS Code con la extensión **WSL**: desde la carpeta del proyecto en Ubuntu, `code .`.

### macOS

1. Herramientas de compilación: `xcode-select --install`.
2. rbenv y ruby-build con [Homebrew](https://brew.sh): `brew install rbenv ruby-build`, después `rbenv init` y abrir una terminal nueva.
3. nvm, con el mismo comando que en Linux (paso 3).

La primera vez que alguien instala en Mac, `bundle install` agrega esa plataforma al `Gemfile.lock`. Ese cambio se commitea.

## Clonar y levantar el proyecto

```bash
git clone git@github.com:santiisamudio/tfi_ruby.git
cd tfi_ruby
rbenv install --skip-existing
nvm install
npm install -g yarn
bin/setup
```

- `rbenv install --skip-existing` instala la versión de Ruby de `.ruby-version`, si todavía no la tenés.
- `nvm install` instala la versión de Node.js de `.nvmrc`.
- `bin/setup` instala las gemas (Rails incluido) y los paquetes de Yarn, prepara la base de datos y levanta el servidor.

La aplicación queda en http://localhost:3000. Se detiene con `Ctrl+C`.

## Uso diario

Para levantar el proyecto:

```bash
bin/dev
```

`bin/dev` levanta el servidor de Rails y, en paralelo, el proceso que recompila el CSS cada vez que cambia un `.scss`. Con `bin/rails server` solo, los cambios de estilos no se ven.

Después de bajar cambios del repositorio:

```bash
git pull
bin/setup --skip-server
```

`bin/setup` se puede correr siempre: si alguien agregó una gema, un paquete o una migración, lo instala o lo aplica; si no hay nada nuevo, no cambia nada.

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
| `bin/rubocop` | Revisa el estilo del código, igual que el CI de GitHub |

## Usuario administrador de prueba

Pendiente: se crea desde `db/seeds.rb` cuando esté implementado el backend.

## Decisiones de diseño

- **Bootstrap con `cssbundling-rails`** (`rails new --css=bootstrap`): permite personalizar Bootstrap con Sass. Por eso el proyecto necesita Node.js y Yarn.
- **SQLite** como base de datos, la que trae Rails 8 por defecto.
- **Versiones fijadas** en `.ruby-version`, `.nvmrc`, `Gemfile.lock` y `yarn.lock`, para que todo el grupo, y quien corrija, trabaje con las mismas versiones.

## Cómo trabajamos con Git

- Una rama por tarea. Nadie trabaja directo sobre `main`.
- Cada rama entra a `main` por pull request, revisado por otro integrante.
- Commits chicos, con un mensaje que diga qué hace el cambio.
- Antes de empezar una tarea: `git checkout main` y `git pull`.

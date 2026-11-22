# Endpoints de GamesController

Todos devuelven JSON y trabajan con el jugador identificado por su cookie.
`:id` es el ID de la partida.

## Estado de partida

Las acciones de asignar, consultar, iniciar y rendirse devuelven:

- `id`, `status`, `difficulty`.
- `daily_on`: fecha del desafío diario, o `null` en partidas normales.
- `attempts_count`, `hints_count`.
- `started_at`, `finished_at`, `points`: pueden ser `null` según el estado.
- Si se inició: `clue`, `enumeration`, `elapsed_seconds` y `hints`
  (solo las pistas desbloqueadas).
- Si se ganó, perdió o hubo rendición: `answer` y `explanation`.
  Un desafío vencido no revela la solución.

Estados posibles: `pending`, `in_progress`, `won`, `lost`, `surrendered`, `expired`.

## POST /games

**Para qué sirve:** asignar un críptico aleatorio sin jugar de la dificultad
elegida. Si el jugador ya tiene una partida abierta, devuelve esa misma partida.

**Recibe:** `{"difficulty":"facil"}`. Valores: `facil`, `medio`, `avanzado`.

**Devuelve:** el estado de partida. Una nueva queda `pending`, sin enunciado
ni cronómetro iniciado.

## POST /games/daily

**Para qué sirve:** asignar el desafío de hoy o recuperar la partida de ese
desafío si ya existe.

**Recibe:** sin body.

**Devuelve:** el estado de partida con `daily_on` indicando la fecha.
Puede rechazar la asignación si hay otra partida abierta o ya jugó ese críptico.

## GET /games/:id

**Para qué sirve:** consultar o recuperar una partida propia.

**Recibe:** sin body.

**Devuelve:** el estado actual, incluido el tiempo del servidor y las pistas
desbloqueadas si se inició.

## POST /games/:id/start

**Para qué sirve:** iniciar la partida al presionar Jugar.
Repetirlo sobre una partida en curso no reinicia el reloj.

**Recibe:** sin body.

**Devuelve:** el estado `in_progress`, con enunciado, enumeración y tiempo.
No devuelve la respuesta correcta.

## POST /games/:id/hint

**Para qué sirve:** desbloquear una pista. Se solicitan en orden del 1 al 4;
repetir un nivel desbloqueado no consume otra pista.

**Recibe:** `{"level":1}`.

**Devuelve:** solo la pista solicitada:

| Nivel | Campos |
| --- | --- |
| 1 | `level`, `puzzle_type` |
| 2 | `level`, `definitions` |
| 3 | `level`, `indicators`, `material` |
| 4 | `level`, `hint` |

## POST /games/:id/surrender

**Para qué sirve:** rendirse en una partida iniciada.

**Recibe:** sin body.

**Devuelve:** el estado `surrendered`, 0 puntos, respuesta y explicación.
Si ya terminó, conserva el resultado existente.

## GET /games/:id/share

**Para qué sirve:** obtener un resultado listo para compartir.
Solo admite partidas terminadas.

**Recibe:** sin body.

**Devuelve:** `text` y `whatsapp_url`. El texto resume resultado, puntos,
intentos, cantidad de pistas y tiempo si hubo inicio. En diarios incluye la fecha.
No revela enunciado ni solución y no envía mensajes automáticamente.

## Errores y pendiente

Los errores controlados devuelven:

```json
{
  "error": {
    "code": "game_not_found",
    "message": "No se encontró una partida de este jugador con ese identificador."
  }
}
```

HTTP: 400 para parámetros incorrectos, 401 sin jugador, 403 si está bloqueado,
404 si la partida no existe o es ajena, y 422 para reglas de juego o CSRF inválido.
Los POST requieren el token CSRF de Rails.

**Todavía no existe un endpoint para enviar respuestas:** falta conectar la
configuración de puntaje con administración.

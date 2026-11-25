# Accendere le luci da Tocco con Home Assistant

Tocco chiama un **webhook** di Home Assistant. Il comando "Luci di casa" (Shift destro + L) usa:

```
https://jarvis.tail370cac.ts.net:9443/api/webhook/tocco_luci
```

Funziona da casa e da fuori, purché Tailscale sia acceso sul Mac.

## 1. Crea l'automazione in Home Assistant

Impostazioni → Automazioni e scene → Crea automazione → ⋮ → **Modifica in YAML**, incolla e salva:

```yaml
alias: Tocco - luci di casa
description: Shift destro + L sulla tastiera (app Tocco)
triggers:
  - trigger: webhook
    webhook_id: tocco_luci
    allowed_methods:
      - POST
    local_only: false
actions:
  - action: light.toggle
    target:
      entity_id: light.sala
mode: single
```

- `light.toggle` accende se è spenta e spegne se è accesa.
- Per più luci aggiungi altre entità sotto `entity_id`, oppure usa una scena o uno script.
- `local_only: false` serve perché la richiesta arriva passando da Tailscale e dal proxy. L'id del webhook (`tocco_luci`) fa da password: non pubblicarlo.

## 2. Provalo dal Terminale

```bash
curl -X POST https://jarvis.tail370cac.ts.net:9443/api/webhook/tocco_luci
```

Se le luci cambiano, cambiano anche da Tocco. Se non cambiano, il problema è in Home Assistant o nella rete, non in Tocco.

## 3. Cambiare l'indirizzo in Tocco

Livello 1 → tasto **L** → Home Assistant: modifica l'indirizzo, oppure crea altri tasti con altri webhook (es. `tocco_film` per la modalità Film).

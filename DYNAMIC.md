# n8n — dynamiczna flota instancji z domenami i SSL

Ten wariant pozwala **dodawać i usuwać instancje n8n w locie**, każda pod własną
subdomeną z automatycznym certyfikatem HTTPS. Nie musisz z góry deklarować, ile
instancji potrzebujesz — dziś 10, jutro 30, jednym poleceniem.

To alternatywa dla statycznego `docker-compose.prod.yaml` (22 sztywne instancje
po `IP:port`). Oba warianty mogą leżeć obok siebie w repo — dynamiczny używa
osobnych plików i nie koliduje ze statycznym.

---

## Jak to działa

```
                *.szkolenie-n8n.easyautomate.pl   (wildcard DNS → IP serwera)
                              │
                    ┌─────────▼──────────┐
                    │      Traefik       │  automatyczny SSL (Let's Encrypt)
                    │  (reverse proxy)   │  wykrywa kontenery po etykietach
                    └─────────┬──────────┘
        ┌───────────┬─────────┼─────────┬─────────────┐
     n8n-1        n8n-2      n8n-3   ...            n8n-N
  1.szkolenie   2.szkolenie                    (dodawane w locie)
       │            │           każda: osobna baza + osobny klucz szyfrowania
       └────────────┴───────────── wspólny PostgreSQL ─────────────┘
```

- **Wildcard DNS** — jeden rekord `*.szkolenie-n8n.easyautomate.pl` obsługuje
  dowolną liczbę subdomen. Nie dodajesz DNS-a per instancja.
- **Traefik** wykrywa nowy kontener n8n (po etykietach Docker) i **sam wystawia
  dla niego certyfikat** (wyzwanie HTTP-01) — bez tokenów DNS, bez restartu reszty.
- **Subdomeny, nie ścieżki** — `1.szkolenie-n8n...` zamiast `.../1`. n8n pod
  podścieżką bywa zawodny (WebSockety, OAuth, assety); subdomeny są niezawodne.
- Każda instancja ma **osobną bazę** (`n8n_<nazwa>`) i **osobny klucz
  szyfrowania** — pełna izolacja danych między uczestnikami.

---

## Wymagania wstępne

1. **Serwer** (VPS) z Dockerem. RAM: licz ~350–500 MB na instancję n8n +
   ~300 MB na PostgreSQL. 20 instancji ≈ 10–12 GB RAM.
2. **Domena** z możliwością ustawienia rekordu wildcard.
3. **Wpis DNS** — w panelu DNS domeny `easyautomate.pl` dodaj:

   | Typ | Nazwa                     | Wartość        |
   |-----|---------------------------|----------------|
   | A   | `*.szkolenie-n8n`         | `IP_SERWERA`   |
   | A   | `szkolenie-n8n` (opcjon.) | `IP_SERWERA`   |

   Dzięki temu `cokolwiek.szkolenie-n8n.easyautomate.pl` trafia na serwer.
4. **Porty 80 i 443** otwarte i wolne na serwerze (patrz sekcja o
   nginx-proxy-manager, jeśli masz już coś na tych portach).

---

## Uruchomienie — krok po kroku

### 1. Pobierz projekt na serwer

```bash
git clone https://github.com/kamilfityka/szkolenie-n8n.git
cd szkolenie-n8n
```

### 2. Skonfiguruj

```bash
cp .env.dynamic.example .env.dynamic
nano .env.dynamic
```

Uzupełnij:
- `BASE_DOMAIN=szkolenie-n8n.easyautomate.pl`
- `ACME_EMAIL=twoj@email.pl` (ostrzeżenia o certyfikatach)
- `POSTGRES_PASSWORD` i `N8N_DB_PASSWORD` — wygeneruj: `openssl rand -hex 16`

### 3. Otwórz porty w firewallu

```bash
ufw allow 22
ufw allow 80/tcp
ufw allow 443/tcp
```

### 4. Dodaj instancje

Pojedynczo:

```bash
bash add-instance.sh 1
bash add-instance.sh 2
bash add-instance.sh ala          # nazwa może być słowna → ala.szkolenie-n8n...
```

Hurtowo (np. 20 instancji numerowanych):

```bash
for i in $(seq 1 20); do bash add-instance.sh "$i"; done
```

Każde wywołanie:
- tworzy bazę `n8n_<nazwa>` i klucz szyfrowania,
- generuje login (`admin+<nazwa>@...`) i losowe hasło,
- podnosi kontener i rejestruje subdomenę w Traefiku (SSL leci automatycznie),
- dopisuje dostęp do `access-list-dynamic.csv`.

### 5. Rozdaj dostępy

```bash
cat access-list-dynamic.csv
```

Kolumny: `name, url, email, password`. Każdy uczestnik dostaje swój wiersz, np.:

```
"1","https://1.szkolenie-n8n.easyautomate.pl","admin+1@...","xYz123abc"
```

---

## Codzienne operacje

| Cel | Komenda |
|---|---|
| Lista instancji + status | `bash list-instances.sh` |
| Dodaj instancję | `bash add-instance.sh 21` |
| Usuń kontener, **zostaw dane** | `bash remove-instance.sh 21` |
| Usuń instancję **z danymi** | `bash remove-instance.sh 21 --purge` |
| Logi instancji | `docker logs n8n-fleet-n8n-1-1` |
| Restart instancji | `docker restart n8n-fleet-n8n-1-1` |
| Logi Traefika (diagnoza SSL) | `docker logs n8n-fleet-traefik-1` |
| Zużycie RAM | `docker stats` |

> `remove-instance.sh <nazwa>` bez `--purge` tylko zdejmuje kontener — baza,
> wolumen i sekrety zostają, więc `add-instance.sh <nazwa>` przywróci instancję
> z tym samym kluczem i danymi. Dopiero `--purge` kasuje dane bezpowrotnie.

---

## Współpraca z nginx-proxy-manager

Masz już NPM na porcie 80/443. Są dwie drogi:

### Opcja A (najprościej): Traefik przejmuje 80/443

Jeśli ten serwer ma obsługiwać głównie flotę n8n — niech porty 80/443 należą do
Traefika (zatrzymaj/przenieś NPM). Traefik sam robi SSL. Nic więcej nie trzeba.

### Opcja B: Traefik **za** nginx-proxy-manager

NPM zostaje na 80/443 dla innych usług, a flota n8n stoi za nim:

1. W `.env.dynamic` ustaw port wewnętrzny, np. `TRAEFIK_HTTP_PORT=8080`.
2. Dodawaj instancje w tym trybie:
   ```bash
   USE_BEHIND_NPM=1 bash add-instance.sh 1
   ```
   (Traefik routuje wtedy po zwykłym HTTP, a SSL robi NPM z przodu.)
3. W NPM zrób **jeden** Proxy Host:
   - Domain: `*.szkolenie-n8n.easyautomate.pl`
   - Forward Hostname/IP: `IP_SERWERA`, Port: `8080`
   - Włącz **Websockets Support**
   - Zakładka SSL: certyfikat **wildcard** dla `*.szkolenie-n8n...`
     (NPM wymaga tu **DNS Challenge**, np. token Cloudflare — HTTP challenge nie
     działa dla wildcardu).

Po tym dodawanie/usuwanie instancji nie wymaga już żadnych zmian w NPM — jeden
wildcard host obsługuje wszystkie subdomeny, a routing per instancja robi Traefik.

> Uwaga: jeśli używasz stale trybu B, wywołuj **wszystkie** komendy z
> `USE_BEHIND_NPM=1` (także `remove-instance.sh` i `list-instances.sh`),
> żeby operowały na tym samym złożeniu plików.

---

## Rozwiązywanie problemów

**„Brak certyfikatu / SSL nie działa"**
- Sprawdź, czy `*.szkolenie-n8n.easyautomate.pl` wskazuje na IP serwera:
  `dig +short cokolwiek.szkolenie-n8n.easyautomate.pl`
- Porty 80 i 443 muszą być publicznie dostępne (Let's Encrypt puka na 80).
- Zajrzyj w logi: `docker logs n8n-fleet-traefik-1`

**„This site can't provide a secure connection" tuż po dodaniu**
- Pierwszy certyfikat powstaje po pierwszym wejściu na URL — odczekaj ~15–30 s
  i odśwież.

**n8n pokazuje ostrzeżenie o secure cookie / nie loguje**
- W tym wariancie działamy po HTTPS, więc `N8N_SECURE_COOKIE=true` jest OK.
  Jeśli testujesz po samym IP/HTTP, użyj wariantu statycznego (`URUCHOMIENIE.md`).

**Za mało RAM przy wielu instancjach**
- `docker stats` pokaże zużycie. Rozważ mniejszą liczbę instancji lub większy VPS.

---

## Czym się różni od wariantu statycznego

| | `docker-compose.prod.yaml` (statyczny) | flota dynamiczna (ten plik) |
|---|---|---|
| Liczba instancji | sztywno 22, edycja YAML | dowolna, jednym poleceniem |
| Adres | `http://IP:port` | `https://nazwa.domena` |
| SSL | brak | automatyczny (Let's Encrypt) |
| Dodanie instancji | edycja compose + restart | `bash add-instance.sh <n>` |
| Proxy | brak | Traefik (dynamiczny) |

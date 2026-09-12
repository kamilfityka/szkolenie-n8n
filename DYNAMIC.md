# n8n — dynamiczna flota instancji z subdomenami i SSL

Ten wariant pozwala **dodawać i usuwać instancje n8n w locie**, każda pod własną
subdomeną i własnym HTTPS. Nie musisz z góry deklarować, ile instancji
potrzebujesz — dziś 16, jutro 30, jednym poleceniem.

**Jedna subdomena = jeden kontener = osobna baza i osobny klucz szyfrowania.**
Uczestnicy nie widzą nawzajem swoich workflowów ani credentiali.

To alternatywa dla statycznego `docker-compose.prod.yaml` (22 sztywne instancje
po `IP:port`). Oba warianty mogą leżeć obok siebie w repo.

---

## Dwa tryby pracy

Wybierasz jeden, wpisem `USE_BEHIND_NPM` w `.env.dynamic`.

### Tryb 1 (domyślny): frontem jest nginx-proxy-manager — `USE_BEHIND_NPM=1`

Dla serwera, na którym **NPM już stoi na portach 80/443** i obsługuje inne usługi.

```
                       user1.n8n.easyautomate.pl ─┐
                       user2.n8n.easyautomate.pl ─┤ (rekordy A → IP serwera)
                                              ... ─┘
                                    │
                        ┌───────────▼────────────┐
                        │  nginx-proxy-manager   │  80/443, SSL per subdomena
                        │  (Proxy Host per user) │  Let's Encrypt, Websockets ON
                        └───────────┬────────────┘
                    sieć docker `n8n-fleet` (bez wystawiania portów na hosta)
        ┌───────────────┬───────────┴───────┬────────────────┐
   n8n-user1        n8n-user2          n8n-user3   ...    n8n-userN
        └───────────────┴───────────────────┴──── wspólny PostgreSQL ────┘
```

- NPM trafia do kontenera **po nazwie** (`n8n-user1:5678`) — kontenery n8n nie
  wystawiają żadnego portu na hosta, jedyne wejście z internetu jest przez NPM.
- Traefik w tym trybie **w ogóle nie startuje** — nie walczy o porty i nie
  dokłada drugiego proxy na trasie.
- Proxy Hosty w NPM zakłada hurtowo `bash npm-hosts.sh --create`.

### Tryb 2: Traefik jako brzeg sieci — `USE_BEHIND_NPM=0`

Dla **czystego serwera**, na którym nic nie słucha na 80/443. Traefik przejmuje
te porty, wykrywa nowe kontenery po etykietach Docker i **sam wystawia
certyfikat** (wyzwanie HTTP-01) — bez tokenów DNS, bez restartu reszty. Najmniej
klikania, ale wymaga wolnych portów.

---

## Wymagania wstępne

1. **Serwer** (VPS) z Dockerem. Licz ~400–500 MB RAM na instancję n8n + ~300 MB
   na PostgreSQL. 20 instancji ≈ 10–12 GB RAM **ponad** to, co serwer już zjada.
2. **DNS.** Albo rekord A per uczestnik:

   | Typ | Nazwa | Wartość |
   |-----|-------|---------|
   | A | `user1.n8n` | `IP_SERWERA` |
   | A | `user2.n8n` | `IP_SERWERA` |
   | … | … | … |

   albo — wygodniej — jeden wildcard, który obsłuży też uczestników dopisanych
   w ostatniej chwili:

   | Typ | Nazwa | Wartość |
   |-----|-------|---------|
   | A | `*.n8n` | `IP_SERWERA` |

   > **Uwaga na catch-all.** Jeśli domena ma ogólny wildcard (`*.example.pl`),
   > brakujący rekord **nie zwróci błędu** — cicho wskaże stary serwer, a
   > certyfikat się nie wystawi. Dlatego zawsze weryfikuj `preflight.sh`.
3. **Porty**: w trybie 1 — 80/443 należą do NPM; w trybie 2 — muszą być wolne.

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
- `BASE_DOMAIN=n8n.easyautomate.pl`
- `ACME_EMAIL=twoj@email.pl`
- `USE_BEHIND_NPM=1` (jeśli na serwerze stoi nginx-proxy-manager) lub `0`
- `NPM_EMAIL` / `NPM_PASSWORD` — login do panelu NPM (tylko dla `npm-hosts.sh --create`)
- `POSTGRES_PASSWORD` i `N8N_DB_PASSWORD` — wygeneruj: `openssl rand -hex 16`

### 3. Sprawdź serwer przed instalacją

```bash
bash preflight.sh user{1..20}
```

Weryfikuje: DNS każdej subdomeny (czy naprawdę wskazuje na ten serwer), kto
trzyma porty 80/443, czy kontener NPM jest widoczny, ile zostało RAM-u.
Rusza dalej dopiero, gdy nie ma błędów.

### 4. Dodaj instancje

```bash
bash add-instance.sh user1                  # -> https://user1.<BASE_DOMAIN>
bash add-instance.sh ala ala@firma.pl       # nazwa słowna też działa

for i in $(seq 1 20); do bash add-instance.sh "user$i"; done   # hurtowo
```

Każde wywołanie:
- tworzy bazę `n8n_<nazwa>` i klucz szyfrowania,
- generuje login (`admin+<nazwa>@...`) i losowe hasło,
- podnosi kontener `n8n-<nazwa>` w sieci `n8n-fleet`,
- w trybie 2 od razu rejestruje subdomenę w Traefiku (SSL leci automatycznie),
- dopisuje dostęp do `access-list-dynamic.csv`.

### 5. (Tryb 1) Załóż Proxy Hosty w NPM

```bash
bash npm-hosts.sh                  # podgląd: co i gdzie wpisać, nic nie zmienia
bash npm-hosts.sh --create         # zakłada brakujące hosty przez API NPM
```

Każdy host to: `userN.<BASE_DOMAIN>` → `http://n8n-userN:5678`, **Websockets
Support ON**, SSL Let's Encrypt + Force SSL. Skrypt pomija hosty, które już
istnieją, więc można go puszczać wielokrotnie. Ręcznie w panelu — te same cztery
pola.

### 6. Rozdaj dostępy

```bash
cat access-list-dynamic.csv
```

Kolumny: `name, url, email, password`, np.:

```
"user1","https://user1.n8n.easyautomate.pl","admin+user1@...","xYz123abc"
```

> Sprawdź na pierwszej instancji, czy login z CSV faktycznie wchodzi — część
> wersji n8n zakłada konto właściciela dopiero w przeglądarce, przy pierwszym
> wejściu. Jeśli tak jest, pierwszym punktem agendy niech będzie „załóż konto
> na swojej subdomenie".

---

## Codzienne operacje

| Cel | Komenda |
|---|---|
| Lista instancji + status | `bash list-instances.sh` |
| Dodaj instancję | `bash add-instance.sh user21` |
| Usuń kontener, **zostaw dane** | `bash remove-instance.sh user21` |
| Usuń instancję **z danymi** | `bash remove-instance.sh user21 --purge` |
| Logi instancji | `docker logs n8n-user1` |
| Restart instancji | `docker restart n8n-user1` |
| Podgląd hostów dla NPM | `bash npm-hosts.sh` |
| Logi Traefika (tylko tryb 2) | `docker logs n8n-fleet-traefik-1` |
| Zużycie RAM | `docker stats` |

> `remove-instance.sh <nazwa>` bez `--purge` tylko zdejmuje kontener — baza,
> wolumen i sekrety zostają, więc `add-instance.sh <nazwa>` przywróci instancję
> z tym samym kluczem i danymi. Dopiero `--purge` kasuje dane bezpowrotnie.
> Proxy Host w NPM zostaje w obu przypadkach — usuń go w panelu, jeśli już
> niepotrzebny.

---

## Dodanie uczestnika w trakcie szkolenia

```bash
bash add-instance.sh user21      # kontener + baza + klucz + dostęp
bash npm-hosts.sh --create       # Proxy Host + certyfikat (tryb 1)
```

Jeśli w DNS masz wildcard `*.n8n` — to wszystko. Przy rekordach per subdomena
dodaj najpierw `user21.n8n  A  IP_SERWERA` i odczekaj TTL.

---

## Rozwiązywanie problemów

**„Brak certyfikatu / SSL nie działa"**
- `bash preflight.sh user{1..20}` — najczęstsza przyczyna to subdomena
  wskazująca na inny serwer (patrz uwaga o catch-all wildcardzie wyżej).
- Port 80 musi być publicznie dostępny — Let's Encrypt puka po HTTP.
- Tryb 1: logi certyfikatu są w panelu NPM (SSL Certificates).
  Tryb 2: `docker logs n8n-fleet-traefik-1`.

**502 Bad Gateway w NPM**
- Kontener NPM musi być w sieci `n8n-fleet`:
  `docker network connect n8n-fleet <nazwa-kontenera-npm>`
  (skrypty robią to same; `bash list-instances.sh` pokaże wykryty kontener).
- Sprawdź, czy instancja żyje: `docker ps | grep n8n-user1`.

**n8n „ładuje się w nieskończoność", edytor nie odpowiada**
- Prawie zawsze brak **Websockets Support** w Proxy Hoście. Włącz i zapisz.

**n8n marudzi o secure cookie / nie loguje**
- Wchodzisz po HTTP zamiast HTTPS. W tym wariancie ruch ma iść po HTTPS
  (`Force SSL` w NPM). Do testów po samym IP użyj wariantu z `URUCHOMIENIE.md`.

**Za mało RAM przy wielu instancjach**
- `docker stats` pokaże zużycie, `bash preflight.sh ...` oszacuje z góry.

---

## Czym się różni od wariantu statycznego

| | `docker-compose.prod.yaml` (statyczny) | flota dynamiczna (ten plik) |
|---|---|---|
| Liczba instancji | sztywno 22, edycja YAML | dowolna, jednym poleceniem |
| Adres | `http://IP:port` | `https://user1.domena` |
| SSL | brak | tak (NPM albo Traefik) |
| Dodanie instancji | edycja compose + restart | `bash add-instance.sh <n>` |
| Izolacja danych | osobna baza | osobna baza + osobny klucz szyfrowania |

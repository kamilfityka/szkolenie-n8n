# n8n — dynamiczna flota instancji z subdomenami i SSL

Ten wariant pozwala **dodawać i usuwać instancje n8n w locie**, każda pod własną
subdomeną i własnym HTTPS. Nie musisz z góry deklarować, ile instancji
potrzebujesz — dziś 16, jutro 30, jednym poleceniem.

**Jedna subdomena = jeden kontener = osobna baza i osobny klucz szyfrowania.**
Uczestnicy nie widzą nawzajem swoich workflowów ani credentiali.

To alternatywa dla statycznego `docker-compose.prod.yaml` (22 sztywne instancje
po `IP:port`). Oba warianty mogą leżeć obok siebie w repo.

---

## Jak to działa

Frontem jest **nginx-proxy-manager** — trzyma porty 80/443, robi SSL i kieruje ruch
po nazwie domeny wprost do kontenera uczestnika. Instancje n8n dołączają do sieci
docker, w której stoi NPM (sieć zewnętrzna, tworzy ją compose NPM-a).

```
                       user1.n8n.easyautomate.pl ─┐
                       user2.n8n.easyautomate.pl ─┤ (rekordy A → IP serwera)
                                              ... ─┘
                                    │
                        ┌───────────▼────────────┐
                        │  nginx-proxy-manager   │  80/443, SSL per subdomena
                        │  (Proxy Host per user) │  Websockets ON
                        └───────────┬────────────┘
                     sieć `nginx-proxy-manager_default` (zewnętrzna)
        ┌───────────────┬───────────┴───────┬────────────────┐
   n8n-user1        n8n-user2          n8n-user3   ...    n8n-userN
        │                │                  │                │
        └────────────────┴── sieć `n8n-fleet-internal` ───────┴─── PostgreSQL
```

- NPM trafia do kontenera **po nazwie**: `n8n-user1`, port `5678`.
- Port 5678 jest tylko **wystawiony (`expose`)** wewnątrz sieci docker —
  **żaden kontener nie publikuje portu na hosta**. Jedyne wejście z internetu
  prowadzi przez NPM.
- PostgreSQL stoi wyłącznie w prywatnej sieci `n8n-fleet-internal`, więc nie jest
  widoczny dla pozostałych kontenerów wpiętych w sieć NPM-a.
- Żadnego Traefika — NPM jest jedynym proxy na trasie.

Nazwę sieci NPM-a ustawia się w `.env.dynamic`:

```
NPM_NETWORK=nginx-proxy-manager_default
```

Sprawdzisz ją poleceniem `docker network ls` (albo `docker inspect <kontener-npm>`).
Skrypty przerywają pracę z czytelnym komunikatem, jeśli ta sieć nie istnieje lub
NPM stoi w innej.

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
3. **nginx-proxy-manager** działający na tym serwerze (trzyma 80/443) i nazwa jego sieci docker.

---

## Najkrótsza droga: jedno polecenie

```bash
git clone https://github.com/kamilfityka/szkolenie-n8n.git
cd szkolenie-n8n
bash setup-fleet.sh --count 16
```

`setup-fleet.sh` przechodzi całą drogę: dopyta o domenę i dane do nginx-proxy-managera,
sprawdzi serwer (DNS, porty, RAM), postawi instancje, założy Proxy Hosty z certyfikatami
i na koniec wypisze tabelę:

```
 UCZESTNIK  ADRES                              LOGIN                             HASŁO           KONTENER
 user1      https://user1.n8n.easyautomate.pl  admin+user1@n8n.easyautomate.pl   376nXiklW0BJ3q  n8n-user1
 user2      https://user2.n8n.easyautomate.pl  admin+user2@n8n.easyautomate.pl   cqYlM8NYfwSFSo  n8n-user2
 ...
```

To samo trafia do `dostepy.md` (gotowe bloki do rozesłania) i `access-list-dynamic.csv`.

Warianty:

```bash
bash setup-fleet.sh --count 20                       # user1..user20
bash setup-fleet.sh --prefix kursant --count 8       # kursant1..kursant8
bash setup-fleet.sh --users ala=ala@firma.pl,bartek  # nazwy własne, własne loginy
bash setup-fleet.sh --count 16 --skip-npm            # bez dotykania NPM
```

Skrypt jest **idempotentny** — można go puścić ponownie. Istniejący uczestnicy zachowują
hasła, klucze szyfrowania i dane; dokładane są tylko brakujące instancje.

Poniżej to samo krok po kroku, gdy chcesz mieć kontrolę nad każdym etapem.

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
- `NPM_NETWORK` — sieć docker nginx-proxy-managera (`docker network ls`)
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
- podnosi kontener `n8n-<nazwa>` w sieci nginx-proxy-managera (bez portów na hoście),
- dopisuje dostęp do `access-list-dynamic.csv`.

### 5. Załóż Proxy Hosty w NPM

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
| Postawić/uzupełnić całą flotę | `bash setup-fleet.sh --count 16` |
| Lista instancji + status | `bash list-instances.sh` |
| Dostępy do rozdania | `cat dostepy.md` |
| Dodaj instancję | `bash add-instance.sh user21` |
| Usuń kontener, **zostaw dane** | `bash remove-instance.sh user21` |
| Usuń instancję **z danymi** | `bash remove-instance.sh user21 --purge` |
| Logi instancji | `docker logs n8n-user1` |
| Restart instancji | `docker restart n8n-user1` |
| Podgląd hostów dla NPM | `bash npm-hosts.sh` |
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
- Logi wystawiania certyfikatu są w panelu NPM (zakładka SSL Certificates).

**502 Bad Gateway w NPM**
- NPM i kontener n8n muszą być w **tej samej sieci** docker. Sprawdź:
  `bash list-instances.sh` (pokaże wykrytą sieć i kontener NPM) oraz
  `docker network inspect $NPM_NETWORK | grep n8n-`.
- Jeśli NPM stoi w innej sieci, popraw `NPM_NETWORK` w `.env.dynamic`
  i przerenderuj instancje (`bash setup-fleet.sh --count 16`).
- Sprawdź, czy instancja żyje: `docker ps | grep n8n-user1`.
- Forward Hostname to **nazwa kontenera** (`n8n-user1`), nie `localhost` ani IP.

**n8n „ładuje się w nieskończoność", edytor nie odpowiada**
- Prawie zawsze brak **Websockets Support** w Proxy Hoście. Włącz i zapisz.

**„Problem running workflow — Lost connection to the server"**
- W przeglądarce (Network, filtr WS) sprawdź żądanie `/rest/push`:
  - brak połączenia albo 400/502 → Websockets Support wyłączone w Proxy Hoście,
  - 101, ale zrywa się po ~minucie → timeouty proxy; w zakładce Advanced hosta
    dodaj `proxy_read_timeout 3600s; proxy_send_timeout 3600s;`,
  - **401** → n8n odrzuca ciasteczko sesji na websockecie. Wyloguj, wyczyść
    ciasteczka domeny, zaloguj; sprawdź w oknie prywatnym (rozszerzenia
    prywatności potrafią odciąć cookie na upgrade). Jeśli nie pomaga, ustaw
    w `.env.dynamic` `N8N_PUSH_BACKEND=sse` i przerenderuj flotę
    (`bash setup-fleet.sh --count 20`) — push idzie wtedy zwykłym HTTP.
- Zmiany w `docker-compose.yaml` **nie dotyczą floty** — instancje renderuje
  `_lib.sh` do `instances/<nazwa>.yaml`. Ustawienia zmieniasz w `.env.dynamic`.
- Przypnij wersję obrazu (`N8N_IMAGE` w `.env.dynamic`), żeby wszystkie
  instancje były identyczne i nie zmieniały się przy kolejnym `up`.

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
| Adres | `http://IP:port` | `https://user1.domena` (port tylko w sieci docker) |
| SSL | brak | tak (nginx-proxy-manager) |
| Dodanie instancji | edycja compose + restart | `bash add-instance.sh <n>` |
| Izolacja danych | osobna baza | osobna baza + osobny klucz szyfrowania |

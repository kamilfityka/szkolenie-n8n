# Uruchamianie szkolenia n8n — krok po kroku

## Co dostaniesz

22 izolowane instancje n8n, każda na osobnym subpath HTTPS (`/01/` … `/22/`),
z osobną bazą danych i kontem użytkownika. Wszystko za jednym nginx na porcie
443 z SSL. Każdy uczestnik dostaje swój URL, login i hasło.

---

## Wymagania

- VPS z Ubuntu 24 / 25 (min. 12 GB RAM — rekomendowany vroot_JUMP! lub OVH VPS-2)
- Dostęp SSH do serwera (publiczne IP, np. `51.83.32.60`)
- Zainstalowany Git na swoim komputerze

---

## KROK 1 — Przygotowanie serwera

Zaloguj się przez SSH:

```bash
ssh root@51.83.32.60
```

Zainstaluj Docker:

```bash
curl -fsSL https://get.docker.com | sh
```

Sprawdź czy działa:

```bash
docker --version
docker compose version
```

---

## KROK 2 — Pobranie projektu na serwer

```bash
git clone https://github.com/kamilfityka/szkolenie-n8n.git
cd szkolenie-n8n
```

---

## KROK 3 — Wpisz uczestników

Otwórz plik `participants.csv` i zastąp placeholdery prawdziwymi danymi:

```bash
nano participants.csv
```

Format pliku:

```
nr,name,email
01,Jan Kowalski,jan@firma.pl
02,Anna Nowak,anna@firma.pl
...
22,Ostatni Uczestnik,ostatni@firma.pl
```

> **Uwaga:** numery muszą być od `01` do `22` i muszą odpowiadać kolejności —
> uczestnik `01` dostanie URL `https://51.83.32.60/01/`, uczestnik `02` → `/02/` itd.

Zapisz plik: `Ctrl+O`, `Enter`, `Ctrl+X`

---

## KROK 4 — Wygeneruj hasła i klucze

```bash
bash generate-env.sh
```

Skrypt zapyta czy nadpisać istniejący plik — wpisz `t` i Enter.

Powstaną dwa pliki:
- `.env.prod` — hasła i klucze szyfrowania (nie udostępniaj!).
  `VPS_IP` jest już ustawione na `51.83.32.60` — zmień jeśli używasz innego adresu.
- `access-list.txt` — tabela dostępów dla uczestników z gotowymi URL-ami HTTPS.

---

## KROK 5 — Wygeneruj certyfikat SSL

```bash
bash generate-certs.sh
```

Skrypt odczyta `VPS_IP` z `.env.prod` i zapisze self-signed certyfikat
w `nginx/certs/cert.pem` + `key.pem` (ważność 365 dni).

> Przeglądarka pokaże ostrzeżenie o self-signed cert — kliknij
> „Zaawansowane" → „Przejdź do strony" lub dodaj wyjątek.

---

## KROK 6 — Otwórz porty w firewallu

Nginx terminuje SSL na 443, więc otwieramy tylko 80/443 (plus SSH):

```bash
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable
```

---

## KROK 7 — Uruchom wszystkie instancje

```bash
docker compose -f docker-compose.prod.yaml --env-file .env.prod up -d
```

Pierwsze uruchomienie pobiera obrazy Docker — może potrwać 2–5 minut.

Sprawdź czy wszystko działa:

```bash
docker compose -f docker-compose.prod.yaml ps
```

Wszystkie 22 kontenery n8n + nginx + postgres powinny mieć status `running`.

---

## KROK 8 — Weryfikacja

Otwórz w przeglądarce adres pierwszej instancji:

```
https://51.83.32.60/01/
```

Powinien pojawić się ekran logowania n8n. Zaloguj się danymi uczestnika nr 01
z `access-list.txt`.

---

## KROK 9 — Rozdaj dostępy uczestnikom

```bash
cat access-list.txt
```

Wydrukuj lub przepisz każdemu uczestnikowi jego wiersz:

```
Nr  Imię i Nazwisko        URL (HTTPS)                  Login (e-mail)     Hasło
01  Jan Kowalski           https://51.83.32.60/01/      jan@firma.pl       xYz123abc
```

---

## Po szkoleniu — zatrzymanie i czyszczenie

Zatrzymaj kontenery:

```bash
docker compose -f docker-compose.prod.yaml down
```

Jeśli chcesz też usunąć dane (bazy, pliki n8n):

```bash
docker compose -f docker-compose.prod.yaml down -v
```

> **Uwaga:** `-v` usuwa wszystkie wolumeny — dane uczestników zostaną trwale skasowane.

---

## Przydatne komendy

| Co chcesz zrobić                | Komenda |
|---------------------------------|---------|
| Sprawdzić logi instancji        | `docker logs n8n-01` |
| Zrestartować jedną instancję    | `docker restart n8n-01` |
| Zrestartować nginx              | `docker restart $(docker ps -qf name=nginx)` |
| Sprawdzić zużycie RAM           | `docker stats` |
| Sprawdzić wolne miejsce         | `df -h` |
| Zobaczyć IP serwera             | `curl ifconfig.me` |

---

## Mapa URL

Wszystkie instancje są dostępne po HTTPS na porcie 443, routing po ścieżce:

| Uczestnik | URL                            |
|-----------|--------------------------------|
| 01        | https://51.83.32.60/01/        |
| 02        | https://51.83.32.60/02/        |
| 03        | https://51.83.32.60/03/        |
| 04        | https://51.83.32.60/04/        |
| 05        | https://51.83.32.60/05/        |
| 06        | https://51.83.32.60/06/        |
| 07        | https://51.83.32.60/07/        |
| 08        | https://51.83.32.60/08/        |
| 09        | https://51.83.32.60/09/        |
| 10        | https://51.83.32.60/10/        |
| 11        | https://51.83.32.60/11/        |
| 12        | https://51.83.32.60/12/        |
| 13        | https://51.83.32.60/13/        |
| 14        | https://51.83.32.60/14/        |
| 15        | https://51.83.32.60/15/        |
| 16        | https://51.83.32.60/16/        |
| 17        | https://51.83.32.60/17/        |
| 18        | https://51.83.32.60/18/        |
| 19        | https://51.83.32.60/19/        |
| 20        | https://51.83.32.60/20/        |
| 21        | https://51.83.32.60/21/        |
| 22        | https://51.83.32.60/22/        |

> Bezpośrednie porty `5678`–`5699` są też wystawione przez Docker (HTTP, bez SSL),
> ale do szkolenia używamy **wyłącznie** URL-i HTTPS powyżej.

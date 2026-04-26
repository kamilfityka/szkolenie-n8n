# Uruchamianie szkolenia n8n — krok po kroku

## Co dostaniesz

20 izolowanych instancji n8n, każda na osobnym porcie, z osobną bazą danych i kontem użytkownika. Każdy uczestnik dostaje swój URL, login i hasło.

---

## Wymagania

- VPS z Ubuntu 24 / 25 (min. 12 GB RAM — rekomendowany vroot_JUMP! lub OVH VPS-2)
- Dostęp SSH do serwera
- Zainstalowany Git na swoim komputerze

---

## KROK 1 — Przygotowanie serwera

Zaloguj się przez SSH:

```bash
ssh root@TWOJ_IP_SERWERA
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
03,Piotr Wiśniewski,piotr@firma.pl
...
```

> **Uwaga:** numery muszą być od `01` do `20` i muszą odpowiadać kolejności — uczestnik `01` dostanie port `5678`, uczestnik `02` port `5679` itd.

Zapisz plik: `Ctrl+O`, `Enter`, `Ctrl+X`

---

## KROK 4 — Wygeneruj hasła i klucze

```bash
bash generate-env.sh
```

Skrypt zapyta czy nadpisać istniejący plik — wpisz `t` i Enter.

Powstaną dwa pliki:
- `.env.prod` — hasła i klucze szyfrowania (nie udostępniaj!)
- `access-list.txt` — tabela dostępów dla uczestników

---

## KROK 5 — Wpisz adres IP serwera

```bash
nano .env.prod
```

Znajdź linię:

```
VPS_IP=CHANGE_ME
```

Zamień `CHANGE_ME` na publiczny adres IP serwera (sprawdzisz go w panelu OVH/vroot lub komendą `curl ifconfig.me`):

```
VPS_IP=1.2.3.4
```

Zapisz plik: `Ctrl+O`, `Enter`, `Ctrl+X`

---

## KROK 6 — Zaktualizuj access-list.txt

Po wpisaniu IP otwórz `access-list.txt` i ręcznie zastąp `VPS_IP` rzeczywistym adresem — wtedy masz gotową tabelę z prawdziwymi linkami do wydruku.

```bash
sed -i 's/VPS_IP/1.2.3.4/g' access-list.txt
```

(zamień `1.2.3.4` na swój adres IP)

---

## KROK 7 — Otwórz porty w firewallu

```bash
ufw allow 22
ufw allow 5678:5697/tcp
ufw enable
```

---

## KROK 8 — Uruchom wszystkie instancje

```bash
docker compose -f docker-compose.prod.yaml --env-file .env.prod up -d
```

Pierwsze uruchomienie pobiera obrazy Docker — może potrwać 2–5 minut.

Sprawdź czy wszystko działa:

```bash
docker compose -f docker-compose.prod.yaml ps
```

Wszystkie kontenery powinny mieć status `running`. Jeśli któryś ma `starting` — poczekaj chwilę i sprawdź ponownie.

---

## KROK 9 — Weryfikacja

Otwórz w przeglądarce adres jednej instancji:

```
http://TWOJ_IP:5678
```

Powinien pojawić się ekran logowania n8n. Zaloguj się danymi uczestnika nr 01 z `access-list.txt`.

---

## KROK 10 — Rozdaj dostępy uczestnikom

Otwórz `access-list.txt`:

```bash
cat access-list.txt
```

Wydrukuj lub przepisz każdemu uczestnikowi jego wiersz:

```
Nr  Imię i Nazwisko   URL                      Login              Hasło
01  Jan Kowalski      http://1.2.3.4:5678      jan@firma.pl       xYz123abc
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

| Co chcesz zrobić | Komenda |
|---|---|
| Sprawdzić logi instancji | `docker logs n8n-01` |
| Zrestartować jedną instancję | `docker restart n8n-01` |
| Sprawdzić zużycie RAM | `docker stats` |
| Sprawdzić wolne miejsce | `df -h` |
| Zobaczyć IP serwera | `curl ifconfig.me` |

---

## Mapa portów

| Uczestnik | Port | URL |
|---|---|---|
| 01 | 5678 | http://IP:5678 |
| 02 | 5679 | http://IP:5679 |
| 03 | 5680 | http://IP:5680 |
| 04 | 5681 | http://IP:5681 |
| 05 | 5682 | http://IP:5682 |
| 06 | 5683 | http://IP:5683 |
| 07 | 5684 | http://IP:5684 |
| 08 | 5685 | http://IP:5685 |
| 09 | 5686 | http://IP:5686 |
| 10 | 5687 | http://IP:5687 |
| 11 | 5688 | http://IP:5688 |
| 12 | 5689 | http://IP:5689 |
| 13 | 5690 | http://IP:5690 |
| 14 | 5691 | http://IP:5691 |
| 15 | 5692 | http://IP:5692 |
| 16 | 5693 | http://IP:5693 |
| 17 | 5694 | http://IP:5694 |
| 18 | 5695 | http://IP:5695 |
| 19 | 5696 | http://IP:5696 |
| 20 | 5697 | http://IP:5697 |

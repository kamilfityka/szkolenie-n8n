# n8n — jedna instancja, wielu użytkowników, za nginx-proxy-manager

Jedna instancja n8n pod `szkolenie-n8n.easyautomate.pl`, z wbudowanym
zarządzaniem użytkownikami (owner zaprasza kolejne osoby). SSL robi
nginx-proxy-manager. **Nie wymaga wildcard DNS** — wystarczy jeden zwykły
rekord A.

---

## Wymagania

1. Serwer z Dockerem, na którym **działa już nginx-proxy-manager** (NPM trzyma
   porty 80/443).
2. Rekord DNS (pojedynczy, zwykły):

   | Typ | Nazwa        | Wartość      |
   |-----|--------------|--------------|
   | A   | `szkolenie-n8n` (w strefie `easyautomate.pl`) | `IP_SERWERA` |

3. Sieć NPM istnieje w Dockerze. Sprawdź nazwę:
   ```bash
   docker network ls | grep nginx
   ```
   Jeśli nazywa się inaczej niż `nginx-proxy-manager_default`, popraw ją w
   `docker-compose.single.yaml` (sekcja `networks:`).

---

## Uruchomienie

```bash
# 1. Konfiguracja
cp .env.single.example .env.single
nano .env.single           # ustaw POSTGRES_PASSWORD, N8N_ENCRYPTION_KEY, N8N_HOST
#   klucz szyfrowania:  openssl rand -hex 24
#   hasło do bazy:      openssl rand -hex 16

# 2. Start
docker compose -f docker-compose.single.yaml --env-file .env.single up -d

# 3. Sprawdź
docker compose -f docker-compose.single.yaml ps
docker logs -f n8n-single
```

n8n nie publikuje portów na świat — wychodzi tylko przez NPM.

---

## Konfiguracja nginx-proxy-manager

W panelu NPM → **Hosts → Proxy Hosts → Add Proxy Host**:

**Zakładka Details:**
- Domain Names: `szkolenie-n8n.easyautomate.pl`
- Scheme: `http`
- Forward Hostname / IP: `n8n-single`  ← nazwa kontenera
- Forward Port: `5678`
- **Websockets Support: WŁĄCZ** (n8n tego wymaga — bez tego edytor się „wiesza")
- Block Common Exploits: można włączyć

**Zakładka SSL:**
- SSL Certificate: **Request a new SSL Certificate** (Let's Encrypt)
- Force SSL: WŁĄCZ
- HTTP/2 Support: WŁĄCZ
- Zaznacz zgodę na warunki Let's Encrypt

> Forward Hostname `n8n-single` działa, bo kontener n8n jest podłączony do tej
> samej sieci Dockera co NPM (`nginx-proxy-manager_default`). Jeśli NPM woła po
> nazwie i nie łączy — upewnij się, że obie usługi są w tej samej sieci
> (`docker network inspect nginx-proxy-manager_default`).

Po zapisaniu wejdź na `https://szkolenie-n8n.easyautomate.pl` — powinien pojawić
się ekran zakładania konta.

---

## Dodawanie użytkowników

1. Pierwsza osoba, która wejdzie na URL i założy konto, zostaje **Ownerem**
   (administrator). Zrób to Ty.
2. **Settings → Users → Invite** — podaj adresy e-mail uczestników.
   - Bez SMTP: n8n pokaże **link zaproszenia** do każdego użytkownika — skopiuj
     i wyślij ręcznie (np. Slackiem/mailem).
   - Z SMTP (uzupełnij `.env.single` i zrestartuj): zaproszenia idą e-mailem
     automatycznie.
3. Każdy użytkownik ma swoją przestrzeń roboczą i własne workflowy.

> Wbudowane zarządzanie wieloma użytkownikami jest w darmowej wersji
> self-hosted. Zaawansowane role, projekty zespołowe i SSO są w wersjach
> płatnych — do szkolenia darmowe konta użytkowników w zupełności wystarczą.

---

## Częste operacje

| Cel | Komenda |
|---|---|
| Logi | `docker logs -f n8n-single` |
| Restart | `docker compose -f docker-compose.single.yaml --env-file .env.single restart` |
| Stop | `docker compose -f docker-compose.single.yaml --env-file .env.single down` |
| Stop + kasacja danych | `... down -v` (usuwa bazę i pliki n8n — nieodwracalne) |
| Aktualizacja n8n | `docker compose -f docker-compose.single.yaml --env-file .env.single pull && ... up -d` |

---

## Rozwiązywanie problemów

**Edytor się „wiesza" / brak podglądu wykonań na żywo**
→ Włącz **Websockets Support** w Proxy Host w NPM.

**„error: Bad Gateway" w NPM**
→ Kontener n8n nie startuje lub NPM nie widzi go po nazwie. Sprawdź
`docker logs n8n-single` i czy obie usługi są w sieci
`nginx-proxy-manager_default`.

**Pętla przekierowań / ostrzeżenie o cookie**
→ Upewnij się, że w Proxy Host włączony jest SSL + Force SSL (n8n ma
`N8N_PROTOCOL=https` i `N8N_SECURE_COOKIE=true`, więc musi chodzić po HTTPS).

**Zmieniłem `N8N_ENCRYPTION_KEY` i credentiale przestały działać**
→ Klucza NIE wolno zmieniać po pierwszym uruchomieniu. Przywróć poprzednią
wartość.

---

## Skalowanie później

Ten wariant to jedna instancja w trybie „main". Jeśli obciążenie wzrośnie,
można dołożyć Redis + workery (tryb `queue`) — patrz istniejący
`docker-compose.yaml` w repo, który pokazuje ten układ.

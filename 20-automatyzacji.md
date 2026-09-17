# 20 automatyzacji na szkolenie „Narzędzia no-code/low-code AI dla menedżerów”

**Środowisko:** n8n (własna instancja dla każdego uczestnika) + konto Google (Gmail, Kalendarz, Dysk, Arkusze, Dokumenty) + klucz OpenAI.
**Grupa:** maks. 16 osób, 2 dni.
**Założenie:** uczestnicy **nie** przynoszą żadnych własnych dostępów (SharePoint, Excel, Outlook, ERP). Wszystko, czego potrzebują, dostają od prowadzącego w dniu szkolenia.

Dokument jest uzupełnieniem `szkolenie-n8n-ul.md` (tam: instalacja, słownik, metodologia promptów). Tutaj: katalog ćwiczeń i plan.

---

## Spis treści

1. [Dlaczego Gmail zamiast Outlook/SharePoint i jak to przełożyć na firmę](#1-mapowanie-firma--szkolenie)
2. [Co przygotowuje prowadzący (seed data)](#2-co-przygotowuje-prowadzący)
3. [Katalog 20 automatyzacji](#3-katalog-20-automatyzacji)
   - [Blok 0 — Rozgrzewka (1–3)](#blok-0--rozgrzewka)
   - [Blok 1 — Zadania i otwarte tematy menedżera (4–9)](#blok-1--zadania-i-otwarte-tematy-menedżera)
   - [Blok 2 — Agent AI do spotkań (10–14)](#blok-2--agent-ai-do-spotkań)
   - [Blok 3 — Ryzyka operacyjne i jakościowe / FMEA (15–20)](#blok-3--ryzyka-operacyjne-i-jakościowe-fmea)
4. [Plan 2 dni](#4-plan-2-dni)
5. [Osoba dołączająca tylko drugiego dnia](#5-osoba-dołączająca-tylko-drugiego-dnia)
6. [Checklista prowadzącego](#6-checklista-prowadzącego)

---

## 1. Mapowanie firma → szkolenie

Uczestnik pyta o Outlook, Teams, SharePoint, Excel, ERP i Power BI. Na szkoleniu nie mamy do tego dostępów, ale **wzorzec automatyzacji jest identyczny** — zmienia się tylko credential i node. Google jest tu wygodny, bo **jedno logowanie OAuth** daje od razu pocztę, kalendarz, pliki, arkusze i dokumenty.

| W firmie uczestnika | Na szkoleniu | Node n8n na szkoleniu | Node n8n w firmie (do pokazania na slajdzie) |
| :--- | :--- | :--- | :--- |
| Outlook (poczta) | Gmail | `Gmail Trigger`, `Gmail` | `Microsoft Outlook Trigger`, `Microsoft Outlook` |
| Kalendarz Outlook | Google Calendar | `Google Calendar` | `Microsoft Outlook` (Calendar) |
| MS Teams | Gmail / n8n Chat / Slack (opcjonalnie) | `Chat Trigger`, `Gmail` | `Microsoft Teams` |
| SharePoint (biblioteka dokumentów) | Google Drive | `Google Drive`, `Google Docs` | `Microsoft SharePoint`, `Microsoft OneDrive` |
| Excel | Google Sheets | `Google Sheets` | `Microsoft Excel 365` |
| ERP (eksport / API) | plik CSV na Dysku **lub** webhook z „ERP” | `Google Drive Trigger`, `Webhook`, `Extract from File` | `HTTP Request`, `Postgres`/`MSSQL`, `SAP` (community) |
| Power BI | Google Sheets z wykresem / Looker Studio | `Google Sheets` | `HTTP Request` → Power BI REST API (push dataset) |

**Komunikat do grupy na starcie:** „Dziś uczycie się wzorca: *trigger → pobierz dane → AI → zapisz/wyślij*. W poniedziałek w firmie podmieniacie Gmail na Outlook i Sheets na Excel — reszta zostaje.”

---

## 2. Co przygotowuje prowadzący

Wszystko poniżej robi prowadzący **przed** szkoleniem. Uczestnik pierwszego dnia dostaje kartkę: adres instancji n8n, login/hasło do n8n, login/hasło do konta Google, klucz OpenAI.

### 2.1 Konta i dostępy

| Element | Ilość | Uwagi |
| :--- | :--- | :--- |
| Instancja n8n | 16 + 1 (prowadzący) | `setup-fleet.sh` z tego repo |
| Konto Google | 16 + 1 | Najlepiej Google Workspace na własnej domenie (np. `uczestnik01@szkolenie.twojadomena.pl`). Zwykłe konta @gmail.com też działają, ale zakładanie 16 sztuk jest uciążliwe (weryfikacja telefonem). |
| Google Cloud: OAuth Client | 1 wspólny | Włączone API: Gmail, Calendar, Drive, Sheets, Docs. Aplikacja w trybie **Testing** + wszystkie 16 kont dodane jako *test users* (limit 100). Redirect URI dla **każdej** instancji n8n (`https://<instancja>/rest/oauth2-credential/callback`). |
| Klucz OpenAI | 1 klucz per uczestnik **lub** 1 wspólny z limitem | Osobne klucze = łatwiej wyłączyć jeden po szkoleniu. Budżet: ~2–3 USD/os. przy gpt-4.1-mini. |

Uczestnik pierwszego dnia tworzy w n8n **3 credentiale**: `Google OAuth2` (jeden, używany przez Gmail/Calendar/Drive/Sheets/Docs), `OpenAI`, i to wszystko. Nie ma SMTP, nie ma ClickUp.

### 2.2 Seed data — „udawana firma”

Automatyzacje muszą mieć na czym pracować. Prowadzący uruchamia **jeden workflow-seeder** na swojej instancji n8n, który dla każdego konta z `participants.csv`:

1. **Wysyła ~15 maili** na skrzynkę uczestnika (od fikcyjnych osób: szef, klient, dostawca, HR, dział jakości). W treści: prośby, terminy, reklamacja, raport NCR, „przypominam o…”, spam. Każdy mail celowo zawiera 0–3 action itemy.
2. **Kopiuje 4 szablony Google Sheets** na Dysk uczestnika (`Google Drive → Copy file`, udostępnione z konta prowadzącego):
   - `Rejestr otwartych spraw` (kolumny: ID, temat, właściciel, źródło, termin, status, priorytet, utworzono)
   - `FMEA – linia montażowa` (funkcja, potencjalna wada, S, O, D, RPN, działanie korygujące, odpowiedzialny, termin, status)
   - `Harmonogram projektu` (zadanie, plan start, plan koniec, faktyczny start, faktyczny koniec, % ukończenia, właściciel)
   - `Lista wymaganych dokumentów` (nazwa dokumentu, projekt, wymagany, odpowiedzialny)
3. **Tworzy folder `Projekt Alfa` na Dysku** z 5–6 dokumentami (specyfikacja, protokół z poprzedniego spotkania, raport audytu, instrukcja) — 2 dokumenty z listy wymaganych celowo **brakuje**.
4. **Tworzy 3 wydarzenia w kalendarzu na jutro** z uczestnikami (te same fikcyjne osoby, co w mailach) i opisem odsyłającym do `Projekt Alfa`.
5. **Wrzuca plik `eksport_erp.csv`** na Dysk (zamówienia, terminy dostaw, statusy, kilka opóźnionych).

Dzięki temu każde ćwiczenie od razu daje **realny wynik na realnych danych**, a nie „hello world”.

---

## 3. Katalog 20 automatyzacji

Legenda:
- 🛠 **budujemy od zera** — uczestnicy klikają razem z prowadzącym
- 📦 **import + modyfikacja** — prowadzący daje JSON, grupa rozumie i zmienia
- 🎬 **demo** — pokaz prowadzącego, uczestnik dostaje JSON do domu
- ⏱ czas z buforem na debug w grupie 16 osób
- Poziom: ★ (klik-klik) / ★★ (expressions, IF, pętle) / ★★★ (AI Agent z narzędziami, Code)

Każda automatyzacja ma sekcję **W firmie:** — czyli jak to samo brzmi po podmianie na Outlook/SharePoint/Excel.

---

### Blok 0 — Rozgrzewka

#### 1. „Zgłoś temat” — formularz → AI → mail 🛠 ★ ⏱ 30 min

**Cel:** pierwszy działający workflow w 30 minut. Uczy: trigger, credential, expression `{{ $json.pole }}`, test krok po kroku.

**Przepływ:** `n8n Form Trigger` (pola: temat, opis, kto zgłasza) → `OpenAI` (nadaj priorytet 1–3 i zaproponuj właściciela z listy działów) → `Gmail: Send` (do zgłaszającego: „przyjęliśmy, priorytet X”).

**Dane wejściowe:** uczestnik sam wypełnia formularz. Zero zależności zewnętrznych.

**W firmie:** Microsoft Forms / formularz w Teams → ten sam AI → Outlook.

#### 2. Klasyfikator skrzynki — pilne / do wiadomości / spam 🛠 ★★ ⏱ 45 min

**Cel:** przeniesienie istniejącego scenariusza 2 (`Email AI Agent — sentyment + intencja + draft.json`) na Gmail. Uczy: Structured Output Parser, etykiety, logowanie do arkusza.

**Przepływ:** `Gmail Trigger` (nowy mail, co 1 min) → `Basic LLM Chain` + `Structured Output Parser` (intencja, pilność 1–5, sentyment, czy wymaga odpowiedzi, streszczenie 1 zdanie) → `Switch` po pilności → `Gmail: Add Label` (`PILNE` / `DO WIADOMOŚCI` / `SPAM`) → `Google Sheets: Append` (log).

**Dane wejściowe:** seedowane maile. Prowadzący w trakcie „dosyła” 2–3 nowe maile do wszystkich, żeby trigger odpalił się na żywo.

**W firmie:** Outlook Trigger → te same node'y AI → kategorie Outlooka.

#### 3. Draft odpowiedzi z człowiekiem w pętli 📦 ★★ ⏱ 30 min

**Cel:** pokazać zasadę *human in the loop* — AI **nie wysyła**, tylko przygotowuje.

**Przepływ:** rozszerzenie #2: gałąź „wymaga odpowiedzi = true” → `OpenAI` (draft odpowiedzi w tonie menedżera, po polsku, max 120 słów, z 2 wariantami) → `Gmail: Create Draft` w tym samym wątku.

**Wariant zaawansowany (demo):** node `Gmail: Send and Wait for Approval` — mail do menedżera z przyciskami *Zatwierdź / Odrzuć*, dopiero wtedy wysyłka.

**W firmie:** Outlook: Create Draft; zatwierdzanie przez Teams Adaptive Card.

---

### Blok 1 — Zadania i otwarte tematy menedżera

> Odpowiedź na obszar 1 uczestnika: identyfikacja action items z poczty/komunikacji, przypisywanie właścicieli, monitorowanie terminów, dashboard otwartych spraw.

#### 4. Action items z maila → Rejestr otwartych spraw 🛠 ★★ ⏱ 45 min

**Cel:** serce całego bloku. Z każdego maila wyciągnąć listę zadań ze strukturą i wpisać do arkusza.

**Przepływ:** `Gmail Trigger` → `Basic LLM Chain` + `Structured Output Parser` (tablica: `zadanie`, `właściciel` (wybierz z listy zespołu przekazanej w prompcie), `termin` (ISO, null jeśli brak), `priorytet`) → `Split Out` (jeden item = jedno zadanie) → `Code` (nadaj ID `T-0001`, dopisz link do maila `https://mail.google.com/mail/#all/{{threadId}}`) → `Google Sheets: Append` (`Rejestr otwartych spraw`).

**Kluczowa lekcja promptowa:** lista zespołu i dzisiejsza data w prompcie, inaczej AI zmyśla właścicieli i „za tydzień” zostaje tekstem.

**W firmie:** Outlook Trigger → Excel 365: Append row / SharePoint List: Create item / Planner: Create task.

#### 5. Action items z notatki ze spotkania → zadania + mail do właścicieli 📦 ★★ ⏱ 30 min

**Cel:** to samo co #4, ale źródłem jest dokument (protokół) zamiast maila. Uczy: czytanie Google Docs, pętla `Loop Over Items`, mail per właściciel.

**Przepływ:** `n8n Form Trigger` (pole: link do Google Doc **lub** wklejony tekst) → `Google Docs: Get` → LLM + Parser (jak w #4) → `Google Sheets: Append` → `Loop Over Items` → `Gmail: Send` („Przypisano Ci zadanie X, termin Y, źródło: protokół Z”).

**Dane wejściowe:** `Protokół – spotkanie 12.09` w folderze `Projekt Alfa`.

**W firmie:** SharePoint: Get file → Word → Outlook/Teams.

#### 6. Strażnik terminów — codzienne przypomnienia i eskalacja 🛠 ★★ ⏱ 40 min

**Cel:** monitorowanie terminów. Uczy: `Schedule Trigger`, filtrowanie po datach, `IF` z eskalacją.

**Przepływ:** `Schedule Trigger` (codziennie 7:30) → `Google Sheets: Get rows` (status ≠ zamknięte) → `Filter` (termin ≤ dziś + 2 dni) → `IF` (termin < dziś?) → **tak:** `Gmail` do właściciela **i** do menedżera (eskalacja, w tytule `[PRZETERMINOWANE]`); **nie:** `Gmail` do właściciela (przypomnienie) → `Google Sheets: Update` (kolumna `ostatnie_przypomnienie`).

**Trik szkoleniowy:** w seedowanym arkuszu 3 zadania mają termin „wczoraj”, więc od razu widać eskalację.

**W firmie:** Excel 365 / SharePoint List → Outlook + Teams: Send message.

#### 7. Poniedziałkowy dashboard otwartych spraw 🛠 ★★ ⏱ 45 min

**Cel:** przeniesienie scenariusza 1 (`Raport.json`) z ClickUp na Google Sheets + komentarz AI. Uczy: agregacja w `Code`, HTML w mailu.

**Przepływ:** `Schedule Trigger` (poniedziałek 7:00) → `Google Sheets: Get rows` → `Code` (liczy: otwarte per właściciel, przeterminowane, dodane w ostatnim tygodniu, zamknięte w ostatnim tygodniu) → `OpenAI` (3 zdania komentarza menedżerskiego: co się zatyka, kto przeciążony) → `Gmail: Send` (tabela HTML + komentarz).

**Rozszerzenie:** ten sam `Code` zapisuje wiersz do arkusza `Historia` → wykres w Sheets = „Power BI dla ubogich”.

**W firmie:** Excel 365 → Outlook; wykres w Power BI z push dataset.

#### 8. Zamykanie spraw odpowiedzią „DONE” 📦 ★★ ⏱ 25 min

**Cel:** domknięcie pętli — właściciel odpowiada na przypomnienie z #6 słowem „done” i status w rejestrze się zmienia. Uczy: parsowanie tematu, `Google Sheets: Update` po kluczu.

**Przepływ:** `Gmail Trigger` (filtr: temat zawiera `[T-`) → `Code` (regex wyciąga ID z tematu) → `OpenAI` (czy treść oznacza zamknięcie? + ewentualny komentarz) → `IF` → `Google Sheets: Update` (status = zamknięte, data zamknięcia, komentarz).

**W firmie:** identycznie na Outlooku; alternatywnie reakcja ✅ w Teams.

#### 9. Asystent zadań na czacie — AI Agent z narzędziami 🛠 ★★★ ⏱ 60 min

**Cel:** „efekt wow” pierwszego dnia i namiastka Teams. Uczy: `AI Agent`, narzędzia (tools), pamięć rozmowy.

**Przepływ:** `Chat Trigger` (wbudowany czat n8n, publiczny URL) → `AI Agent` z narzędziami:
- `Google Sheets Tool` (odczyt rejestru),
- `Google Sheets Tool` (dopisz wiersz),
- `Google Sheets Tool` (aktualizuj status),
- `Gmail Tool` (wyślij przypomnienie),
- `Window Buffer Memory`.

Uczestnik pisze: *„Co mam otwartego z terminem w tym tygodniu?”*, *„Dodaj zadanie: audyt dostawcy, Nowak, piątek”*, *„Zamknij T-0007”*.

**W firmie:** ten sam agent wpięty jako bot w MS Teams (`Microsoft Teams Trigger`) lub Slacku.

---

### Blok 2 — Agent AI do spotkań

> Odpowiedź na obszar 2 uczestnika: briefing przed spotkaniem na bazie korespondencji i dokumentów, potem podsumowanie, decyzje, działania.

#### 10. Poranny briefing — kalendarz + korespondencja 🛠 ★★ ⏱ 45 min

**Cel:** codziennie o 7:00 mail „dziś masz 3 spotkania, oto kontekst każdego”. Uczy: `Google Calendar: Get many`, `Gmail: Get many` z wyszukiwaniem, pętla + agregacja.

**Przepływ:** `Schedule Trigger` → `Google Calendar: Get events` (dziś) → `Loop Over Items` → `Gmail: Get many` (query: `from:(uczestnicy) newer_than:14d`) → `Aggregate` → `OpenAI` (na każde spotkanie: cel, ostatnie ustalenia z maili, otwarte pytania, sugerowane 3 punkty do poruszenia) → `Gmail: Send` (jeden zbiorczy mail).

**Dane wejściowe:** 3 seedowane wydarzenia na „jutro” (prowadzący seeduje z datą dnia szkolenia) + maile od tych samych fikcyjnych osób.

**W firmie:** Outlook Calendar + Outlook Mail — 1:1.

#### 11. Briefing z dokumentów projektowych 📦 ★★ ⏱ 35 min

**Cel:** rozszerzenie #10 o „SharePoint”: agent szuka dokumentów powiązanych z tematem spotkania.

**Przepływ:** z opisu wydarzenia wyciągnij nazwę projektu (`OpenAI` lub regex) → `Google Drive: Search` (folder `Projekt Alfa`, nazwa zawiera) → `Google Docs: Get` (max 3 najnowsze) → `OpenAI` (streszczenie 5 punktów + „co się zmieniło od ostatniego protokołu”) → dołącz do briefingu z #10.

**W firmie:** SharePoint: Search / Get file → Word → to samo.

#### 12. Podsumowanie spotkania: transkrypt/nagranie → decyzje, action items, protokół 🛠 ★★★ ⏱ 60 min

**Cel:** najważniejsze ćwiczenie bloku 2. Uczy: upload pliku w formularzu, transkrypcja (Whisper), jeden prompt → trzy wyjścia, tworzenie dokumentu.

**Przepływ:** `n8n Form Trigger` (pole plik audio **lub** pole tekst „wklej transkrypt z Teams”) → `IF` (jest plik?) → `OpenAI: Transcribe` → `Basic LLM Chain` + `Structured Output Parser` (`streszczenie`, `decyzje[]`, `action_items[] {zadanie, właściciel, termin}`, `otwarte_pytania[]`) → **równolegle:**
- `Google Docs: Create` (protokół wg szablonu) w folderze projektu,
- `Google Sheets: Append` do `Rejestru otwartych spraw` (te same kolumny co #4 — **reużycie**),
- `Gmail: Send` do uczestników spotkania (z linkiem do protokołu).

**Dane wejściowe:** prowadzący nagrywa na telefonie 3-minutowe „spotkanie” (2 osoby, 3 decyzje, 4 zadania) i wrzuca plik na wspólny Dysk. Alternatywnie tekst transkryptu.

**W firmie:** transkrypt z Teams (Graph API / Copilot) → Word na SharePoint → Planner.

#### 13. Propozycja agendy i zaproszenie 📦 ★★ ⏱ 30 min

**Cel:** AI przygotowuje agendę następnego spotkania z otwartych spraw i ostatniego protokołu, a n8n tworzy wydarzenie w kalendarzu.

**Przepływ:** `n8n Form Trigger` (projekt, data, uczestnicy) → `Google Sheets: Get rows` (otwarte sprawy tego projektu) → `Google Drive: Search` + `Google Docs: Get` (ostatni protokół) → `OpenAI` (agenda: 5 punktów z czasem, kto referuje) → `Google Calendar: Create event` (opis = agenda, goście = uczestnicy) → `Gmail: Send` (potwierdzenie).

**W firmie:** Outlook Calendar: Create event + Teams link.

#### 14. Follow-up 48 h po spotkaniu 🎬 ★★ ⏱ 20 min

**Cel:** pokazać node `Wait` i to, że workflow może „spać” dwa dni.

**Przepływ:** po #12 → `Wait` (2 dni; na demo 2 minuty) → `Google Sheets: Get rows` (action items z tego spotkania po ID protokołu) → `Filter` (status ≠ zamknięte) → `OpenAI` (uprzejmy, imienny follow-up) → `Gmail: Send` do każdego właściciela.

**W firmie:** identycznie; w Teams jako DM od bota.

---

### Blok 3 — Ryzyka operacyjne i jakościowe (FMEA)

> Odpowiedź na obszar 3 uczestnika: analiza danych z Excel/SharePoint/ERP/Power BI, wczesne wykrywanie opóźnień, braków dokumentacji, przeterminowanych działań korygujących, raport ryzyk i szans.

#### 15. Monitor FMEA — przeterminowane działania korygujące i Top 5 RPN 🛠 ★★ ⏱ 45 min

**Cel:** pierwsza automatyzacja „jakościowa”. Uczy: obliczenia w `Code` (RPN = S×O×D), sortowanie, próg alarmowy, raport.

**Przepływ:** `Schedule Trigger` (codziennie) → `Google Sheets: Get rows` (`FMEA – linia montażowa`) → `Code` (przelicz RPN, oznacz: RPN ≥ 100 **i** brak działania korygującego; działanie z terminem < dziś i status ≠ zamknięte) → `IF` (są alarmy?) → `OpenAI` (uporządkuj po wadze biznesowej, dla każdego: co grozi, co zrobić do jutra) → `Gmail: Send` (`[FMEA] 4 alarmy, Top 5 RPN`) → `Google Sheets: Update` (kolumna `alarm_wysłano`).

**Dane wejściowe:** seedowany arkusz FMEA z 25 wierszami, 4 celowo przeterminowane, 3 z RPN > 100 bez działania.

**W firmie:** Excel 365 / SharePoint List — 1:1. Jeśli FMEA jest w systemie QMS, `HTTP Request`.

#### 16. Wykrywanie opóźnień w projekcie z eksportu ERP 🛠 ★★ ⏱ 45 min

**Cel:** dane „z ERP” bez ERP. Uczy: `Google Drive Trigger` (nowy plik w folderze), `Extract from File` (CSV), porównanie plan vs fakt.

**Przepływ:** `Google Drive Trigger` (folder `Eksporty ERP`, nowy plik) → `Google Drive: Download` → `Extract from File` (CSV) → `Code` (opóźnienie = dziś − planowany termin dla statusów ≠ dostarczone; ślizg harmonogramu z `Harmonogram projektu`) → `OpenAI` (które opóźnienia zatrzymają linię/klienta — skala 1–3) → `Gmail: Send` (tabela opóźnień z komentarzem) + `Google Sheets: Append` (`Historia opóźnień`).

**Wariant webhook (demo, 10 min):** `Webhook` odbiera JSON „z ERP”; prowadzący wysyła `curl` na żywo — uczestnicy widzą, że system może pchać dane sam, bez eksportu.

**W firmie:** SharePoint: Get file (eksport SAP/Comarch) lub `HTTP Request` do API ERP / `MSSQL` bezpośrednio do bazy raportowej.

#### 17. Audyt kompletności dokumentacji 📦 ★★ ⏱ 35 min

**Cel:** braki dokumentów wykrywane automatycznie. Uczy: porównywanie dwóch zbiorów (`Compare Datasets`), listowanie folderu.

**Przepływ:** `Schedule Trigger` (tygodniowo) → `Google Sheets: Get rows` (`Lista wymaganych dokumentów`) → `Google Drive: Search` (folder projektu, lista plików) → `Compare Datasets` (po nazwie dokumentu; wynik: „w A, nie w B” = brak) → `Loop` → `Gmail: Send` do odpowiedzialnego („Brakuje: Plan kontroli v2, termin: …”) + zbiorczy mail do menedżera.

**Dane wejściowe:** w seedzie celowo brakuje 2 dokumentów.

**W firmie:** SharePoint: Get many files w bibliotece — 1:1.

#### 18. Alert jakościowy z maila — reklamacje i NCR 🛠 ★★ ⏱ 40 min

**Cel:** to, co #2, ale dla jakości: reklamacja/raport niezgodności → klasyfikacja → rejestr → natychmiastowa eskalacja przy krytycznych.

**Przepływ:** `Gmail Trigger` → `Basic LLM Chain` + `Structured Output Parser` (czy to zgłoszenie jakościowe; typ: reklamacja klienta / NCR wewnętrzne / dostawca; kategoria wady; ocena krytyczności 1–4 wg podanych definicji; produkt/linia; numer partii jeśli jest) → `IF` (jakościowe?) → `Google Sheets: Append` (`Rejestr NCR`) → `IF` (krytyczność ≥ 3) → `Gmail: Send` do kierownika jakości z tytułem `[KRYTYCZNE]` + `Google Calendar: Create event` (spotkanie 8D za 24 h).

**Dane wejściowe:** 3 seedowane maile: reklamacja klienta (krytyczna), NCR wewnętrzne (średnie), pytanie dostawcy (niejakościowe — test negatywny).

**W firmie:** Outlook → Excel/SharePoint List → Teams: kanał `#jakość`.

#### 19. Tygodniowy raport ryzyk i szans dla zarządu 🛠 ★★ ⏱ 45 min

**Cel:** złożyć #15, #16, #17, #18 w jeden dokument. Uczy: `Merge` z wielu źródeł, generowanie dokumentu Google Docs, jeden prompt „menedżerski”.

**Przepływ:** `Schedule Trigger` (piątek 15:00) → równolegle `Google Sheets: Get rows` z 4 arkuszy (FMEA, Historia opóźnień, Rejestr NCR, Rejestr otwartych spraw) → `Merge` → `Code` (KPI: liczba alarmów, trend tydzień/tydzień, % zamkniętych działań) → `OpenAI` (sekcje: *Top 5 ryzyk*, *Top 3 szanse*, *Co wymaga decyzji zarządu*, każdy punkt: fakt → skutek → rekomendacja) → `Google Docs: Create` (raport w folderze `Raporty`) → `Gmail: Send` do „zarządu” (link + streszczenie).

**Rozszerzenie (Power BI dla ubogich):** KPI dopisywane do arkusza `KPI tygodniowe` z wykresem; w firmie ten sam wiersz leci do Power BI push dataset.

**W firmie:** Excel 365 ×4 → Word na SharePoint → Outlook → Power BI.

#### 20. Analityk danych na czacie — AI Agent nad arkuszami 📦 ★★★ ⏱ 45 min

**Cel:** zamknięcie szkolenia: menedżer zadaje pytania po polsku, agent sam sięga do danych. Uczy: agent z wieloma narzędziami, `Calculator`, ograniczenia halucynacji (prompt: „odpowiadaj tylko na podstawie danych z narzędzi”).

**Przepływ:** `Chat Trigger` → `AI Agent` z narzędziami: `Google Sheets Tool` ×4 (FMEA, Harmonogram, NCR, Rejestr spraw — tylko odczyt), `Calculator`, `Google Docs Tool` (odczyt ostatniego raportu z #19), `Gmail Tool` (wyślij wynik na maila) + pamięć.

Pytania testowe: *„Które działania korygujące Kowalskiego są przeterminowane?”*, *„Ile mamy NCR krytycznych w tym miesiącu vs poprzednim?”*, *„Wyślij mi listę zadań z RPN powyżej 120 na maila.”*

**W firmie:** te same narzędzia na Excel 365 / SharePoint; agent jako bot w Teams.

---

### Tabela zbiorcza

| # | Automatyzacja | Blok | Forma | Poziom | ⏱ | Główne node'y |
| :-- | :--- | :-- | :-- | :-- | :-- | :--- |
| 1 | Zgłoś temat: formularz → AI → mail | 0 | 🛠 | ★ | 30 | Form, OpenAI, Gmail |
| 2 | Klasyfikator skrzynki | 0 | 🛠 | ★★ | 45 | Gmail Trigger, LLM Chain, Parser, Switch, Sheets |
| 3 | Draft odpowiedzi (human in the loop) | 0 | 📦 | ★★ | 30 | Gmail: Create Draft, Send and Wait |
| 4 | Action items z maila → rejestr | 1 | 🛠 | ★★ | 45 | LLM Chain, Parser, Split Out, Code, Sheets |
| 5 | Action items z protokołu → zadania + maile | 1 | 📦 | ★★ | 30 | Form, Google Docs, Loop, Gmail |
| 6 | Strażnik terminów + eskalacja | 1 | 🛠 | ★★ | 40 | Schedule, Sheets, Filter, IF, Gmail |
| 7 | Poniedziałkowy dashboard | 1 | 🛠 | ★★ | 45 | Schedule, Sheets, Code, OpenAI, Gmail HTML |
| 8 | Zamykanie spraw przez „DONE” | 1 | 📦 | ★★ | 25 | Gmail Trigger, Code (regex), Sheets: Update |
| 9 | Asystent zadań na czacie | 1 | 🛠 | ★★★ | 60 | Chat Trigger, AI Agent, Sheets Tool, Gmail Tool, Memory |
| 10 | Poranny briefing (kalendarz + maile) | 2 | 🛠 | ★★ | 45 | Schedule, Calendar, Gmail: Get many, Aggregate |
| 11 | Briefing z dokumentów | 2 | 📦 | ★★ | 35 | Drive: Search, Docs: Get |
| 12 | Podsumowanie spotkania (audio/tekst) | 2 | 🛠 | ★★★ | 60 | Form (plik), Transcribe, Parser, Docs: Create, Sheets, Gmail |
| 13 | Agenda + zaproszenie | 2 | 📦 | ★★ | 30 | Form, Sheets, Docs, OpenAI, Calendar: Create |
| 14 | Follow-up 48 h | 2 | 🎬 | ★★ | 20 | Wait, Sheets, Filter, Gmail |
| 15 | Monitor FMEA | 3 | 🛠 | ★★ | 45 | Schedule, Sheets, Code (RPN), OpenAI, Gmail |
| 16 | Opóźnienia z eksportu ERP (CSV / webhook) | 3 | 🛠 | ★★ | 45 | Drive Trigger, Extract from File, Code, Webhook |
| 17 | Audyt kompletności dokumentacji | 3 | 📦 | ★★ | 35 | Sheets, Drive: Search, Compare Datasets |
| 18 | Alert jakościowy (reklamacje/NCR) | 3 | 🛠 | ★★ | 40 | Gmail Trigger, Parser, IF, Sheets, Calendar |
| 19 | Tygodniowy raport ryzyk i szans | 3 | 🛠 | ★★ | 45 | Sheets ×4, Merge, Code, OpenAI, Docs: Create |
| 20 | Analityk danych na czacie | 3 | 📦 | ★★★ | 45 | Chat Trigger, AI Agent, Sheets Tool ×4, Calculator |

Suma czasu ćwiczeń: ~13,5 h. Z wprowadzeniem, konfiguracją i przerwami to pełne 2 dni — dlatego część jest 📦/🎬, a nie 🛠.

---

## 4. Plan 2 dni

### Dzień 1 — „Poczta, zadania, terminy” (≈ 8 h z przerwami)

| Czas | Blok | Co |
| :-- | :-- | :-- |
| 9:00–9:45 | Wstęp | Czym jest n8n, wzorzec trigger → dane → AI → akcja, mapowanie firma → szkolenie (sekcja 1). Rozdanie kart z dostępami. |
| 9:45–10:30 | Konfiguracja | Logowanie do n8n, credential Google OAuth (jeden na wszystko), OpenAI. Test: Gmail „Get many”. |
| 10:30–11:00 | #1 | Pierwszy workflow. |
| 11:15–12:45 | #2, #3 | Klasyfikator + draft. Metodologia promptów (sekcja 3 głównego skryptu) wpleciona w #2. |
| 13:30–15:00 | #4, #6 | Action items → rejestr; strażnik terminów. |
| 15:15–16:15 | #7, #8 | Dashboard; domknięcie pętli. (#5 — jako zadanie „dla szybkich” lub import.) |
| 16:15–17:00 | #9 | Asystent na czacie — wow na koniec dnia. |

### Dzień 2 — „Spotkania i ryzyka” (≈ 8 h)

| Czas | Blok | Co |
| :-- | :-- | :-- |
| 9:00–9:30 | Recap | Import workflowów z dnia 1 dla spóźnionych/nieobecnych; 3 pytania kontrolne. |
| 9:30–11:00 | #10, #11 | Briefing poranny (dane seedowane na dziś!). |
| 11:15–12:30 | #12 | Podsumowanie spotkania z nagrania. |
| 12:30–13:00 | #13, #14 | Agenda; follow-up jako demo. |
| 13:45–15:15 | #15, #16 | FMEA; opóźnienia z „ERP” + webhook demo. |
| 15:30–16:30 | #18, #17 | Alert jakościowy; audyt dokumentacji (import). |
| 16:30–17:15 | #19, #20 | Raport dla zarządu; analityk na czacie. |
| 17:15–17:30 | Zamknięcie | „Co przenoszę do firmy w poniedziałek” — każdy wybiera 1 automatyzację i wypisuje, co podmienia (Outlook/Excel/SharePoint). |

**Zasada bezpieczeństwa czasowego:** jeśli grupa jest wolniejsza, wypadają w tej kolejności: #14, #5, #11, #17, #13. Nigdy nie wypadają: #4, #6, #9, #12, #15, #19.

---

## 5. Osoba dołączająca tylko drugiego dnia

**Tak, ma to sens** — pod trzema warunkami:

1. **Dzień 2 jest samodzielny tematycznie.** Bloki 2 i 3 (spotkania, FMEA/ryzyka) to dokładnie obszary 2 i 3 z listy uczestnika i nie wymagają workflowów z dnia 1 — poza `Rejestrem otwartych spraw`, który dostaje jako gotowy arkusz z seeda.
2. **Środowisko musi być skonfigurowane przed 9:00.** Prowadzący wysyła tej osobie dzień wcześniej kartę z dostępami i 10-minutowy film/instrukcję (sekcja 2 głównego skryptu: credential Google + OpenAI). Alternatywnie: prowadzący przychodzi 30 min wcześniej i robi to z nią. Bez tego straci pierwsze ćwiczenie dnia 2.
3. **Dostaje paczkę z dnia 1 do importu** (JSON-y #1–#9) i w recapie o 9:00 importuje #2 i #4, żeby rozumieć, skąd bierze się rejestr spraw i parser strukturalny — te dwa mechanizmy wracają w #12, #18, #19.

Czego nie nadrobi: praktyki z expressions i debugowania z dnia 1. Dlatego przy tej osobie warto usiąść w #10 (pierwsze samodzielne ćwiczenie dnia 2) — po nim zwykle łapie rytm.

Jeśli ta osoba jest autorem listy trzech obszarów — tym bardziej warto, bo dzień 2 odpowiada na dwa z jej trzech tematów wprost.

---

## 6. Checklista prowadzącego

**Tydzień przed:**
- [ ] 17 instancji n8n (`setup-fleet.sh`), sprawdzone logowanie na każdej
- [ ] 17 kont Google (Workspace lub gmail.com), hasła na kartach
- [ ] Google Cloud: projekt, włączone API (Gmail, Calendar, Drive, Sheets, Docs), OAuth Client, 17 test users, 17 redirect URI
- [ ] Klucze OpenAI (osobne lub wspólny z limitem), doładowane saldo
- [ ] 4 szablony Google Sheets + folder `Projekt Alfa` + `eksport_erp.csv` na koncie prowadzącego
- [ ] Nagranie 3-minutowego „spotkania” (do #12)
- [ ] Workflow-seeder przetestowany na 1 koncie (maile, kopie arkuszy, wydarzenia, pliki)
- [ ] JSON-y wszystkich 20 workflowów wyeksportowane z instancji prowadzącego, credentiale w nich **odpięte**

**Dzień przed:**
- [ ] Seeder uruchomiony dla wszystkich 16 kont; daty wydarzeń kalendarza = dzień 2 szkolenia
- [ ] Karta z dostępami + instrukcja wysłana do osoby dołączającej drugiego dnia
- [ ] Test end-to-end #2 i #10 na losowym koncie uczestnika

**W trakcie:**
- [ ] Prowadzący „dosyła” maile na żywo (#2, #4, #18) — przygotowane w drafcie
- [ ] `curl` do webhooka (#16) w schowku
- [ ] Po każdym bloku: JSON-y na wspólny Dysk uczestników

**Po szkoleniu:**
- [ ] Wyłączyć klucze OpenAI, zresetować hasła kont Google lub usunąć konta
- [ ] Zostawić uczestnikom paczkę JSON + ten dokument + tabelę mapowania (sekcja 1)

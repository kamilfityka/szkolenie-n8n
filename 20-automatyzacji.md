# 20 automatyzacji na szkolenie „Narzędzia no-code/low-code AI dla menedżerów”

**Środowisko:** n8n (własna instancja dla każdego uczestnika) + **SMTP** (wysyłka maili) + **ClickUp** (zadania, terminy, „kalendarz”) + **Google Sheets / Drive / Docs przez Service Account** (dane, dokumenty) + **OpenAI**.
**Grupa:** maks. 16 osób, 2 dni.
**Założenia:**
- uczestnicy **nie** przynoszą żadnych własnych dostępów (SharePoint, Excel, Outlook, ERP) i **nie muszą mieć konta Google**,
- nie ma dostępu do środowiska Microsoft,
- uczestnicy **nie logują się do Google** — wszystko, co google'owe, działa na jednym koncie usługi (Service Account), którego klucz JSON dostają na kartce,
- SMTP tylko wysyła, **nie ma triggera „nowy mail”** — pocztę przychodzącą symuluje arkusz `Skrzynka` odpytywany **triggerem czasowym** (`Schedule Trigger`),
- wyniki (raporty, przypomnienia, alerty) lecą SMTP-em na **prywatny/służbowy adres uczestnika** z `participants.csv`, więc każdy widzi efekt na własnym telefonie.

Dokument jest uzupełnieniem `szkolenie-n8n-ul.md` (tam: instalacja, słownik, metodologia promptów). Tutaj: katalog ćwiczeń i plan.

---

## Spis treści

1. [Mapowanie firma → szkolenie](#1-mapowanie-firma--szkolenie)
2. [Środowisko i seed data — co przygotowuje prowadzący](#2-środowisko-i-seed-data)
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

Uczestnik pyta o Outlook, Teams, SharePoint, Excel, ERP i Power BI. Na szkoleniu nie mamy do tego dostępów, ale **wzorzec automatyzacji jest identyczny**: *trigger → pobierz dane → AI → zapisz / wyślij*. Zmienia się tylko credential i node.

| W firmie uczestnika | Na szkoleniu | Node n8n na szkoleniu | Node n8n w firmie (na slajd) |
| :--- | :--- | :--- | :--- |
| Outlook — poczta przychodząca | arkusz `Skrzynka` odpytywany co N minut | `Schedule Trigger` → `Google Sheets: Get rows` | `Schedule Trigger` → `Microsoft Outlook: Get many` (ten sam wzorzec!) lub `Outlook Trigger` |
| Outlook — wysyłka | SMTP | `Send Email` | `Microsoft Outlook: Send` |
| Kalendarz Outlook | lista `Spotkania` w ClickUp (zadanie = spotkanie, due date = termin) | `ClickUp: Get many / Create task` | `Microsoft Outlook` (Calendar) |
| Planner / lista zadań | lista `Otwarte sprawy` w ClickUp | `ClickUp` | `Microsoft Planner`, `Microsoft To Do` |
| MS Teams | wbudowany czat n8n + mail | `Chat Trigger`, `Send Email` | `Microsoft Teams` |
| SharePoint (biblioteka dokumentów) | folder Google Drive (Service Account) | `Google Drive`, `Google Docs` | `Microsoft SharePoint`, `OneDrive` |
| Excel | Google Sheets (Service Account) | `Google Sheets` | `Microsoft Excel 365` |
| ERP (eksport / API) | plik CSV na Dysku **lub** webhook „z ERP” | `Google Drive: Download`, `Extract from File`, `Webhook` | `HTTP Request`, `Postgres` / `MSSQL` |
| Power BI | zakładka `KPI` w Sheets z wykresem | `Google Sheets: Append` | `HTTP Request` → Power BI REST API (push dataset) |

**Komunikat do grupy na starcie:** „Trigger czasowy, który co 5 minut pyta *czy jest coś nowego*, to dokładnie to, co w firmie zrobicie z Outlookiem. Dziś zamiast Outlooka pytamy arkusz.”

---

## 2. Środowisko i seed data

### 2.1 Karta uczestnika

Każdy dostaje pierwszego dnia kartkę z **sześcioma** rzeczami. Nic więcej nie jest potrzebne.

```
┌──────────────────────────────────────────────────────────────┐
│  UCZESTNIK U01                                               │
├──────────────────────────────────────────────────────────────┤
│  n8n:            https://u01.<domena>   login / hasło        │
│  Mój e-mail:     jan.kowalski@firma.pl  (tu przychodzą wyniki)│
│  SMTP:           host / port / user / hasło                  │
│  Google SA:      plik szkolenie-sa.json (wspólny dla wszystkich)│
│  Mój arkusz:     https://docs.google.com/spreadsheets/d/…    │
│  ClickUp:        token pk_… + ID listy „Otwarte sprawy – U01”│
│  OpenAI:         sk-…                                        │
└──────────────────────────────────────────────────────────────┘
```

Credentiale w n8n (tworzone raz, pierwszego dnia, 20 minut):

| Credential | Typ w n8n | Skąd |
| :--- | :--- | :--- |
| `SMTP – szkolenie` | SMTP | wspólne dane od prowadzącego |
| `Google SA – szkolenie` | Google Service Account | wklejenie zawartości `szkolenie-sa.json` (jeden credential obsługuje Sheets, Drive, Docs) |
| `ClickUp – moje` | ClickUp API | własny token (patrz 2.3) |
| `OpenAI – szkolenie` | OpenAi API | klucz od prowadzącego |

### 2.2 Dlaczego tak, a nie „konto Google dla każdego”

- 16 osób logujących się do jednego konta Google z 16 IP naraz = blokady i weryfikacje telefonem właściciela. **Nikt się nie loguje.**
- Service Account nie ma przeglądarki, nie ma zgód OAuth, nie ma redirect URI per instancja. Jeden JSON, wklejony 16 razy.
- SMTP nie ma triggera, IMAP Trigger trzyma stałe połączenie, a Gmail dopuszcza **15 jednoczesnych połączeń IMAP** na konto — 17 instancji przekracza limit. Dlatego poczta przychodząca to arkusz + trigger czasowy.

**Limit, którego trzeba pilnować:** Google Sheets API — **60 odczytów na minutę na użytkownika**, a Service Account to jeden użytkownik dla całej sali. Zasady:
- `Schedule Trigger` do `Skrzynki` **co 5 minut**, nie co 1 (16 instancji × 1/min = 16 odczytów w tle, zanim ktokolwiek kliknie Execute),
- na każdym node `Google Sheets` włączone **Retry On Fail** (3 próby, 2000 ms),
- w Google Cloud Console złożony wniosek o podniesienie limitu (zwykle akceptowany w 1–2 dni),
- w trakcie ćwiczeń workflowy uruchamiane **ręcznie** (`Execute workflow`), aktywacja („Active”) dopiero na końcu ćwiczenia.

### 2.3 ClickUp

Wspólny token to **100 żądań/min na całą salę** — zatnie się. Dlatego, tak jak w `szkolenie-n8n-ul.md` (sekcja 2.2):
- każdy uczestnik ma **własne konto ClickUp** (darmowe, zakładane na swój adres) i **własny token** `pk_…`,
- prowadzący zaprasza wszystkie konta do jednego workspace `Szkolenie n8n`,
- każdy dostaje własny folder `U01` z dwiema listami: `Otwarte sprawy – U01` i `Spotkania – U01`,
- w listach są **pola niestandardowe**: `Źródło` (tekst), `Priorytet` (dropdown 1–3), `ID protokołu` (tekst); statusy: `otwarte / w toku / zamknięte`.

Zaproszenia wysyła prowadzący **tydzień przed** — token generuje uczestnik w 2 minuty w trakcie konfiguracji.

### 2.4 Arkusz uczestnika (`Szkolenie – U01`)

Jeden plik Google Sheets na uczestnika, skopiowany przez seeder z szablonu prowadzącego, udostępniony do edycji dla Service Account. Zakładki:

| Zakładka | Rola | Zawartość seedowana |
| :--- | :--- | :--- |
| `Skrzynka` | **symulacja poczty przychodzącej** | ~20 maili: `id`, `od`, `temat`, `treść`, `data`, `przetworzono` (puste). Od fikcyjnego szefa, klienta, dostawcy, HR, działu jakości. Reklamacja, NCR, „przypominam o…”, spam. Każdy mail ma 0–3 action itemy. |
| `FMEA` | rejestr FMEA linii montażowej | 25 wierszy: funkcja, wada, S, O, D, RPN (puste — liczymy w n8n), działanie korygujące, odpowiedzialny, termin, status. 4 przeterminowane, 3 z RPN > 100 bez działania. |
| `Harmonogram` | plan vs fakt projektu | 15 zadań: plan start/koniec, fakt start/koniec, % ukończenia, właściciel. |
| `Dokumenty wymagane` | lista kontrolna dokumentacji | 8 dokumentów projektu `Alfa`: nazwa, wymagany, odpowiedzialny. |
| `Zespół` | kto jest kim (dla promptów) | 6 osób: imię, rola, e-mail (= adres uczestnika z sufiksem, np. `jan.kowalski+nowak@firma.pl`, żeby maile „do zespołu” wracały do uczestnika). |
| `Historia`, `KPI` | puste, wypełniane przez workflowy | — |

**Dosyłanie maili na żywo:** prowadzący ma na swojej instancji workflow `Dosyłacz`: `n8n Form` (od, temat, treść, do kogo: wszyscy / U01…U16) → pętla po arkuszach → `Google Sheets: Append` do `Skrzynki`. Uczestnicy widzą, jak ich trigger czasowy „łapie” nowy mail.

### 2.5 Google Drive (Service Account)

- Folder `Projekt Alfa` (wspólny, tylko odczyt): 6 dokumentów Google Docs — specyfikacja, protokół z poprzedniego spotkania, raport audytu, instrukcja kontroli, plan jakości, notatka od klienta. Z listy `Dokumenty wymagane` celowo **brakuje 2**.
- Folder `Eksporty ERP` (wspólny): `eksport_erp.csv` — zamówienia, terminy dostaw, statusy, 5 opóźnionych.
- Folder `Raporty – U01` … `U16` (per uczestnik, zapis): tu lądują protokoły i raporty tworzone przez workflowy.
- Plik `spotkanie.mp3` (3 minuty, nagrane przez prowadzącego: 2 osoby, 3 decyzje, 4 zadania) — do ćwiczenia 12.

Service Account musi mieć **Editor** na folderach zapisu i **Viewer** na wspólnych.

---

## 3. Katalog 20 automatyzacji

Legenda:
- 🛠 **budujemy od zera** — uczestnicy klikają razem z prowadzącym
- 📦 **import + modyfikacja** — prowadzący daje JSON, grupa rozumie i zmienia
- 🎬 **demo** — pokaz prowadzącego, uczestnik dostaje JSON do domu
- ⏱ czas z buforem na debug w grupie 16 osób
- Poziom: ★ (klik-klik) / ★★ (expressions, IF, pętle) / ★★★ (AI Agent z narzędziami, Code)

**Wzorzec „poczta przychodząca”** (używany w #2, #3, #4, #8, #18) — buduje się raz w #2, potem kopiuje:

```
Schedule Trigger (co 5 min)
  → Google Sheets: Get rows  (zakładka Skrzynka, filtr: przetworzono = puste)
  → [właściwa logika]
  → Google Sheets: Update    (przetworzono = teraz, po kolumnie id)
```

Każda automatyzacja ma sekcję **W firmie:** — jak to samo brzmi po podmianie na Outlook / SharePoint / Excel / Planner.

---

### Blok 0 — Rozgrzewka

#### 1. „Zgłoś temat” — formularz → AI → mail 🛠 ★ ⏱ 30 min

**Cel:** pierwszy działający workflow w 30 minut. Uczy: trigger, credential, expression `{{ $json.pole }}`, test krok po kroku.

**Przepływ:** `n8n Form Trigger` (pola: temat, opis, kto zgłasza) → `OpenAI` (nadaj priorytet 1–3 i zaproponuj właściciela z zakładki `Zespół` wklejonej do promptu) → `Send Email` (SMTP, na adres uczestnika: „przyjęliśmy, priorytet X, właściciel Y”).

**Dane wejściowe:** uczestnik sam wypełnia formularz. Zero zależności.

**W firmie:** Microsoft Forms → ten sam AI → Outlook.

#### 2. Klasyfikator skrzynki — pilne / do wiadomości / spam 🛠 ★★ ⏱ 50 min

**Cel:** zbudować wzorzec „poczta przychodząca” i przenieść istniejący scenariusz 2 (`Email AI Agent — sentyment + intencja + draft.json`) z IMAP na trigger czasowy. Uczy: `Schedule Trigger`, filtr w Sheets, Structured Output Parser, `Switch`, aktualizacja wiersza po kluczu.

**Przepływ:** `Schedule Trigger` (co 5 min) → `Google Sheets: Get rows` (`Skrzynka`, `przetworzono` puste) → `Basic LLM Chain` + `Structured Output Parser` (intencja, pilność 1–5, sentyment, czy wymaga odpowiedzi, streszczenie 1 zdanie) → `Switch` po pilności → `Google Sheets: Update` (`Skrzynka`: kolumny `kategoria`, `pilność`, `przetworzono`) → gałąź PILNE: `Send Email` (SMTP, do uczestnika, tytuł `[PILNE] {{temat}}`).

**Na żywo:** prowadzący `Dosyłaczem` wrzuca 2 nowe maile — uczestnicy klikają `Execute workflow` i widzą, że przetwarzają się tylko nowe.

**W firmie:** `Schedule Trigger` → `Outlook: Get many` (filtr `isRead eq false`) → to samo → `Outlook: Update` (kategoria).

#### 3. Draft odpowiedzi z człowiekiem w pętli 📦 ★★ ⏱ 30 min

**Cel:** zasada *human in the loop* — AI **nie wysyła** odpowiedzi do nadawcy, tylko przygotowuje ją menedżerowi.

**Przepływ:** rozszerzenie #2: gałąź „wymaga odpowiedzi = true” → `OpenAI` (draft odpowiedzi w tonie menedżera, po polsku, max 120 słów, 2 warianty: krótki / dyplomatyczny) → `Send Email` do uczestnika z tytułem `[DRAFT] Re: {{temat}}` i oboma wariantami → `Google Sheets: Update` (`Skrzynka`, kolumna `draft`).

**Wariant demo:** `Send Email` z linkami „Zatwierdź / Odrzuć” prowadzącymi do `Webhook`, który dopiero wysyła właściwą odpowiedź (`Send Email` do adresu z `od`). Pokazuje, że akceptacja może być jednym kliknięciem w telefonie.

**W firmie:** Outlook: Create Draft w wątku; zatwierdzanie w Teams (Adaptive Card).

---

### Blok 1 — Zadania i otwarte tematy menedżera

> Odpowiedź na obszar 1 uczestnika: identyfikacja action items z poczty/komunikacji, przypisywanie właścicieli, monitorowanie terminów, dashboard otwartych spraw.

#### 4. Action items z maila → ClickUp „Otwarte sprawy” 🛠 ★★ ⏱ 45 min

**Cel:** serce bloku. Z każdego maila wyciągnąć zadania ze strukturą i założyć je w ClickUp z właścicielem i terminem.

**Przepływ:** wzorzec „poczta przychodząca” → `Basic LLM Chain` + `Structured Output Parser` (tablica: `zadanie`, `właściciel` — wybierz z listy `Zespół` w prompcie, `termin` ISO lub null, `priorytet`) → `Split Out` (1 item = 1 zadanie) → `ClickUp: Create task` (lista `Otwarte sprawy – U01`; nazwa, opis = streszczenie + cytat z maila, due date, priorytet, pole `Źródło` = `mail #id`) → `Google Sheets: Update` (`przetworzono`).

**Kluczowa lekcja promptowa:** lista zespołu i **dzisiejsza data** w prompcie (`{{ $now.toISODate() }}`), inaczej „do piątku” zostaje tekstem, a właściciel jest zmyślony.

**W firmie:** Outlook: Get many → to samo → Planner: Create task / SharePoint List: Create item.

#### 5. Action items z protokołu (Google Docs) → zadania + maile do właścicieli 📦 ★★ ⏱ 30 min

**Cel:** to samo co #4, ale źródłem jest dokument, a nie mail. Uczy: `Google Docs: Get` przez Service Account, pętla `Loop Over Items`, mail per właściciel.

**Przepływ:** `n8n Form Trigger` (pole: ID dokumentu **lub** wklejony tekst) → `Google Docs: Get` → LLM + Parser (jak w #4) → `ClickUp: Create task` → `Loop Over Items` → `Send Email` do właściciela („Przypisano Ci zadanie X, termin Y, źródło: protokół Z”; adres z zakładki `Zespół`, czyli wraca do uczestnika).

**Dane wejściowe:** `Protokół – spotkanie 12.09` z folderu `Projekt Alfa`.

**W firmie:** SharePoint: Get file (Word) → to samo → Outlook.

#### 6. Strażnik terminów — codzienne przypomnienia i eskalacja 🛠 ★★ ⏱ 40 min

**Cel:** monitorowanie terminów. Uczy: `ClickUp: Get many` z filtrem, daty w expressions, `IF` z eskalacją.

**Przepływ:** `Schedule Trigger` (codziennie 7:30) → `ClickUp: Get many tasks` (lista `Otwarte sprawy`, status ≠ zamknięte, `due_date_lt` = dziś + 2 dni) → `IF` (termin < dziś?) →
- **tak:** `Send Email` do właściciela **i** do menedżera (tytuł `[PRZETERMINOWANE] {{nazwa}}`), `ClickUp: Update task` (priorytet ↑, komentarz „eskalowano”),
- **nie:** `Send Email` do właściciela (przypomnienie „zostały 2 dni”).

**Trik szkoleniowy:** seeder zakłada w ClickUp 3 zadania z terminem „wczoraj”, więc eskalacja odpala się za pierwszym razem.

**W firmie:** Planner / SharePoint List → Outlook + Teams: Send message.

#### 7. Poniedziałkowy dashboard otwartych spraw 🛠 ★★ ⏱ 45 min

**Cel:** przeniesienie scenariusza 1 (`Raport.json`) na nowe listy + komentarz AI. Uczy: agregacja w `Code`, HTML w mailu, zapis historii do KPI.

**Przepływ:** `Schedule Trigger` (poniedziałek 7:00) → `ClickUp: Get many tasks` (wszystkie z folderu `U01`) → `Code` (otwarte per właściciel, przeterminowane, dodane w ostatnim tygodniu, zamknięte w ostatnim tygodniu, średni wiek otwartej sprawy) → `OpenAI` (3 zdania komentarza: co się zatyka, kto przeciążony, jedna rekomendacja) → `Send Email` (tabela HTML + komentarz) → `Google Sheets: Append` (zakładka `KPI` — wiersz z datą; wykres w arkuszu = „Power BI dla ubogich”).

**W firmie:** Planner / Excel 365 → Outlook → Power BI push dataset.

#### 8. Zamykanie spraw odpowiedzią „DONE” 📦 ★★ ⏱ 25 min

**Cel:** domknięcie pętli — właściciel odpisuje na przypomnienie z #6 słowem „done”, status w ClickUp się zmienia. Uczy: regex w `Code`, `ClickUp: Update task` po ID.

**Przepływ:** wzorzec „poczta przychodząca” (`Skrzynka`, filtr: temat zawiera `Re: [`) → `Code` (regex wyciąga ID zadania ClickUp z tematu, np. `[#86abc123]`, które #6 wstawiło do tytułu) → `OpenAI` (czy treść oznacza zamknięcie? + komentarz do zadania) → `IF` → `ClickUp: Update task` (status `zamknięte`) + `ClickUp: Create comment` (treść odpowiedzi).

**Na żywo:** prowadzący `Dosyłaczem` wrzuca mail „Re: [#…] zrobione, faktura wysłana”.

**W firmie:** identycznie na Outlooku; alternatywnie reakcja ✅ w Teams.

#### 9. Asystent zadań na czacie — AI Agent z narzędziami 🛠 ★★★ ⏱ 60 min

**Cel:** „efekt wow” pierwszego dnia i namiastka Teams. Uczy: `AI Agent`, narzędzia (dowolny node jako *tool*), pamięć rozmowy.

**Przepływ:** `Chat Trigger` (wbudowany czat n8n, publiczny URL) → `AI Agent` z narzędziami:
- `ClickUp Tool` — Get many tasks (moje otwarte),
- `ClickUp Tool` — Create task,
- `ClickUp Tool` — Update task (status),
- `Send Email Tool` — wyślij przypomnienie,
- `Window Buffer Memory`.

System prompt: lista zespołu, dzisiejsza data, „nigdy nie zamykaj zadania bez potwierdzenia użytkownika”.

Uczestnik pisze: *„Co mam otwartego z terminem w tym tygodniu?”*, *„Dodaj zadanie: audyt dostawcy, Nowak, piątek”*, *„Zamknij zadanie z audytem”*.

**W firmie:** ten sam agent jako bot w MS Teams (`Microsoft Teams Trigger`) z `Planner Tool`.

---

### Blok 2 — Agent AI do spotkań

> Odpowiedź na obszar 2 uczestnika: briefing przed spotkaniem na bazie korespondencji i dokumentów, potem podsumowanie, decyzje, działania.

**Kalendarz na szkoleniu** = lista `Spotkania – U01` w ClickUp: zadanie = spotkanie, `due date` = termin (z godziną), opis = agenda, pole `Uczestnicy` = imiona z `Zespołu`. Seeder tworzy 3 spotkania na **dzień 2 szkolenia**.

#### 10. Poranny briefing — spotkania + korespondencja 🛠 ★★ ⏱ 45 min

**Cel:** codziennie o 7:00 mail „dziś masz 3 spotkania, oto kontekst każdego”. Uczy: dwa źródła w jednym workflow, pętla + agregacja, prompt z kontekstem.

**Przepływ:** `Schedule Trigger` → `ClickUp: Get many tasks` (`Spotkania`, due date = dziś) → `Loop Over Items` → `Google Sheets: Get rows` (`Skrzynka`, filtr: `od` ∈ uczestnicy spotkania, ostatnie 14 dni) → `Aggregate` → `OpenAI` (na każde spotkanie: cel, ostatnie ustalenia z maili, otwarte pytania, sugerowane 3 punkty do poruszenia) → `Send Email` (jeden zbiorczy mail „Briefing na dziś”).

**W firmie:** Outlook Calendar: Get many + Outlook Mail: Get many — 1:1.

#### 11. Briefing z dokumentów projektowych 📦 ★★ ⏱ 35 min

**Cel:** rozszerzenie #10 o „SharePoint”: agent szuka dokumentów powiązanych z tematem spotkania.

**Przepływ:** z opisu spotkania wyciągnij nazwę projektu (`OpenAI` lub regex) → `Google Drive: Search` (folder `Projekt Alfa`, nazwa zawiera) → `Google Docs: Get` (max 3 najnowsze) → `OpenAI` (streszczenie 5 punktów + „co się zmieniło od ostatniego protokołu”) → doklej do briefingu z #10.

**W firmie:** SharePoint: Search / Get file → to samo.

#### 12. Podsumowanie spotkania: nagranie/transkrypt → decyzje, action items, protokół 🛠 ★★★ ⏱ 60 min

**Cel:** najważniejsze ćwiczenie bloku 2. Uczy: upload pliku w formularzu, transkrypcja (Whisper), jeden prompt → trzy wyjścia, tworzenie dokumentu, **reużycie** listy z #4.

**Przepływ:** `n8n Form Trigger` (pole plik audio **lub** pole tekst „wklej transkrypt”) → `IF` (jest plik?) → `OpenAI: Transcribe` → `Basic LLM Chain` + `Structured Output Parser` (`streszczenie`, `decyzje[]`, `action_items[] {zadanie, właściciel, termin}`, `otwarte_pytania[]`) → **równolegle:**
- `Google Docs: Create` (protokół wg szablonu) w folderze `Raporty – U01`,
- `Split Out` → `ClickUp: Create task` (`Otwarte sprawy`, pole `ID protokołu` = ID dokumentu),
- `Send Email` do uczestników spotkania (z linkiem do protokołu i listą decyzji).

**Dane wejściowe:** `spotkanie.mp3` z Dysku (uczestnik pobiera i wrzuca w formularz) lub tekst transkryptu.

**W firmie:** transkrypt z Teams (Graph API) → Word na SharePoint → Planner → Outlook.

#### 13. Propozycja agendy i „zaproszenie” 📦 ★★ ⏱ 30 min

**Cel:** AI przygotowuje agendę następnego spotkania z otwartych spraw i ostatniego protokołu, n8n zakłada spotkanie.

**Przepływ:** `n8n Form Trigger` (projekt, data i godzina, uczestnicy) → `ClickUp: Get many tasks` (otwarte sprawy projektu) → `Google Drive: Search` + `Google Docs: Get` (ostatni protokół) → `OpenAI` (agenda: 5 punktów z czasem, kto referuje) → `ClickUp: Create task` (`Spotkania`, due date, opis = agenda) → `Send Email` (zaproszenie z agendą do uczestników).

**W firmie:** Outlook Calendar: Create event (goście + link Teams).

#### 14. Follow-up 48 h po spotkaniu 🎬 ★★ ⏱ 20 min

**Cel:** pokazać `Wait` — workflow może „spać” dwa dni.

**Przepływ:** po #12 → `Wait` (2 dni; na demo 2 minuty) → `ClickUp: Get many tasks` (pole `ID protokołu` = ten protokół, status ≠ zamknięte) → `Filter` → `OpenAI` (uprzejmy, imienny follow-up) → `Send Email` do każdego właściciela.

**W firmie:** identycznie; w Teams jako DM od bota.

---

### Blok 3 — Ryzyka operacyjne i jakościowe (FMEA)

> Odpowiedź na obszar 3 uczestnika: analiza danych z Excel/SharePoint/ERP/Power BI, wczesne wykrywanie opóźnień, braków dokumentacji, przeterminowanych działań korygujących, raport ryzyk i szans.

#### 15. Monitor FMEA — przeterminowane działania korygujące i Top 5 RPN 🛠 ★★ ⏱ 45 min

**Cel:** pierwsza automatyzacja „jakościowa”. Uczy: obliczenia w `Code` (RPN = S×O×D), sortowanie, próg alarmowy, raport, zapis wyników z powrotem do arkusza.

**Przepływ:** `Schedule Trigger` (codziennie) → `Google Sheets: Get rows` (`FMEA`) → `Code` (przelicz RPN; oznacz: RPN ≥ 100 **i** brak działania korygującego; działanie z terminem < dziś i status ≠ zamknięte) → `Google Sheets: Update` (kolumna `RPN`) → `IF` (są alarmy?) → `OpenAI` (uporządkuj po wadze biznesowej; dla każdego: co grozi, co zrobić do jutra) → `Send Email` (`[FMEA] 4 alarmy, Top 5 RPN`) → `ClickUp: Create task` dla każdego przeterminowanego działania (jeśli jeszcze nie istnieje — pole `Źródło` = `FMEA #wiersz`).

**W firmie:** Excel 365 / SharePoint List — 1:1. FMEA w systemie QMS → `HTTP Request`.

#### 16. Wykrywanie opóźnień z eksportu ERP 🛠 ★★ ⏱ 45 min

**Cel:** dane „z ERP” bez ERP. Uczy: `Google Drive: Download` + `Extract from File` (CSV), porównanie plan vs fakt, webhook.

**Przepływ:** `Schedule Trigger` (co godzinę) → `Google Drive: Search` (folder `Eksporty ERP`, najnowszy plik) → `Google Drive: Download` → `Extract from File` (CSV) → `Code` (opóźnienie = dziś − planowany termin dla statusów ≠ dostarczone; ślizg harmonogramu z zakładki `Harmonogram`) → `OpenAI` (które opóźnienia zatrzymają linię/klienta — skala 1–3) → `Send Email` (tabela opóźnień z komentarzem) + `Google Sheets: Append` (`Historia`).

**Wariant webhook (demo, 10 min):** `Webhook` odbiera JSON „z ERP”; prowadzący wysyła `curl` na żywo — system może pchać dane sam, bez eksportu.

**W firmie:** SharePoint: Get file (eksport SAP/Comarch) lub `HTTP Request` do API ERP / `MSSQL` do bazy raportowej.

#### 17. Audyt kompletności dokumentacji 📦 ★★ ⏱ 35 min

**Cel:** braki dokumentów wykrywane automatycznie. Uczy: porównywanie dwóch zbiorów (`Compare Datasets`), listowanie folderu.

**Przepływ:** `Schedule Trigger` (tygodniowo) → `Google Sheets: Get rows` (`Dokumenty wymagane`) → `Google Drive: Search` (folder `Projekt Alfa`, lista plików) → `Compare Datasets` (po nazwie; „w A, nie w B” = brak) → `Loop` → `Send Email` do odpowiedzialnego („Brakuje: Plan kontroli v2”) → `ClickUp: Create task` (uzupełnij dokument, termin +5 dni) + zbiorczy mail do menedżera.

**W firmie:** SharePoint: Get many files w bibliotece — 1:1.

#### 18. Alert jakościowy z maila — reklamacje i NCR 🛠 ★★ ⏱ 40 min

**Cel:** wzorzec z #2, ale dla jakości: reklamacja / raport niezgodności → klasyfikacja → rejestr → natychmiastowa eskalacja przy krytycznych.

**Przepływ:** wzorzec „poczta przychodząca” → `Basic LLM Chain` + `Structured Output Parser` (czy to zgłoszenie jakościowe; typ: reklamacja klienta / NCR wewnętrzne / dostawca; kategoria wady; krytyczność 1–4 wg podanych w prompcie definicji; produkt/linia; numer partii jeśli jest) → `IF` (jakościowe?) → `Google Sheets: Append` (zakładka `NCR` — tworzona w tym ćwiczeniu) → `IF` (krytyczność ≥ 3) → `Send Email` do „kierownika jakości” z tytułem `[KRYTYCZNE]` + `ClickUp: Create task` (`Spotkania`: „8D – {{produkt}}”, due date = jutro 9:00, priorytet urgent).

**Dane wejściowe:** w `Skrzynce` są 3 maile: reklamacja klienta (krytyczna), NCR wewnętrzne (średnie), pytanie dostawcy (niejakościowe — test negatywny).

**W firmie:** Outlook → Excel / SharePoint List → Teams: kanał `#jakość` → Outlook Calendar.

#### 19. Tygodniowy raport ryzyk i szans dla zarządu 🛠 ★★ ⏱ 45 min

**Cel:** złożyć #15, #16, #17, #18 w jeden dokument. Uczy: `Merge` z wielu źródeł, generowanie Google Docs, jeden prompt „menedżerski”.

**Przepływ:** `Schedule Trigger` (piątek 15:00) → równolegle: `Google Sheets: Get rows` (`FMEA`, `Historia`, `NCR`) + `ClickUp: Get many tasks` (`Otwarte sprawy`) → `Merge` → `Code` (KPI: liczba alarmów, trend tydzień/tydzień, % zamkniętych działań na czas) → `OpenAI` (sekcje: *Top 5 ryzyk*, *Top 3 szanse*, *Co wymaga decyzji zarządu*; każdy punkt: fakt → skutek → rekomendacja) → `Google Docs: Create` (folder `Raporty – U01`) → `Send Email` do „zarządu” (link + streszczenie) → `Google Sheets: Append` (`KPI`).

**W firmie:** Excel 365 ×3 + Planner → Word na SharePoint → Outlook → Power BI.

#### 20. Analityk danych na czacie — AI Agent nad arkuszami i ClickUp 📦 ★★★ ⏱ 45 min

**Cel:** zamknięcie szkolenia: menedżer zadaje pytania po polsku, agent sam sięga do danych. Uczy: agent z wieloma narzędziami, `Calculator`, ograniczanie halucynacji (prompt: „odpowiadaj tylko na podstawie danych z narzędzi; jeśli ich nie ma, powiedz, że nie wiesz”).

**Przepływ:** `Chat Trigger` → `AI Agent` z narzędziami: `Google Sheets Tool` ×3 (`FMEA`, `Harmonogram`, `NCR` — tylko odczyt), `ClickUp Tool` (Get many tasks), `Calculator`, `Google Docs Tool` (odczyt ostatniego raportu z #19), `Send Email Tool` (wyślij wynik na maila) + pamięć.

Pytania testowe: *„Które działania korygujące Nowaka są przeterminowane?”*, *„Ile mamy NCR krytycznych w tym miesiącu vs poprzednim?”*, *„Wyślij mi listę wad z RPN powyżej 120 na maila.”*

**W firmie:** te same narzędzia na Excel 365 / SharePoint / Planner; agent jako bot w Teams.

---

### Tabela zbiorcza

| # | Automatyzacja | Blok | Forma | Poziom | ⏱ | Główne node'y |
| :-- | :--- | :-- | :-- | :-- | :-- | :--- |
| 1 | Zgłoś temat: formularz → AI → mail | 0 | 🛠 | ★ | 30 | Form, OpenAI, Send Email |
| 2 | Klasyfikator skrzynki (wzorzec „poczta przychodząca”) | 0 | 🛠 | ★★ | 50 | Schedule, Sheets: Get rows, LLM Chain, Parser, Switch, Sheets: Update |
| 3 | Draft odpowiedzi (human in the loop) | 0 | 📦 | ★★ | 30 | OpenAI, Send Email, Webhook (demo) |
| 4 | Action items z maila → ClickUp | 1 | 🛠 | ★★ | 45 | Parser, Split Out, ClickUp: Create task |
| 5 | Action items z protokołu → zadania + maile | 1 | 📦 | ★★ | 30 | Form, Google Docs, ClickUp, Loop, Send Email |
| 6 | Strażnik terminów + eskalacja | 1 | 🛠 | ★★ | 40 | Schedule, ClickUp: Get many, IF, Send Email |
| 7 | Poniedziałkowy dashboard | 1 | 🛠 | ★★ | 45 | ClickUp, Code, OpenAI, Send Email HTML, Sheets: Append |
| 8 | Zamykanie spraw przez „DONE” | 1 | 📦 | ★★ | 25 | Sheets, Code (regex), ClickUp: Update |
| 9 | Asystent zadań na czacie | 1 | 🛠 | ★★★ | 60 | Chat Trigger, AI Agent, ClickUp Tool, Send Email Tool, Memory |
| 10 | Poranny briefing (spotkania + maile) | 2 | 🛠 | ★★ | 45 | ClickUp, Sheets, Loop, Aggregate, OpenAI |
| 11 | Briefing z dokumentów | 2 | 📦 | ★★ | 35 | Drive: Search, Docs: Get |
| 12 | Podsumowanie spotkania (audio/tekst) | 2 | 🛠 | ★★★ | 60 | Form (plik), Transcribe, Parser, Docs: Create, ClickUp, Send Email |
| 13 | Agenda + zaproszenie | 2 | 📦 | ★★ | 30 | Form, ClickUp, Docs, OpenAI, ClickUp: Create |
| 14 | Follow-up 48 h | 2 | 🎬 | ★★ | 20 | Wait, ClickUp, Filter, Send Email |
| 15 | Monitor FMEA | 3 | 🛠 | ★★ | 45 | Sheets, Code (RPN), Sheets: Update, OpenAI, ClickUp |
| 16 | Opóźnienia z eksportu ERP (CSV / webhook) | 3 | 🛠 | ★★ | 45 | Drive: Download, Extract from File, Code, Webhook |
| 17 | Audyt kompletności dokumentacji | 3 | 📦 | ★★ | 35 | Sheets, Drive: Search, Compare Datasets, ClickUp |
| 18 | Alert jakościowy (reklamacje/NCR) | 3 | 🛠 | ★★ | 40 | Sheets, Parser, IF, Send Email, ClickUp |
| 19 | Tygodniowy raport ryzyk i szans | 3 | 🛠 | ★★ | 45 | Sheets ×3, ClickUp, Merge, Code, OpenAI, Docs: Create |
| 20 | Analityk danych na czacie | 3 | 📦 | ★★★ | 45 | Chat Trigger, AI Agent, Sheets Tool ×3, ClickUp Tool, Calculator |

Suma czasu ćwiczeń: ~13,5 h. Z wprowadzeniem, konfiguracją i przerwami to pełne 2 dni — dlatego część jest 📦/🎬, a nie 🛠.

---

## 4. Plan 2 dni

### Dzień 1 — „Poczta, zadania, terminy” (≈ 8 h z przerwami)

| Czas | Blok | Co |
| :-- | :-- | :-- |
| 9:00–9:45 | Wstęp | Czym jest n8n, wzorzec trigger → dane → AI → akcja, mapowanie firma → szkolenie (sekcja 1). Rozdanie kart. |
| 9:45–10:30 | Konfiguracja | Logowanie do n8n, 4 credentiale (SMTP, Google SA, ClickUp — tu uczestnik generuje token, OpenAI). Test: `Google Sheets: Get rows` na własnym arkuszu + `Send Email` do siebie. |
| 10:30–11:00 | #1 | Pierwszy workflow. |
| 11:15–12:45 | #2, #3 | Wzorzec „poczta przychodząca”, klasyfikator, draft. Metodologia promptów (sekcja 3 głównego skryptu) wpleciona w #2. |
| 13:30–15:00 | #4, #6 | Action items → ClickUp; strażnik terminów. |
| 15:15–16:15 | #7, #8 | Dashboard; domknięcie pętli. (#5 — zadanie „dla szybkich” lub import.) |
| 16:15–17:00 | #9 | Asystent na czacie — wow na koniec dnia. |

### Dzień 2 — „Spotkania i ryzyka” (≈ 8 h)

| Czas | Blok | Co |
| :-- | :-- | :-- |
| 9:00–9:30 | Recap | Import workflowów z dnia 1 dla spóźnionych/nieobecnych; 3 pytania kontrolne. |
| 9:30–11:00 | #10, #11 | Briefing poranny (spotkania seedowane na dziś!). |
| 11:15–12:30 | #12 | Podsumowanie spotkania z nagrania. |
| 12:30–13:00 | #13, #14 | Agenda; follow-up jako demo. |
| 13:45–15:15 | #15, #16 | FMEA; opóźnienia z „ERP” + webhook demo. |
| 15:30–16:30 | #18, #17 | Alert jakościowy; audyt dokumentacji (import). |
| 16:30–17:15 | #19, #20 | Raport dla zarządu; analityk na czacie. |
| 17:15–17:30 | Zamknięcie | „Co przenoszę do firmy w poniedziałek” — każdy wybiera 1 automatyzację i wypisuje, co podmienia (Outlook / Excel / SharePoint / Planner). |

**Zasada bezpieczeństwa czasowego:** jeśli grupa jest wolniejsza, wypadają w tej kolejności: #14, #5, #11, #17, #13. Nigdy nie wypadają: #2, #4, #6, #9, #12, #15, #19.

---

## 5. Osoba dołączająca tylko drugiego dnia

**Tak, ma to sens** — pod trzema warunkami:

1. **Dzień 2 jest samodzielny tematycznie.** Bloki 2 i 3 (spotkania, FMEA/ryzyka) to dokładnie obszary 2 i 3 z listy uczestnika i nie wymagają workflowów z dnia 1 — potrzebna jest tylko lista `Otwarte sprawy` w ClickUp, którą seeder zakłada każdemu.
2. **Środowisko musi być skonfigurowane przed 9:00.** Prowadzący wysyła tej osobie dzień wcześniej kartę z dostępami, zaproszenie do ClickUp i 10-minutową instrukcję (4 credentiale). Alternatywnie przychodzi 30 min wcześniej i robi to z nią. Bez tego straci pierwsze ćwiczenie dnia 2.
3. **Dostaje paczkę z dnia 1 do importu** (JSON-y #1–#9) i w recapie o 9:00 importuje #2 i #4 — wzorzec „poczta przychodząca” i parser strukturalny wracają w #10, #12, #18, #19.

Czego nie nadrobi: praktyki z expressions i debugowania z dnia 1. Dlatego przy tej osobie warto usiąść w #10 (pierwsze samodzielne ćwiczenie dnia 2) — po nim zwykle łapie rytm.

Jeśli ta osoba jest autorem listy trzech obszarów — tym bardziej warto, bo dzień 2 odpowiada na dwa z jej trzech tematów wprost.

---

## 6. Checklista prowadzącego

**Tydzień przed:**
- [ ] 17 instancji n8n (`setup-fleet.sh`), sprawdzone logowanie na każdej
- [ ] SMTP: konto/relay z limitem wysyłki ≥ 500 maili/dzień (16 osób × ~25 testowych maili); jeśli Gmail — App Password, jeśli własny serwer — SPF/DKIM, żeby maile nie lądowały w spamie uczestników
- [ ] Google Cloud: projekt, włączone API (Sheets, Drive, Docs), **Service Account** + klucz JSON, wniosek o podniesienie limitu Sheets API (odczyty/min/użytkownik)
- [ ] Szablon arkusza `Szkolenie – szablon` (zakładki z 2.4) i foldery Drive (2.5) udostępnione dla Service Account
- [ ] ClickUp: workspace `Szkolenie n8n`, zaproszenia wysłane na adresy z `participants.csv`, 16 folderów `U01…U16` z listami `Otwarte sprawy` i `Spotkania`, pola niestandardowe, statusy
- [ ] Klucze OpenAI (osobne lub wspólny z limitem), doładowane saldo (~2–3 USD/os. przy gpt-4.1-mini)
- [ ] Nagranie `spotkanie.mp3` (3 min)
- [ ] Workflow-seeder przetestowany na 1 uczestniku: kopia arkusza z szablonu (Drive: Copy) + wpisanie adresu uczestnika do `Zespołu`, folder `Raporty – Uxx`, 3 spotkania i 3 przeterminowane zadania w ClickUp (token prowadzącego, listy uczestnika)
- [ ] Workflow `Dosyłacz` (Form → Append do 16 `Skrzynek`)
- [ ] JSON-y wszystkich 20 workflowów wyeksportowane, credentiale w nich **odpięte**, ID arkuszy/list jako pola do podmiany na górze workflow (`Set` node „Konfiguracja”)

**Dzień przed:**
- [ ] Seeder uruchomiony dla wszystkich 16; terminy spotkań w ClickUp = dzień 2 szkolenia, zadania „przeterminowane” = wczoraj względem dnia 1
- [ ] Karta z dostępami + instrukcja wysłana do osoby dołączającej drugiego dnia
- [ ] Test end-to-end #2 i #10 na losowym arkuszu/folderze uczestnika, z instancji uczestnika

**W trakcie:**
- [ ] `Dosyłacz` otwarty na drugim ekranie; przygotowane treści maili do #2, #4, #8, #18
- [ ] `curl` do webhooka (#16) w schowku
- [ ] Po każdym bloku: JSON-y na wspólny folder Drive (link publiczny)
- [ ] Obserwacja limitu Sheets API w Cloud Console (wykres 429) — jeśli rośnie: „wyłączcie Active, klikajcie Execute”

**Po szkoleniu:**
- [ ] Wyłączyć klucze OpenAI, zrotować hasło SMTP, usunąć klucz Service Account, usunąć uczestników z workspace ClickUp (lub zostawić — ich decyzja)
- [ ] Zostawić uczestnikom paczkę JSON + ten dokument + tabelę mapowania (sekcja 1)

# Szkolenie n8n — Uniwersytet Łódzki

## No-code, low-code w zarządzaniu

**Dla kogo:** Uczestnicy szkolenia bez wcześniejszego doświadczenia z n8n. **Cel:** Zbudować od zera trzy automatyzacje, które realnie odciążają menedżera w codziennej pracy. **Forma:** Instrukcja krok po kroku — czytasz, klikasz, widzisz efekt.

---

## Spis treści

1. [Wprowadzenie — czym jest n8n i dlaczego warto](#1-wprowadzenie)  
2. [Konfiguracja środowiska — wklej swoje klucze](#2-konfiguracja-środowiska)  
3. [Metodologia — jak pisać prompty do LLM](#3-metodologia--jak-pisać-prompty-do-llm)  
4. [Scenariusz 1 — Inteligentny Raport Menedżerski](#4-scenariusz-1--inteligentny-raport-menedżerski)  
5. [Scenariusz 2 — Automatyzacja maili z AI](#5-scenariusz-2--automatyzacja-maili-z-ai)  
6. [Scenariusz 3 — Webhooki: Wizytówki w czasie rzeczywistym](#6-scenariusz-3--webhooki-wizytówki-w-czasie-rzeczywistym)  
8. [Dodatek A — Najczęstsze błędy](#dodatek-b--najczęstsze-błędy)  
9. [Dodatek B — Co dalej?](#dodatek-c--co-dalej)

---

## 1\. Wprowadzenie

### Czym jest n8n?

n8n to narzędzie typu **low-code/no-code** do budowy automatyzacji. Łączysz "klocki" (zwane **node'ami**) w **workflow** — przepływ pracy, który robi coś za Ciebie: pobiera dane z jednego systemu, przetwarza je, wysyła do drugiego.

Przykład z życia: zamiast w poniedziałek rano przez godzinę kopiować dane z Excela do prezentacji, klikasz raz — i raport sam ląduje na Twoim mailu. Tak ma być po szkoleniu.

### Czym n8n różni się od Blue Prism (i podobnych "klasycznych" narzędzi RPA)?

To pytanie warto zrozumieć od razu, bo wpływa na to, **jak myślisz o automatyzacji**:

| Aspekt | Blue Prism (klasyczne RPA) | n8n |
| :---- | :---- | :---- |
| **Filozofia** | Reaktywna — "udaje" człowieka klikającego w UI | Event-driven — reaguje na zdarzenia przez API i webhooki |
| **Sposób integracji** | Screen scraping, surface automation | API-first, webhooki |
| **Czas reakcji** | Cykliczne odpytywanie (np. co 5 min) | Natychmiast (webhook odpala proces real-time) |
| **AI w procesie** | Wymaga integracji przez IT | Wbudowany node "AI Agent" — działa od razu |
| **Próg wejścia** | Wysokie kompetencje techniczne | Można zacząć w godzinę |

**Wniosek:** n8n to narzędzie dla osoby, która chce **myśleć o procesie, a nie o technicznych integracjach**. To dlatego znalazło się na szkoleniu z zarządzania, a nie z programowania.

### Co umieść po szkoleniu?

Po przejściu trzech scenariuszy będziesz potrafił/-a:

- Połączyć n8n z zewnętrznymi systemami (ClickUp, Gmail/SMTP, OpenAI),  
- Pisać prompty do LLM, które rzeczywiście działają,  
- Generować kod JavaScript w n8n bez znajomości JavaScript — przez prompt do AI,  
- Reagować na zdarzenia w czasie rzeczywistym przez webhooki,  
- Zbudować swój własny scenariusz na podstawie tego, co zobaczyłeś/-aś.

### Jak korzystać z tego dokumentu

Każdy scenariusz ma tę samą strukturę:

1. **Proces PRZED automatyzacją** — jak wygląda dzisiaj, co boli.  
2. **Proces PO automatyzacji** — jak ma wyglądać po szkoleniu.  
3. **Mapa workflow** — wszystkie node'y po kolei.  
4. **Budowa krok po kroku** — co kliknąć, co wpisać.  
5. **Prompty do LLM** — jak skłonić AI do napisania tego za Ciebie.  
6. **Pomysły na rozszerzenia** — co możesz zrobić sam/-a po szkoleniu.

### Słownik pojęć

| Pojęcie | Co to znaczy |
| :---- | :---- |
| **Workflow** | Cały scenariusz automatyzacji — zestaw połączonych node'ów. |
| **Node** | Pojedynczy "klocek" — jedna akcja (pobierz dane, wyślij maila itd.). |
| **Trigger** | Pierwszy node — to, co odpala workflow (czas, webhook, mail). |
| **Credential** | Zapisane dane logowania do zewnętrznego systemu. |
| **Expression** | Dynamiczna wartość w `{{ }}` — np. `{{ $json.email }}`. |
| **`$json`** | Dane wchodzące do bieżącego node'a. |
| **`$input.all()`** | W node Code — tablica wszystkich elementów wchodzących. |
| **`$('Nazwa Node').item.json`** | Dostęp do danych z konkretnego wcześniejszego node'a. |
| **Webhook** | URL, który po wywołaniu z zewnątrz odpala workflow w czasie rzeczywistym. |
| **Code node** | Node, w którym piszesz własny JavaScript / Python. |
| **AI Agent** | Wbudowany w n8n node do komunikacji z LLM. |
| **Execute step** | Uruchom tylko ten node (do testów krok po kroku). |
| **Active workflow** | Workflow, który działa "na produkcji" — trigger jest aktywny. |

---

## 2\. Konfiguracja środowiska

Zanim zaczniesz cokolwiek budować, musisz dać n8n **dostęp do trzech systemów**: ClickUp, OpenAI (LLM) i serwer pocztowy SMTP. To się robi raz i działa potem we wszystkich scenariuszach.

**Ważne:** Klucze API to jak hasła. Nie wklejaj ich na czat, nie commituj do GitHuba, nie pokazuj na ekranie podczas prezentacji.

### 2.1 Klucze, które będziesz potrzebować

Wpisz swoje wartości w tabelce poniżej (lub miej je pod ręką w innym miejscu):

```
┌─────────────────────────────────────────────────────────┐
│  MOJE KLUCZE — WYPEŁNIJ PRZED SZKOLENIEM                │
├─────────────────────────────────────────────────────────┤
│  ClickUp API Token:    pk_____________________________  │
│  ClickUp Workspace ID: ________________________________ │
│                                                         │
│  OpenAI API Key:       sk-____________________________  │
│                                                         │
│  SMTP Host:            ________________________________ │
│  SMTP Port:            ________________________________ │
│  SMTP User:            ________________________________ │
│  SMTP Password:        ________________________________ │
│  SMTP From (email):    ________________________________ │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Skąd wziąć klucze

#### ClickUp API Token

1. Zaloguj się do ClickUp → kliknij swój awatar w lewym dolnym rogu.  
2. **Settings** → **Apps** → sekcja **API Token**.  
3. Kliknij **Generate** (lub **Regenerate** jeśli już masz).  
4. Skopiuj token zaczynający się od `pk_`.

**Workspace ID** znajdziesz w URL: `https://app.clickup.com/{WORKSPACE_ID}/...` — to ten numer po `clickup.com/`.

#### OpenAI API Key

1. Wejdź na [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys).  
2. Zaloguj się → **Create new secret key**.  
3. Skopiuj klucz zaczynający się od `sk-`. **Po zamknięciu okna już go nie zobaczysz** — zapisz od razu.  
4. Upewnij się, że masz doładowane saldo (Settings → Billing). Bez tego API zwróci błąd `insufficient_quota`.

#### SMTP

Dane SMTP zależą od dostawcy poczty. Najpopularniejsze:

- **Gmail**: host `smtp.gmail.com`, port `587`, użytkownik \= Twój email, hasło \= **App Password** (nie zwykłe hasło konta — musisz wygenerować w ustawieniach Google).  
- **Outlook/Office 365**: host `smtp.office365.com`, port `587`.  
- **Własny serwer**: zapytaj administratora.

Jeśli organizator szkolenia dostarcza dostęp SMTP — masz go w materiałach od prowadzącego.

### 2.3 Dodawanie credentials w n8n

W n8n każde połączenie z zewnętrznym systemem to **Credential**. Dodajesz je raz, używasz wszędzie.

**Krok po kroku:**

1. W lewym menu n8n kliknij **Credentials**.  
2. Kliknij **Add Credential** (prawy górny róg).  
3. Wpisz w wyszukiwarce nazwę — np. `ClickUp`, `OpenAI`, `SMTP`.  
4. Wybierz odpowiedni typ z listy:  
   - **ClickUp** → wybierz `ClickUp API` → wklej swój API Token.  
   - **OpenAI** → wybierz `OpenAi API` → wklej swój klucz.  
   - **SMTP** → wybierz `SMTP` → wpisz host, port, użytkownika, hasło.  
5. Kliknij **Save**. n8n od razu spróbuje przetestować połączenie — jeśli wyrzuci błąd, sprawdź dane.

**Nazewnictwo:** nadaj credentialom czytelne nazwy, np. `ClickUp - moje konto`, `OpenAI - szkolenie`, `SMTP - Gmail`. Łatwiej wybierzesz w workflow.

### 2.4 Szybki test

Zanim ruszysz dalej — sprawdź, czy każdy credential działa:

1. Stwórz nowy workflow (**Workflows** → **Add workflow**).  
2. Dodaj node **HTTP Request** lub bezpośrednio node **ClickUp** / **OpenAI** / **Send Email**.  
3. Wybierz swój credential, ustaw najprostszą operację (np. ClickUp → "Get Workspaces"; OpenAI → wyślij prompt "Cześć"; SMTP → wyślij testowego maila do siebie).  
4. Kliknij **Execute step**. Jeśli zwróci dane bez błędu — credential działa.

Ten test zajmuje 5 minut, a oszczędza godzinę debugowania w trakcie scenariuszy.

---

## 3\. Metodologia — jak pisać prompty do LLM

W tym szkoleniu **nie dajemy gotowych promptów do skopiowania**. Dajemy coś więcej: **metodę, jak je pisać samemu**, żeby po szkoleniu nie być od nas zależnym.

### 3.1 Anatomia dobrego promptu

Każdy prompt do LLM ma cztery elementy. Brak któregokolwiek \= słaby wynik.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  1. ROLA                                                │
│     Kim ma być LLM? "Jesteś programistą n8n..."         │
│                                                         │
│  2. KONTEKST                                            │
│     Co dzieje się dookoła? Jakie dane wchodzą?          │
│     Jaki jest cel biznesowy?                            │
│                                                         │
│  3. ZADANIE                                             │
│     Co dokładnie ma zrobić? Jeden konkret.              │
│                                                         │
│  4. FORMAT WYJŚCIA                                      │
│     Jak ma wyglądać odpowiedź?                          │
│     JSON? Kod? Lista? Tabela?                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Przykład — prompt SŁABY:**

"Napisz mi kod do n8n co wyciąga zadania z ClickUp."

Co jest nie tak? Brak roli, brak kontekstu, brak formatu. LLM zgadnie i prawdopodobnie się pomyli.

**Przykład — prompt DOBRY:**

**\[ROLA\]** Jesteś programistą JavaScript piszącym kod do node'a "Code" w n8n.

**\[KONTEKST\]** Dostajesz na wejściu listę zadań z ClickUp w formacie JSON. Każde zadanie ma pola: `name`, `due_date` (timestamp w ms), `assignees` (tablica obiektów z polem `username`), `list`, `folder`, `space`.

**\[ZADANIE\]** Wygeneruj kod, który dla każdego zadania zwróci obiekt z polami: `space`, `folder`, `list`, `task_name`, `is_overdue` (true/false — przeterminowane jeśli `due_date < now`), `due_human` (data w formacie "23 maja 2026"), `assignee` (pierwszy username z `assignees` lub "brak").

**\[FORMAT\]** Sam kod JavaScript, gotowy do wklejenia w node Code w n8n. Bez komentarzy w stylu "tutaj wstaw...", bez markdown — tylko czysty kod.

Różnica jest dramatyczna. Drugi prompt da Ci kod gotowy do wklejenia.

### 3.2 Reguły, które oszczędzą Ci godziny

**Reguła 1: Mów co MA być, nie co NIE MA być.**

- ❌ "Nie używaj fetch"  
- ✅ "Użyj wyłącznie funkcji `$input.all()` dostępnej w n8n"

**Reguła 2: Podaj przykład danych wejściowych.** Skopiuj z poprzedniego node'a kawałek JSON-a i wklej do promptu jako `[DANE]`. LLM przestanie zgadywać strukturę.

**Reguła 3: Iteruj.** Pierwszy prompt rzadko daje idealny wynik. Druga runda powinna brzmieć: "W poprzednim kodzie zmień X. Reszta zostaje."

**Reguła 4: Rozdziel "co" od "jak".** Najpierw opisz problem biznesowy. Potem techniczne wymagania. Mieszanie ich daje chaos.

**Reguła 5: Format wyjścia jest kluczowy dla node Code.** W n8n Code node oczekuje, że zwrócisz **tablicę obiektów**: `return [{json: {...}}, {json: {...}}]`. Zawsze proś LLM, żeby zwracał kod w tej konwencji.

### 3.3 Szablon promptu do node Code w n8n

Skopiuj sobie ten szablon i wypełniaj przy każdym node Code:

```
Jesteś programistą JavaScript piszącym kod do node'a "Code" w n8n
(środowisko: Node.js, dostępna jest funkcja $input.all() zwracająca
tablicę obiektów {json: {...}}).

KONTEKST:
- Poprzedni node zwraca dane w formacie: [TUTAJ WKLEJ PRZYKŁAD JSON]
- Cel biznesowy: [TUTAJ OPISZ PO LUDZKU CO MA SIĘ STAĆ]

ZADANIE:
[TUTAJ KONKRETNIE: jakie pola wyciągnąć, jakie przekształcenia,
jakie warunki, jaki ma być wynik]

FORMAT WYJŚCIA:
- Czysty kod JavaScript bez markdown.
- Zwracana wartość: tablica obiektów w formacie n8n,
  czyli: return items.map(item => ({json: {...}}))
- Bez komentarzy "tutaj wstaw swoje...".
- Bez konsola.log na produkcję.
```

Zapamiętaj go. Będziemy go używać w każdym scenariuszu.

### 3.4 Szablon promptu do AI Agent / generowania treści

Gdy LLM ma **wygenerować treść** (a nie kod) — np. odpowiedź na maila, raport HTML, klasyfikację sentymentu — używaj tego szablonu:

```
ROLA: [kim jest LLM? np. "Jesteś asystentem menedżera"]

ZADANIE: [co ma zrobić? np. "Sklasyfikuj sentyment maila i napisz draft odpowiedzi"]

DANE WEJŚCIOWE:
[treść maila, dane, kontekst]

ZASADY:
- [styl, ton, długość]
- [czego unikać]
- [co jest priorytetem]

FORMAT ODPOWIEDZI:
[JSON ze strukturą / czysty tekst / HTML / inne]

PRZYKŁAD POPRAWNEJ ODPOWIEDZI:
[1-2 przykłady — to tzw. "few-shot prompting", drastycznie poprawia jakość]
```

---

## 4\. Scenariusz 1 — Inteligentny Raport Menedżerski

### 4.1 Proces PRZED automatyzacją

**Poniedziałek, 8:30 rano. Manager przy biurku.**

Otwiera ClickUp. Filtruje zadania z poprzedniego tygodnia. Kopiuje listę przeterminowanych zadań do notatnika. Otwiera Excel ze sprzedażą. Wkleja, formatuje. Otwiera bank — sprawdza wydatki. Wszystko zlepione w PowerPoincie. Wysyła zarządowi.

**Co poszło nie tak?**

- 60-90 minut tygodniowo na **kopiowanie**.  
- Błędy ludzkie (zapomniał kolumny, pomylił datę).  
- Decyzje na podstawie "przeczucia", bo dane nigdy nie są aktualne.  
- Manager nienawidzi poniedziałków.

### 4.2 Proces PO automatyzacji

**Poniedziałek, 8:30 rano. Manager bierze kawę.**

W skrzynce mailowej czeka raport PDF z danymi z ClickUp (przeterminowane zadania, kto odpowiada, do kiedy miało być). Workflow odpalił się o 8:00 automatycznie. Manager otwiera maila, czyta raport, ustala priorytety.

**Co zyskujemy:**

- 0 minut kopiowania.  
- 0 błędów (jak coś jest źle, to systemowo, więc raz naprawiamy i działa).  
- Decyzje na twardych danych.  
- Manager lubi poniedziałki.

### 4.3 Mapa workflow

Zanim zaczniesz klikać — zobacz całość:

```
┌──────────┐    ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌─────────┐
│ Schedule │───▶│ ClickUp │───▶│  Code    │───▶│  Code    │───▶│  Send   │
│ Trigger  │    │ Get All │    │ Filtruj  │    │ Generuj  │    │  Email  │
│ (8:00)   │    │ Tasks   │    │ + format │    │  HTML    │    │  SMTP   │
└──────────┘    └─────────┘    └──────────┘    └──────────┘    └─────────┘
```

Pięć node'ów. To wszystko.

### 4.4 Budowa krok po kroku

#### Krok 1: Schedule Trigger

1. **Workflows** → **Add workflow** → nazwij: `Raport Menedżerski`.  
2. Kliknij **\+** na canvasie → wpisz `Schedule` → wybierz **Schedule Trigger**.  
3. **Trigger Interval**: `Cron`.  
4. **Cron Expression**: `0 8 * * 1` (każdy poniedziałek o 8:00).  
5. **Save**.

**Wskazówka:** Na początku ustaw na **Every Minute**, żeby szybko testować. Cron ustawisz na końcu, jak workflow działa.

#### Krok 2: ClickUp — pobierz zadania

1. **\+** za Schedule Trigger → wpisz `ClickUp` → wybierz **ClickUp**.  
2. **Credential**: wybierz swój `ClickUp - moje konto`.  
3. **Resource**: `Task`.  
4. **Operation**: `Get All`.  
5. **Team / Workspace**: wybierz z listy.  
6. **Space / Folder / List**: zostaw lub zawęź (jeśli chcesz tylko z konkretnej listy).  
7. **Return All**: ✅ włączone.  
8. **Execute step** — sprawdź, czy wraca lista zadań.

#### Krok 3: Code — przygotuj dane z ClickUp

To jest pierwszy node, do którego napiszemy prompt do LLM.

**Co ten node ma zrobić?** Z ogromnego JSON-a z ClickUp wyciągnąć dla każdego zadania tylko to, co potrzebne do raportu: space, folder, lista, nazwa zadania, czy przeterminowane, do kiedy było, kto odpowiada.

**Twój prompt do LLM** (np. ChatGPT, Claude — gdziekolwiek piszesz prompty):

```
Jesteś programistą JavaScript piszącym kod do node'a "Code" w n8n.

KONTEKST:
Poprzedni node "ClickUp - Get All" zwraca tablicę zadań. Każdy element ma
strukturę zbliżoną do (skróconą):

{
  "id": "abc123",
  "name": "Nazwa zadania",
  "due_date": "1716422400000",   // timestamp w ms jako string
  "assignees": [{"username": "Anna K."}, ...],
  "list": {"name": "Lista X"},
  "folder": {"name": "Folder Y"},
  "space": {"name": "Space Z"}
}

CEL BIZNESOWY:
Manager chce na poniedziałkowym mailu zobaczyć zwięzłą listę zadań,
ze szczególnym wskazaniem przeterminowanych.

ZADANIE:
Dla każdego zadania zwróć obiekt z polami:
- space        (nazwa space)
- folder       (nazwa folderu, lub "—" jeśli brak)
- list         (nazwa listy)
- task_name    (nazwa zadania)
- is_overdue   (true/false — true jeśli due_date jest w przeszłości)
- due_human    (data w formacie "23 maja 2026" w języku polskim,
                lub "brak terminu" jeśli due_date pusty)
- assignee     (username pierwszej osoby z assignees, lub "brak")

FORMAT WYJŚCIA:
- Czysty kod JavaScript bez markdown.
- Zakończony: return items.map(item => ({json: {...}}))
- Pamiętaj, że due_date to STRING z timestampem w ms — trzeba zrobić
  Number(due_date) przed użyciem w new Date().
- W n8n dane wejściowe pobierasz przez const items = $input.all();
  i każdy element ma strukturę {json: {...rzeczywiste dane...}}.
```

Skopiuj wynik z LLM, wklej do node Code, **Execute step** — sprawdź wynik.

**Co zrobić jak nie działa?** Patrz Dodatek B — najczęstsze błędy.

#### Krok 4: Code — wygeneruj HTML do maila

Ten node bierze przefiltrowane dane i robi z nich ładny HTML.

**Twój prompt do LLM:**

```
Jesteś programistą JavaScript piszącym kod do node'a "Code" w n8n.

KONTEKST:
Poprzedni node Code zwraca tablicę zadań w formacie:

{
  space: "Marketing",
  folder: "Q2",
  list: "Kampania majowa",
  task_name: "Brief dla agencji",
  is_overdue: true,
  due_human: "20 maja 2026",
  assignee: "Anna K."
}

CEL BIZNESOWY:
Wysłać managerowi mail z TYLKO przeterminowanymi zadaniami,
sformatowanymi jako tabela HTML.

ZADANIE:
1. Filtruj: zostaw tylko zadania z is_overdue === true.
2. Jeśli po filtrze tablica jest pusta — zwróć HTML z komunikatem
   "Wszystkie zadania w terminie — gratulacje!".
3. W przeciwnym razie wygeneruj HTML zawierający:
   - nagłówek <h2> "Zadania przeterminowane — raport tygodniowy"
   - tabelę z kolumnami: Space | Folder | Lista | Zadanie | Termin | Osoba
   - wiersze z danymi zadań
   - delikatny styl inline (border, padding, font-family sans-serif)
   - na końcu: liczba przeterminowanych zadań

FORMAT WYJŚCIA:
- Czysty kod JavaScript do node Code.
- Zwracana wartość: return [{ json: { html: "<...>" } }]
- HTML ma być w jednym stringu, dobrze sformatowany,
  z escapowaniem znaków specjalnych w nazwach zadań (& < >).
```

Wklej wynik, **Execute step**, sprawdź czy w `html` wraca poprawny HTML.

#### Krok 5: Send Email (SMTP)

1. **\+** za drugim Code → wpisz `email` → wybierz **Send Email**.  
2. **Credential**: wybierz swój `SMTP - Gmail` (lub jak nazwałeś).  
3. **From Email**: Twój adres.  
4. **To Email**: adres managera (na szkoleniu — Twój własny do testów).  
5. **Subject**: `Raport tygodniowy — {{ $now.format('dd.MM.yyyy') }}`  
6. **Email Format**: `HTML`.  
7. **HTML Body**: `{{ $json.html }}` — to wyrażenie wyciąga pole `html` z poprzedniego node'a.  
8. **Execute step** — sprawdź skrzynkę.

#### Krok 6: Aktywacja

Wszystko działa? Wróć do Schedule Trigger, ustaw Cron na poniedziałek 8:00, **Save**, przełącz workflow w prawym górnym rogu na **Active**.

Gotowe.

### 4.5 Pomysły na rozszerzenia

- **Dodaj dane ze sprzedaży z CRM** (kolejny node przed Code) — masz raport multi-source.  
- **Wygeneruj PDF zamiast HTML** — node `HTML to PDF` lub external service.  
- **Dodaj wykres** — biblioteka QuickChart przez HTTP Request, wstaw obrazek do maila.  
- **Ranking osób z największą liczbą przeterminowań** — kolejne pole w prompcie.

---

## 5\. Scenariusz 2 — Automatyzacja maili z AI

### 5.1 Proces PRZED automatyzacją

**Wtorek, 14:00. Skrzynka mailowa managera ma 47 nieprzeczytanych.**

Każdy mail trzeba: przeczytać, ocenić "czy pilny", "czy klient niezadowolony", napisać odpowiedź albo przekazać do zespołu, zapisać sprawę w CRM. Średnio 3-5 minut na maila. **47 maili × 4 minuty \= 3 godziny dziennie tylko na obsługę poczty.**

W Blue Prism trzeba by zadzwonić do IT, żeby zintegrowali z OpenAI API. Tydzień. W n8n — node "AI Agent" i działa.

### 5.2 Proces PO automatyzacji

**Wtorek, 14:00. Manager pije kawę.**

Każdy mail od klienta jest automatycznie:

1. Klasyfikowany pod kątem **sentymentu** (pozytywny / neutralny / negatywny / pilny).  
2. Analizowany pod kątem **intencji** (pytanie / reklamacja / zamówienie / inne).  
3. Generowany jest **draft odpowiedzi** dopasowany do tonu klienta.  
4. Zapisany jako zadanie w **ClickUp** z odpowiednim tagiem i priorytetem.

Manager dostaje listę draftów do akceptacji. 47 maili × 30 sekund na akceptację \= **23 minuty zamiast 3 godzin**.

### 5.3 Mapa workflow

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Email   │───▶│ AI Agent │───▶│  Code    │───▶│ ClickUp  │
│ Trigger  │    │ Klasyfi- │    │ Parse    │    │ Create   │
│  (IMAP)  │    │ kacja    │    │ JSON     │    │ Task     │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                                                       │
                                                       ▼
                                                 ┌──────────┐
                                                 │  Send    │
                                                 │  Email   │
                                                 │ (draft)  │
                                                 └──────────┘
```

### 5.4 Budowa krok po kroku

#### Krok 1: Email Trigger (IMAP)

1. Nowy workflow: `Automatyzacja maili AI`.  
2. **\+** → wpisz `email` → **Email Trigger (IMAP)**.  
3. **Credential**: dodaj nowy IMAP — host, port, user, password (analogicznie do SMTP, tylko do odbioru).  
4. **Mailbox**: `INBOX`.  
5. **Action**: `Read New Emails`.  
6. **Format**: `Resolved`.  
7. **Save**.

Na szkoleniu jeśli nie chcemy używać prawdziwej skrzynki — można podmienić ten node na **Manual Trigger** \+ node `Set` z przykładowym mailem (w Dodatku C).

#### Krok 2: AI Agent — klasyfikacja i draft

1. **\+** za Email Trigger → wpisz `AI` → wybierz **AI Agent**.  
2. **Credential** (LLM): wybierz `OpenAI - szkolenie`.  
3. **Model**: `gpt-4o-mini` (taniej do testów) lub `gpt-4o` (lepsze wyniki).  
4. **Prompt** — to jest najważniejsze pole.

**Twój prompt** (zgodnie z metodologią z sekcji 3.4):

```
ROLA:
Jesteś asystentem menedżera obsługującym pocztę klientów. Twoja praca:
sklasyfikować maila i przygotować draft odpowiedzi.

ZADANIE:
Przeanalizuj poniższego maila i zwróć dane w formacie JSON:

DANE WEJŚCIOWE:
Temat: {{ $json.subject }}
Od: {{ $json.from.value[0].address }}
Treść:
{{ $json.text }}

ZASADY:
- Sentyment ocenij na skali: positive / neutral / negative / urgent.
- Intencja: question / complaint / order / feedback / other.
- Draft odpowiedzi:
  * Po polsku, ton dopasowany do klienta (formalny dla negative/urgent,
    przyjazny dla positive/neutral).
  * Maks. 5 zdań.
  * Bez obietnic, których nie możemy spełnić ("zwrot w 24h" itp.).
  * Bez wymyślania faktów (np. cen, terminów wysyłki).
  * Zakończ "Pozdrawiam, Zespół Obsługi Klienta".
- Priorytet ClickUp:
  * urgent → urgent
  * negative → high
  * question/complaint → normal
  * pozostałe → low

FORMAT ODPOWIEDZI (czysty JSON, bez markdown, bez backticków):
{
  "sentiment": "positive|neutral|negative|urgent",
  "intent": "question|complaint|order|feedback|other",
  "priority": "urgent|high|normal|low",
  "summary": "jednozdaniowe streszczenie sprawy",
  "draft": "treść draftu odpowiedzi"
}

PRZYKŁAD:
Wejście: "Zamówiłem 3 dni temu, nadal nie ma. To skandal."
Wyjście:
{
  "sentiment": "negative",
  "intent": "complaint",
  "priority": "high",
  "summary": "Klient skarży się na opóźnienie wysyłki zamówienia.",
  "draft": "Dzień dobry,\n\nDziękujemy za kontakt i przepraszamy za opóźnienie. Sprawdzę status Pana/Pani zamówienia i wrócę z konkretną informacją w ciągu najbliższych godzin.\n\nPozdrawiam,\nZespół Obsługi Klienta"
}
```

5. **Execute step** — sprawdź czy wraca poprawny JSON.

#### Krok 3: Code — parsuj JSON od LLM

LLM zwraca string. Musimy go zmienić na obiekt, żeby kolejne node'y miały dostęp do pól.

**Twój prompt:**

````
Jesteś programistą JavaScript piszącym kod do node'a "Code" w n8n.

KONTEKST:
Poprzedni node "AI Agent" zwraca obiekt z polem "output" zawierającym
string z JSON-em (LLM wygenerował JSON jako tekst).

Czasem LLM owija JSON w ```json ... ``` mimo prośby — trzeba to obsłużyć.

ZADANIE:
1. Pobierz dane z $input.all().
2. Dla każdego elementu: weź pole "output" (string).
3. Usuń ewentualne ``` na początku/końcu i słowo "json" jeśli jest.
4. Sparsuj JSON.
5. Zwróć obiekt z polami: sentiment, intent, priority, summary, draft
   plus oryginalne pola maila (from, subject) z elementu wejściowego
   pod kluczem .json.email (jeśli były tam przekazane) lub z
   wcześniejszego node'a Email Trigger przez $('Email Trigger (IMAP)').first().json.

FORMAT WYJŚCIA:
- Czysty kod JavaScript do node Code.
- Obsługa błędu parsowania: jeśli JSON.parse rzuci błąd, zwróć obiekt
  z polem error: "Nie udało się sparsować odpowiedzi LLM" i zachowaj
  oryginalny output.
- return items.map(...) ze strukturą { json: { ... } }
````

#### Krok 4: ClickUp — utwórz zadanie

1. **\+** za Code → wpisz `ClickUp` → **ClickUp**.  
2. **Resource**: `Task`.  
3. **Operation**: `Create`.  
4. **List**: wybierz listę "Inbox \- klienci" (lub inną).  
5. **Name**: `{{ $json.summary }}` — streszczenie z LLM.  
6. **Additional Fields** → **Description**: wstaw oryginalny mail \+ draft \+ sentyment.  
7. **Additional Fields** → **Priority**: użyj wyrażenia mapującego `priority` z LLM na liczby ClickUp (urgent=1, high=2, normal=3, low=4).  
8. **Execute step**.

#### Krok 5: Send Email — wyślij draft do akceptacji

1. **\+** za ClickUp → **Send Email**.  
2. **To Email**: adres managera.  
3. **Subject**: `[DRAFT do akceptacji] {{ $json.summary }}`.  
4. **HTML Body**:

```html
<h3>Sentyment: {{ $json.sentiment }} | Intencja: {{ $json.intent }}</h3>
<p><b>Streszczenie:</b> {{ $json.summary }}</p>
<hr>
<h4>Proponowany draft odpowiedzi:</h4>
<pre>{{ $json.draft }}</pre>
<p><i>Zadanie utworzone w ClickUp.</i></p>
```

5. **Execute step**.

### 5.5 Pomysły na rozszerzenia

- **Auto-wysyłka** dla sentyment=positive — bez czekania na akceptację.  
- **Tłumaczenie** maili z innych języków przed klasyfikacją.  
- **Załączniki** — analiza PDFów (faktur, dokumentów) przez OpenAI Vision.  
- **Integracja ze Slack** — pilne sprawy lecą od razu na kanał.

---

## 6\. Scenariusz 3 — Webhooki: Wizytówki w czasie rzeczywistym

### 6.1 Proces PRZED automatyzacją

**Konferencja, środa, 11:00. Stoisko firmowe.**

Klient zostawia wizytówkę. Wieczorem ktoś z zespołu przepisuje 50 wizytówek do CRM. Następnego dnia "wpadkowy" mail follow-up. Połowa kontaktów przepisana z błędem. Część zgubiona. Sprzedaż mówi "to leady słabej jakości" — bo dotarły 3 dni za późno.

W Blue Prism rozwiązanie: skrypt odpytujący formularz **co 5 minut**. Czyli 5-minutowy delay na każdy lead. Plus integracja przez IT.

### 6.2 Proces PO automatyzacji

**Konferencja, środa, 11:00. Stoisko firmowe.**

Klient skanuje QR kod stoiska, wypełnia krótki formularz (Typeform / Tally / własny). Naciska **Wyślij**. **W tym samym momencie:**

- Webhook w n8n odpala workflow.  
- LLM analizuje wpisy i kategoryzuje lead (hot / warm / cold).  
- Powstaje karta w ClickUp.  
- Kanał Slack \#leady dostaje powiadomienie z kluczowymi danymi.  
- Klient dostaje spersonalizowanego maila w 30 sekund od wypełnienia.

**Efekt:** Sprzedaż ma "świeży" lead w czasie, gdy klient jeszcze stoi przy stoisku.

### 6.3 Mapa workflow

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Webhook  │───▶│ AI Agent │───▶│ ClickUp  │───▶│  Slack   │
│ (form)   │    │  Klasyf. │    │  Create  │    │  Notify  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                                                       │
                                                       ▼
                                                 ┌──────────┐
                                                 │  Send    │
                                                 │  Email   │
                                                 │ (klient) │
                                                 └──────────┘
```

### 6.4 Budowa krok po kroku

#### Krok 1: Webhook

1. Nowy workflow: `Wizytówki real-time`.  
2. **\+** → wpisz `webhook` → **Webhook**.  
3. **HTTP Method**: `POST`.  
4. **Path**: `wizytowka` (n8n wygeneruje pełny URL).  
5. **Respond**: `When Last Node Finishes`.  
6. **Save** — n8n pokaże dwa URL-e: **Test URL** (do prób) i **Production URL** (po aktywacji).

Test URL działa tylko gdy klikniesz **Listen for test event** w node'ie. Production URL działa zawsze, gdy workflow jest **Active**.

7. **Listen for test event** → w drugiej karcie przeglądarki użyj narzędzia w stylu Postman / curl, żeby wysłać testowy POST z przykładowymi danymi:

```json
{
  "name": "Jan Kowalski",
  "email": "jan@firma.pl",
  "company": "Firma X",
  "interest": "Szukam rozwiązania do raportowania sprzedaży, mamy ok 50 osób w zespole, budżet do uzgodnienia.",
  "phone": "+48 600 000 000"
}
```

Webhook złapie payload i pokaże go w n8n.

#### Krok 2: AI Agent — kategoryzacja leada

**Twój prompt:**

```
ROLA:
Jesteś analitykiem sprzedaży. Twoja praca: ocenić "temperaturę" leada
i wygenerować spersonalizowanego maila powitalnego.

DANE WEJŚCIOWE:
Imię: {{ $json.body.name }}
Firma: {{ $json.body.company }}
Email: {{ $json.body.email }}
Wpis "czego szuka":
{{ $json.body.interest }}

ZASADY OCENY TEMPERATURY:
- HOT: konkretna potrzeba + sygnały budżetu/skali ("50 osób",
  "budżet do uzgodnienia", "do końca miesiąca").
- WARM: konkretna potrzeba bez sygnałów budżetu.
- COLD: ogólne zainteresowanie ("chcę poznać produkt", brak konkretu).

ZASADY GENEROWANIA MAILA:
- Zwróć się po imieniu, podziękuj za kontakt na konferencji.
- W jednym zdaniu odnieś się do jego konkretnej potrzeby
  (zacytuj/sparafrazuj).
- Zaproponuj konkretny next step (call 15-min / wysłanie case study).
- Nie wymyślaj cen, terminów, funkcji.
- Maks 6 zdań. Po polsku.

FORMAT (czysty JSON, bez markdown):
{
  "temperature": "hot|warm|cold",
  "lead_summary": "jednozdaniowy opis potrzeby klienta",
  "next_step": "call|case_study|nurture",
  "email_subject": "temat maila powitalnego",
  "email_body": "treść maila"
}
```

#### Krok 3: Code — parsuj JSON

(Identycznie jak w Scenariuszu 2 — możesz skopiować ten sam prompt, zmieniając pola na: `temperature`, `lead_summary`, `next_step`, `email_subject`, `email_body`.)

#### Krok 4: ClickUp — utwórz lead

1. **ClickUp** node → **Resource: Task** → **Operation: Create**.  
2. **List**: wybierz "Leady".  
3. **Name**: `[{{ $json.temperature.toUpperCase() }}] {{ $json.body.name }} - {{ $json.body.company }}`  
4. **Description**: pełne dane \+ AI-generated summary.  
5. **Tags**: `{{ $json.temperature }}`, `konferencja-2026`, `next-step:{{ $json.next_step }}`.

#### Krok 5: Slack — powiadomienie zespołu

1. **\+** → wpisz `Slack` → **Slack**.  
2. **Credential**: dodaj Slack (OAuth lub webhook URL).  
3. **Resource**: `Message`.  
4. **Operation**: `Send`.  
5. **Channel**: `#leady`.  
6. **Text**:

```
🔥 Nowy lead {{ $json.temperature.toUpperCase() }}: *{{ $json.body.name }}* z {{ $json.body.company }}
Potrzeba: {{ $json.lead_summary }}
Next step: {{ $json.next_step }}
Email: {{ $json.body.email }}
```

#### Krok 6: Send Email — do klienta

1. **Send Email** node.  
2. **To Email**: `{{ $json.body.email }}`.  
3. **Subject**: `{{ $json.email_subject }}`.  
4. **Email Format**: `Text` (lub HTML jeśli w prompcie generujesz HTML).  
5. **Text**: `{{ $json.email_body }}`.

#### Krok 7: Aktywacja i połączenie z formularzem

1. Przełącz workflow na **Active**.  
2. Skopiuj **Production URL** webhooka.  
3. W swoim narzędziu formularzowym (Typeform / Tally / Google Forms via Apps Script) ustaw, żeby po wysłaniu formularza wykonywał POST na ten URL z danymi w body.  
4. Wypełnij formularz testowo. Sprawdź: ClickUp ma kartę, Slack ma message, klient dostał maila.

### 6.5 Pomysły na rozszerzenia

- **Hubspot/Pipedrive** zamiast ClickUp — kolejny node, ten sam pattern.  
- **Routing** — HOT leady idą do konkretnego sprzedawcy (random / round-robin).  
- **Wzbogacanie danych** — przed klasyfikacją zapytaj API typu Apollo o info o firmie.  
- **Multi-language** — wykryj język wpisu i odpowiadaj w nim.

---

## Dodatek A — Najczęstsze błędy

### "Cannot read property 'X' of undefined"

**Przyczyna:** odwołujesz się do pola, które w bieżącym elemencie nie istnieje (np. zadanie bez `due_date`). **Naprawa:** sprawdź `if (item.json.due_date) { ... }` przed użyciem.

### "Invalid JSON" w node po AI Agent

**Przyczyna:** LLM owinął JSON w `json` lub dodał komentarz. **Naprawa:** w node Code zrób cleanup: ````output.replace(/```json|```/g, '').trim()```` przed `JSON.parse`.

### Webhook "404 not found"

**Przyczyna:** używasz Test URL, ale workflow nie nasłuchuje (nie kliknąłeś **Listen for test event**) — albo używasz Production URL, ale workflow nie jest **Active**. **Naprawa:** Test → Listen, Produkcja → Active.

### SMTP "535 Authentication failed"

**Przyczyna:** Gmail wymaga **App Password**, nie zwykłego hasła. Lub kont firmowych z 2FA. **Naprawa:** wygeneruj App Password w Google Account → Security.

### OpenAI "insufficient\_quota"

**Przyczyna:** brak salda na koncie OpenAI (free trial wygasł). **Naprawa:** doładuj saldo (Settings → Billing).

### ClickUp wraca pustą listę zadań

**Przyczyna:** wybrałeś niewłaściwy Workspace lub filtry odcięły wszystko. **Naprawa:** Execute step na ClickUp credential test — sprawdź czy widzi Workspace. Sprawdź filtry w node ClickUp (czy nie odfiltrowujesz wszystkich zadań).

### Code node — "items is not defined"

**Przyczyna:** używasz `items` zamiast `$input.all()`. **Naprawa:** zacznij każdy Code node od `const items = $input.all();`.

### Mail dochodzi pusty

**Przyczyna:** w polu HTML Body wpisałeś `{{ $json.html }}`, ale poprzedni node zwraca dane pod innym kluczem. **Naprawa:** Execute step poprzedniego node'a — sprawdź dokładnie nazwę pola.

---

## Dodatek B — Co dalej?

### Twoje pierwsze własne automatyzacje — pomysły

**Łatwe (na rozgrzewkę):**

- Codzienne podsumowanie kalendarza Google → mail.  
- Nowe zadanie w ClickUp → message na Slacka.  
- Codzienne backup linka z Google Sheets → Drive.

**Średnie:**

- Kandydat aplikuje przez formularz → AI ocenia CV → punkty \+ tag w ClickUp.  
- Faktura w mailu (PDF) → AI Vision wyciąga kwoty → wpis do arkusza.  
- Pytanie na czacie firmowym → AI szuka w bazie wiedzy → odpowiada.

**Trudniejsze:**

- Multi-step approval workflow z webhookami (manager akceptuje przez kliknięcie linka w mailu).  
- Pipeline analizy ankiet — sentyment \+ tematy \+ wykresy \+ raport tygodniowy.  
- Asystent recepcji — webhook z formularza rezerwacji → kalendarz \+ przypomnienie SMS \+ powitalny mail.

### Materiały do dalszej nauki

- **Dokumentacja n8n**: [https://docs.n8n.io](https://docs.n8n.io)  
- **n8n Community**: [https://community.n8n.io](https://community.n8n.io) — ogromna baza gotowych workflow.  
- **Templates**: [https://n8n.io/workflows](https://n8n.io/workflows) — setki gotowców do skopiowania i adaptacji.  
- **YouTube**: kanał oficjalny n8n \+ szukaj "n8n tutorial 2026".

### Złota zasada na koniec

Najlepsza automatyzacja to ta, która **odejmuje** Ci kliknięć z dnia, a nie **dodaje** kompleksowości do życia.

Zacznij od jednej rzeczy, którą robisz w każdy poniedziałek. Zautomatyzuj. Potem następną.

---

**Powodzenia.**

*Dokument przygotowany na potrzeby szkolenia "No-code, low-code w zarządzaniu" — Uniwersytet Łódzki.*  
